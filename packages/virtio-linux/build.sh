#!/bin/bash
set -euo pipefail

# Source tarball is extracted with strip_prefix, so we're already in the kernel tree.

JOBS=$(nproc)

# Reproducibility: the kernel bakes build time/user/host into the image
# (scripts/mkcompile_h). Pin them so vmlinuz is byte-identical across builds.
export KBUILD_BUILD_TIMESTAMP="@${SOURCE_DATE_EPOCH:-0}"
export KBUILD_BUILD_USER=builder
export KBUILD_BUILD_HOST=minimal

# Pick the right kernel image target + path per host arch. arm64's analogue
# of bzImage is just `Image`; there's no `kvm_guest.config` fragment for
# arm64 either, so we only merge that on x86.
case "$(uname -m)" in
  x86_64)
    # bzImage is already self-extracting; CONFIG_KERNEL_GZIP=y in defconfig
    # means the inner compression is gzip — no external wrap needed.
    KERNEL_TARGET=bzImage
    KERNEL_ARTIFACT=arch/x86/boot/bzImage
    HAS_KVM_GUEST_FRAGMENT=1
    ;;
  aarch64)
    # arm64 Image is uncompressed; Image.gz is the gzip-wrapped variant
    # that qemu/cloud-hypervisor/firecracker all accept.
    KERNEL_TARGET=Image.gz
    KERNEL_ARTIFACT=arch/arm64/boot/Image.gz
    HAS_KVM_GUEST_FRAGMENT=0
    ;;
  *)
    echo "unsupported arch: $(uname -m)" >&2
    exit 1
    ;;
esac

# Start from the arch's defconfig, then on x86 layer the upstream KVM-guest
# fragment which turns on the common virtio + paravirt bits microVMs need.
make defconfig
if [ "$HAS_KVM_GUEST_FRAGMENT" = "1" ]; then
  make kvm_guest.config
fi

CFG="scripts/config --file .config"

# --- modules stay enabled, but we ship none ----------------------------------
# We build only the image target (never `make modules` / `modules_install`), so
# no .ko is ever produced or shipped; every driver we actually want is pinned
# =y below and asserted after olddefconfig.
#
# Leaving MODULES=n would be the tidier invariant, but it is not free: when
# modules are off, kconfig cannot leave a tristate at =m and promotes it to =y
# instead. x86_64_defconfig has exactly one =m symbol so that was invisible
# there — arm64's defconfig has 779, the whole SoC driver zoo, and every one of
# them got compiled into a microVM guest kernel. That is what dragged in
# drivers/gpu/drm/msm (which shells out to python3 to generate headers, absent
# from build_deps) and blew up the arm64 build.
#
# With MODULES=y those 779 stay =m, and since we never invoke the modules
# target they cost nothing: not built, not shipped, not in the image.
$CFG --enable MODULES

# Module signing would make the build generate a fresh RSA keypair and embed
# the cert in the image — a different vmlinuz every run. Nothing turns it on
# today (MODULE_SIG has no `default y` and neither defconfig sets it), but it
# is one stray `select MODULE_SIG if MODULES` away from silently breaking
# reproducibility, so pin it off now that MODULES is back on.
$CFG --disable MODULE_SIG

# `scripts/config --enable FOO` is a silent no-op in three cases: FOO isn't a
# real symbol (typo, or upstream renamed it), FOO's dependencies aren't
# satisfied, or FOO is a tristate whose dependencies are themselves only =m —
# in which case our =y is invalid and kconfig quietly downgrades it back to =m,
# which for us means "not in the shipped image". Either way `make olddefconfig`
# rewrites the line without complaint. So route the must-haves through want()
# and assert on the resulting .config below, instead of finding the hole from
# inside a guest.
REQUIRED=()
want() {
  local sym
  for sym in "$@"; do
    $CFG --enable "$sym"
    REQUIRED+=("$sym")
  done
}

# The mirror image: `--disable` is just as silent when something else turns the
# symbol back on — a defconfig line, a merged fragment, or a `select` from a
# driver we didn't think about. nope() records those so we can assert they
# really are out of the image. Landing at =m is tolerated: we only ever build
# the image target, so a module is never compiled, let alone shipped.
FORBIDDEN=()
nope() {
  local sym
  for sym in "$@"; do
    $CFG --disable "$sym"
    FORBIDDEN+=("$sym")
  done
}

# --- virtio guest drivers ----------------------------------------------------
# Pin the core virtio transports and every guest-side device driver we'd
# plausibly want from a microVM hypervisor, plus the modern transports
# (MMIO for firecracker-style, PCI for cloud-hypervisor/qemu).
want VIRTIO VIRTIO_PCI VIRTIO_MMIO VIRTIO_MMIO_CMDLINE_DEVICES
want VIRTIO_BLK VIRTIO_NET VIRTIO_CONSOLE VIRTIO_BALLOON VIRTIO_INPUT
want VIRTIO_IOMMU
want HW_RANDOM HW_RANDOM_VIRTIO
$CFG --enable VIRTIO_PCI_LEGACY

# The SCSI guest driver is not called VIRTIO_SCSI (no such symbol), and the
# failover netdev is NET_FAILOVER, which VIRTIO_NET selects for us anyway.
# Asking by the wrong name was invisible on x86 — where kvm_guest.config
# happens to set the real symbols — and a missing driver on arm64, where we
# don't merge that fragment.
want SCSI_VIRTIO NET_FAILOVER

# No GPU. A microVM guest has no display — its console is a serial port — so
# the whole DRM subsystem is dead weight. Dropping DRM_VIRTIO_GPU from the
# want() list above is not enough to be rid of it: x86_64_defconfig sets
# CONFIG_DRM=y and CONFIG_DRM_I915=y outright, and kvm_guest.config re-asserts
# CONFIG_DRM_VIRTIO_GPU=y on top. Turn the subsystem off at the root.
nope DRM_I915 DRM_VIRTIO_GPU DRM

# virtio-mem is gated on the memory hotplug/hotremove machinery; without it the
# driver silently drops out of the config.
want MEMORY_HOTPLUG MEMORY_HOTREMOVE VIRTIO_MEM

# virtio-pmem likewise needs libnvdimm, and DAX is what makes a pmem device (or
# virtiofs, below) mappable without going through the guest page cache.
want ZONE_DEVICE LIBNVDIMM VIRTIO_PMEM DAX FS_DAX

# vsock + virtio-vsock for host<->guest sockets. The loopback transport lets
# guest-local services speak vsock without a host peer, which is what most
# vsock-based agents test against.
want VSOCKETS VSOCKETS_LOOPBACK VIRTIO_VSOCKETS

# virtiofs (needs FUSE). DAX mapping and passthrough are what make it fast
# enough to use as a real rootfs/workspace share.
want FUSE_FS VIRTIO_FS FUSE_DAX FUSE_PASSTHROUGH

# 9p-over-virtio: the older host share, and something x86 gets for free from
# kvm_guest.config — pin it so arm64 has it too.
want NET_9P NET_9P_VIRTIO 9P_FS

# ip=/DHCP autoconfiguration from the kernel cmdline (also x86-only via the
# fragment otherwise).
want IP_PNP IP_PNP_DHCP

# --- namespaces + cgroups (containers / sandboxing) --------------------------
want NAMESPACES UTS_NS IPC_NS PID_NS NET_NS USER_NS TIME_NS
want CGROUPS MEMCG CPUSETS CGROUP_PIDS CGROUP_FREEZER CGROUP_DEVICE
want CGROUP_CPUACCT CGROUP_SCHED BLK_CGROUP CGROUP_HUGETLB CGROUP_MISC
want CGROUP_PERF CGROUP_BPF CGROUP_NET_PRIO CGROUP_NET_CLASSID NET_CLS_CGROUP
# Pressure-stall + delay accounting: what memory/CPU-aware schedulers,
# systemd-oomd and cgroup `*.pressure` readers need.
want PSI TASKSTATS TASK_DELAY_ACCT TASK_IO_ACCOUNTING
# Note: cgroup v1's memory and cpuset controllers (MEMCG_V1 / CPUSETS_V1) stay
# off — v2-only, same as modern distros.

# --- /proc + process introspection userspace expects -------------------------
# PROC_CHILDREN backs /proc/<pid>/task/<tid>/children, which process
# supervisors use to walk a tree without scanning all of /proc.
# CHECKPOINT_RESTORE brings /proc/<pid>/map_files plus the rest of the CRIU
# surface, and USERFAULTFD is how CRIU (and lazy restore / live migration)
# faults pages back in. PROC_PAGE_MONITOR is /proc/<pid>/pagemap + smaps,
# which every memory profiler reads.
want PROC_CHILDREN PROC_PAGE_MONITOR PROC_KCORE CHECKPOINT_RESTORE USERFAULTFD

# --- core syscall surface container runtimes assume --------------------------
# seccomp is how every runtime filters syscalls; runc's default spec mounts
# /dev/mqueue (POSIX_MQUEUE) and needs ptys for `exec -t`.
want SECCOMP SECCOMP_FILTER
want SYSVIPC SYSVIPC_SYSCTL POSIX_MQUEUE POSIX_MQUEUE_SYSCTL UNIX98_PTYS
want EPOLL SIGNALFD TIMERFD EVENTFD AIO IO_URING FUTEX
want BINFMT_ELF BINFMT_SCRIPT BINFMT_MISC
want HUGETLBFS TRANSPARENT_HUGEPAGE

# --- BPF ---------------------------------------------------------------------
# systemd's device access control, container runtimes and the whole
# observability stack are BPF-first now; CGROUP_BPF is the cgroup-v2 attach
# point. KPROBES/PERF_EVENTS are what BPF_EVENTS — and therefore BPF_LSM —
# are gated on.
# Not enabled: DEBUG_INFO_BTF. CO-RE tooling (bpftrace, libbpf skeletons)
# wants it, but it needs pahole (dwarves) as a build dep and a DWARF-enabled
# build, so it's a deliberate follow-up rather than a free win.
want BPF_SYSCALL BPF_JIT CGROUP_BPF PERF_EVENTS KPROBES
# BPF_EVENTS is what gates BPF_LSM (and attaching BPF to kprobes/uprobes/
# tracepoints at all), and it needs KPROBE_EVENTS || UPROBE_EVENTS — both of
# which live inside `if FTRACE` in kernel/trace/Kconfig. FTRACE is
# `default y if DEBUG_KERNEL`, which x86_64_defconfig satisfies, but arm64's
# defconfig explicitly carries `# CONFIG_FTRACE is not set` — so on arm64 the
# probe-event symbols were unreachable and BPF_EVENTS silently fell to n,
# taking BPF_LSM with it. Turn the menu on and pin both probe backends.
want FTRACE KPROBE_EVENTS UPROBE_EVENTS BPF_EVENTS

# --- container networking ----------------------------------------------------
want VETH TUN WIREGUARD MACVLAN IPVLAN DUMMY BRIDGE BRIDGE_NETFILTER
want VLAN_8021Q IPV6
# Port publishing and egress NAT: docker, podman and CNI plugins program either
# nftables or iptables, and their rules lean on the addrtype/conntrack/multiport
# matches. defconfig sets NETFILTER_ADVANCED=n, which hides most of this and
# defaults the rest to =m — invisible to us, since we ship no modules.
want NETFILTER NETFILTER_ADVANCED NETFILTER_XTABLES
want NF_CONNTRACK NF_NAT NF_NAT_MASQUERADE
want NF_TABLES NF_TABLES_INET NF_TABLES_IPV4 NF_TABLES_IPV6
want NFT_CT NFT_NAT NFT_MASQ NFT_COMPAT NFT_LIMIT NFT_LOG
want NFT_REJECT NFT_REJECT_IPV4 NFT_REJECT_IPV6 NFT_FIB_IPV4 NFT_FIB_IPV6
want IP_NF_IPTABLES IP_NF_IPTABLES_LEGACY IP_NF_FILTER IP_NF_NAT IP_NF_MANGLE
want IP_NF_TARGET_MASQUERADE IP_NF_TARGET_REJECT IP_NF_TARGET_REDIRECT
want IP6_NF_IPTABLES IP6_NF_IPTABLES_LEGACY IP6_NF_FILTER IP6_NF_NAT
want IP6_NF_MANGLE IP6_NF_TARGET_MASQUERADE IP6_NF_TARGET_REJECT
want NETFILTER_XT_NAT NETFILTER_XT_MARK NETFILTER_XT_MATCH_ADDRTYPE
want NETFILTER_XT_MATCH_CONNTRACK NETFILTER_XT_MATCH_MULTIPORT
want NETFILTER_XT_MATCH_COMMENT NETFILTER_XT_MATCH_STATE
want NETFILTER_XT_TARGET_MASQUERADE NETFILTER_XT_TARGET_REDIRECT
# The log backends default to =m, which for us means `nft ... log` and
# `iptables -j LOG` rules would load but never emit anything.
want NETFILTER_XT_TARGET_LOG NF_LOG_SYSLOG NF_LOG_IPV4 NF_LOG_IPV6 NF_LOG_ARP
# `ss` and anything else that enumerates sockets goes through sock_diag.
want INET_DIAG INET_TCP_DIAG INET_UDP_DIAG UNIX_DIAG NETLINK_DIAG PACKET_DIAG
# tc classifiers/qdiscs, including the eBPF datapath hooks. NET_ACT_MIRRED is
# both how `tc` redirects/mirrors traffic and IFB's hard dependency — without
# it the ifb driver drops out of the config.
want NET_SCH_INGRESS NET_SCH_FQ_CODEL NET_CLS_BPF NET_ACT_BPF
want NET_ACT_MIRRED IFB

# --- block devices + filesystems ---------------------------------------------
# Loop devices and device-mapper are how disk images get mounted and how the
# thin/crypt storage stacks work.
#
# Not enabled: DM_VERITY. It exists to authenticate a read-only rootfs against
# a signed root hash, which is a defence against tampering with the backing
# store — not a threat model that applies here, where the rootfs arrives as a
# virtio-blk device handed to us by the hypervisor we already trust.
want BLK_DEV_LOOP BLK_DEV_DM DM_SNAPSHOT DM_THIN_PROVISIONING DM_CRYPT
# initramfs, and the decompressors a packed initrd might use.
want BLK_DEV_INITRD RD_GZIP RD_XZ RD_ZSTD
want EXT4_FS EXT4_FS_POSIX_ACL EXT4_FS_SECURITY
# Read-only image formats: squashfs and erofs both show up as container/rootfs
# images; ISO9660 + vfat are what cloud-init style config drives use.
want SQUASHFS SQUASHFS_XZ SQUASHFS_ZSTD EROFS_FS EROFS_FS_ZIP
want ISO9660_FS VFAT_FS NLS_CODEPAGE_437 NLS_ISO8859_1 NLS_UTF8 NLS_ASCII
# systemd mounts /proc/sys/fs/binfmt_misc and friends through autofs.
want AUTOFS_FS

# --- bind mounts / pivot_root substrate --------------------------------------
# Bind mounts are part of core VFS, but pivot_root + the filesystems people
# commonly use to assemble container roots are configurable. Make sure the
# usual suspects are present. TMPFS_INODE64 avoids inode-number reuse on
# long-lived tmpfs trees.
want TMPFS TMPFS_POSIX_ACL TMPFS_XATTR TMPFS_INODE64
want PROC_FS SYSFS DEVTMPFS DEVTMPFS_MOUNT

# --- overlayfs ---------------------------------------------------------------
want OVERLAY_FS OVERLAY_FS_REDIRECT_DIR OVERLAY_FS_INDEX
want OVERLAY_FS_XINO_AUTO OVERLAY_FS_METACOPY

# --- fanotify (privileged FS event monitoring + access control) -------------
want FANOTIFY FANOTIFY_ACCESS_PERMISSIONS

# --- LSMs --------------------------------------------------------------------
# landlock for unprivileged sandboxing, yama for ptrace scoping, bpf-lsm for
# programmable policy.
want SECURITY SECURITY_NETWORK SECURITY_LANDLOCK SECURITY_YAMA BPF_LSM
# Deliberately not enabling SECURITY_LOCKDOWN_LSM: it does
# `select MODULE_SIG if MODULES` — a condition we now satisfy — and MODULE_SIG
# with the default
# CONFIG_MODULE_SIG_KEY="certs/signing_key.pem" makes the build generate a
# fresh RSA keypair and embed the cert in the image — a different vmlinuz on
# every build. Lockdown buys us nothing here anyway (we ship no modules and
# there's no secure-boot chain in a microVM guest).
# Stackable LSMs only run if they're in this list, and only names that are
# actually compiled in mean anything — so keep the list and the config in sync.
# (The list previously named lockdown, apparmor and integrity, none of which
# was built.)
$CFG --set-str LSM "landlock,yama,bpf"

# --- nested KVM (let this guest itself host VMs) -----------------------------
# CONFIG_KVM is host-side virtualization; enabling it inside the guest is
# what makes nesting work from the guest's point of view. Whether nesting
# is *actually* available depends on the outer hypervisor exposing
# vmx/svm/EL2-virt to us, but the kernel side has to be built either way.
# KVM_INTEL/KVM_AMD only exist on x86; on arm64 the equivalent is folded
# into CONFIG_KVM. These stay outside want() precisely because they're
# arch-conditional, so olddefconfig is free to drop the ones that don't apply.
$CFG --enable VIRTUALIZATION
$CFG --enable KVM
$CFG --enable KVM_INTEL
$CFG --enable KVM_AMD

# Resolve any new dependencies / silently drop options renamed upstream.
make olddefconfig

# --- assert the config we asked for is the config we got ---------------------
missing=()
for sym in "${REQUIRED[@]}"; do
  grep -qx "CONFIG_${sym}=y" .config || missing+=("CONFIG_${sym}")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "error: required kernel options absent from .config after olddefconfig:" >&2
  printf '  %s\n' "${missing[@]}" >&2
  echo "cause is one of: symbol renamed/removed upstream, unmet dependency," >&2
  echo "or downgraded to =m (only the image target is built, so a module is" >&2
  echo "never compiled into the shipped kernel)." >&2
  exit 1
fi

resurrected=()
for sym in "${FORBIDDEN[@]}"; do
  grep -qx "CONFIG_${sym}=y" .config && resurrected+=("CONFIG_${sym}")
done
if [ "${#resurrected[@]}" -gt 0 ]; then
  echo "error: kernel options we disabled came back =y after olddefconfig:" >&2
  printf '  %s\n' "${resurrected[@]}" >&2
  echo "something selects them — find it and disable that instead." >&2
  exit 1
fi

make -j"$JOBS" "$KERNEL_TARGET"

OUT=$OUTPUT_DIR/usr/share/virtio-linux
mkdir -p "$OUT"
# Always publish as `vmlinuz` regardless of arch — the bytes inside differ
# per-arch (bzImage on x86, Image.gz on arm64) but the path is uniform so
# consumers don't need to care.
cp "$KERNEL_ARTIFACT" "$OUT/vmlinuz"
cp .config "$OUT/config"
cp System.map "$OUT/System.map"

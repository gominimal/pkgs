#!/bin/bash
set -euo pipefail

# gce-linux-detonation: the detonation observability kernel, bootable on a
# Google Compute Engine host (see build.ncl). Three parts:
#
#   1. HOST: what a C4 / C4A instance needs to boot and to run the build
#      host's userspace (Ubuntu, systemd, snap, nftables, the vTPM).
#   2. DETONATION: the BPF-LSM observability delta, copied from
#      virtio-linux-detonation's build.sh.
#   3. A comparison of (2), as resolved, with the config that package ships.
#
# No modules: every driver needed is built in and the rest are turned off, so
# the image is the whole kernel.

JOBS=$(nproc)

# Reproducibility: pin what the kernel bakes into the image.
export KBUILD_BUILD_TIMESTAMP="@${SOURCE_DATE_EPOCH:-0}"
export KBUILD_BUILD_USER=builder
export KBUILD_BUILD_HOST=minimal

case "$(uname -m)" in
  x86_64)
    KERNEL_TARGET=bzImage
    KERNEL_ARTIFACT=arch/x86/boot/bzImage
    HAS_KVM_GUEST_FRAGMENT=1
    ;;
  aarch64)
    # GRUB reads a gzip-compressed Image, as Ubuntu's own arm64 kernel is.
    KERNEL_TARGET=Image.gz
    KERNEL_ARTIFACT=arch/arm64/boot/Image.gz
    HAS_KVM_GUEST_FRAGMENT=0
    ;;
  *)
    echo "unsupported arch: $(uname -m)" >&2
    exit 1
    ;;
esac

# The same start as virtio-linux-detonation: a Compute Engine instance is a
# KVM guest, so the x86 KVM-guest fragment applies here too.
make defconfig
if [ "$HAS_KVM_GUEST_FRAGMENT" = "1" ]; then
  make kvm_guest.config
fi

CFG="scripts/config --file .config"

# Every symbol the host part asks for, checked after the config is resolved.
HOST_SYMS=()
host() {
  local s
  for s in "$@"; do
    $CFG --enable "$s"
    HOST_SYMS+=("$s")
  done
}

# === HOST: boot ==============================================================
# UEFI boot, with the EFI stub GRUB hands over to, and the GPT/EFI filesystems.
host EFI EFI_STUB EFIVAR_FS EFI_PARTITION VFAT_FS NLS_CODEPAGE_437 NLS_ISO8859_1 NLS_UTF8
host ACPI PCI PCI_MSI HOTPLUG_PCI
# An initramfs is optional (everything is built in), but the host's boot
# tooling may hand one over.
host BLK_DEV_INITRD RD_GZIP RD_ZSTD
# The running kernel's own config at /proc/config.gz, so a host can check
# what it booted.
host IKCONFIG IKCONFIG_PROC
# C4 has up to 288 vCPUs and the x86 defconfig stops at 64.
if [ "$(uname -m)" = x86_64 ]; then
  $CFG --set-val NR_CPUS 512
  host X86_X2APIC NUMA
fi
host SMP HIGH_RES_TIMERS NO_HZ_IDLE

# === HOST: disks and filesystems ============================================
# C4 and C4A present every disk (Hyperdisk, local SSD) as NVMe; older machine
# types use virtio-scsi.
host BLK_DEV_NVME SCSI BLK_DEV_SD SCSI_VIRTIO VIRTIO_BLK VIRTIO_PCI
host EXT4_FS EXT4_FS_POSIX_ACL EXT4_FS_SECURITY XFS_FS
host BLK_DEV_LOOP SQUASHFS SQUASHFS_XZ SQUASHFS_ZSTD SQUASHFS_LZO
host BLK_DEV_DM BLK_DEV_MD MD_RAID0
host TMPFS TMPFS_POSIX_ACL TMPFS_XATTR PROC_FS SYSFS DEVTMPFS DEVTMPFS_MOUNT
host OVERLAY_FS FUSE_FS AUTOFS_FS

# === HOST: network ===========================================================
# gVNIC is the only NIC on C4 and C4A; virtio-net for older machine types.
host NET_VENDOR_GOOGLE GVE VIRTIO_NET
host INET IPV6 PACKET UNIX
host VETH TUN BRIDGE
# nftables, as the build egress policy and the feed listener guard use it:
# inet tables, conntrack state, the cgroup v2 socket match, counters, rate
# limits, logging, and NAT for sandboxes with their own address.
host NETFILTER NETFILTER_ADVANCED NF_CONNTRACK NF_TABLES NF_TABLES_INET NF_TABLES_IPV4 NF_TABLES_IPV6
host NFT_CT NFT_LOG NFT_LIMIT NFT_REJECT NFT_SOCKET NFT_NAT NFT_MASQ NFT_COMPAT NF_NAT
host NETFILTER_XTABLES IP_NF_IPTABLES IP6_NF_IPTABLES
host CGROUP_NET_CLASSID SOCK_CGROUP_DATA

# === HOST: userspace (systemd, snap, the sandbox) ============================
host NAMESPACES UTS_NS IPC_NS PID_NS NET_NS USER_NS TIME_NS
host CGROUPS MEMCG CPUSETS CGROUP_PIDS CGROUP_FREEZER CGROUP_DEVICE CGROUP_CPUACCT CGROUP_SCHED BLK_CGROUP CGROUP_BPF
host FAIR_GROUP_SCHED CFS_BANDWIDTH PSI
host INOTIFY_USER FANOTIFY FANOTIFY_ACCESS_PERMISSIONS FHANDLE SIGNALFD TIMERFD EVENTFD EPOLL IO_URING
host SECCOMP SECCOMP_FILTER BINFMT_MISC DMI DMIID
host TRANSPARENT_HUGEPAGE

# === HOST: vTPM ==============================================================
# The Shielded VM's vTPM (/dev/tpmrm0) and the firmware's boot event log
# under securityfs, which a quote is replayed against.
host TCG_TPM TCG_TIS TCG_CRB SECURITYFS
host HW_RANDOM HW_RANDOM_VIRTIO HW_RANDOM_TPM

# === HOST: LSMs ==============================================================
# Ubuntu's userspace loads AppArmor profiles (snap confinement among them).
# The order is virtio-linux-detonation's, and `bpf` in it is what makes the
# BPF LSM active with no boot-command-line change.
host SECURITY SECURITY_LANDLOCK SECURITY_APPARMOR
$CFG --set-str LSM "landlock,lockdown,yama,integrity,apparmor,bpf"

# === DETONATION: BPF-LSM observability delta =================================
# Copied from virtio-linux-detonation/build.sh, which says why each is there.
# Do not edit here alone: part 3 below fails the build when the two differ.
$CFG --enable FTRACE
$CFG --enable KPROBES
$CFG --enable PERF_EVENTS
$CFG --enable KPROBE_EVENTS
$CFG --enable UPROBE_EVENTS
$CFG --enable BPF_EVENTS
$CFG --enable FUNCTION_TRACER
$CFG --enable DYNAMIC_FTRACE
$CFG --enable FTRACE_SYSCALLS
$CFG --enable BPF
$CFG --enable BPF_SYSCALL
$CFG --enable BPF_JIT
$CFG --enable BPF_JIT_ALWAYS_ON
$CFG --enable BPF_LSM
$CFG --disable DEBUG_INFO_NONE
$CFG --enable DEBUG_INFO
$CFG --enable DEBUG_INFO_DWARF5
$CFG --disable DEBUG_INFO_REDUCED
$CFG --disable DEBUG_INFO_SPLIT
$CFG --enable DEBUG_INFO_BTF
$CFG --enable AUDIT
$CFG --enable AUDITSYSCALL
# =============================================================================

make olddefconfig
# Whatever is still a module was not asked for above: turn it off, so that the
# image is the whole kernel and nothing is silently missing from it.
make mod2noconfig
make olddefconfig

fail=0

# The same guard as virtio-linux-detonation.
for sym in BPF_LSM DEBUG_INFO_BTF AUDIT DYNAMIC_FTRACE_WITH_ARGS FTRACE_SYSCALLS; do
  if ! grep -q "^CONFIG_${sym}=y" .config; then
    echo "FATAL: CONFIG_${sym}=y did not survive olddefconfig" >&2
    fail=1
  fi
done

# Every host symbol must be built in. One that is unknown to this kernel
# version or this arch, or whose dependency is unmet, is dropped without a
# word by olddefconfig, and the host would then not boot or not run its
# services.
for sym in "${HOST_SYMS[@]}"; do
  if ! grep -q "^CONFIG_${sym}=y" .config; then
    echo "FATAL: host symbol CONFIG_${sym} is not =y: $(grep -E "^(CONFIG_${sym}=|# CONFIG_${sym} )" .config || echo absent)" >&2
    fail=1
  fi
done
if grep -q '=m$' .config; then
  echo "FATAL: the config still has modules:" >&2
  grep '=m$' .config | head -20 >&2
  fail=1
fi
if [ "$(uname -m)" = x86_64 ] && ! grep -q '^CONFIG_NR_CPUS=512$' .config; then
  echo "FATAL: NR_CPUS is $(grep '^CONFIG_NR_CPUS=' .config || echo unset), not 512" >&2
  fail=1
fi

# === 3. the observability settings are virtio-linux-detonation's =============
# Each symbol below must have, in this config, the value it has in the config
# that package ships (set to the same value, or not set in both).
REF=/usr/share/virtio-linux-detonation/config
[ -s "$REF" ] || { echo "FATAL: $REF is missing: the virtio-linux-detonation build dependency did not provide its config" >&2; exit 1; }
value_of() { grep -E "^CONFIG_$2=" "$1" || echo "CONFIG_$2 is not set"; }
for sym in \
    LSM SECURITY SECURITY_LANDLOCK SECURITY_LOCKDOWN_LSM SECURITY_YAMA INTEGRITY \
    BPF BPF_SYSCALL BPF_JIT BPF_JIT_ALWAYS_ON BPF_JIT_DEFAULT_ON BPF_UNPRIV_DEFAULT_OFF \
    BPF_LSM BPF_EVENTS CGROUP_BPF \
    FTRACE FUNCTION_TRACER FUNCTION_GRAPH_TRACER DYNAMIC_FTRACE DYNAMIC_FTRACE_WITH_REGS \
    DYNAMIC_FTRACE_WITH_DIRECT_CALLS DYNAMIC_FTRACE_WITH_ARGS FTRACE_SYSCALLS FPROBE \
    KPROBES KRETPROBES KPROBE_EVENTS UPROBES UPROBE_EVENTS PERF_EVENTS TRACEPOINTS \
    DEBUG_INFO DEBUG_INFO_NONE DEBUG_INFO_DWARF5 DEBUG_INFO_REDUCED DEBUG_INFO_SPLIT \
    DEBUG_INFO_BTF PAHOLE_VERSION \
    AUDIT AUDITSYSCALL; do
  ours=$(value_of .config "$sym")
  theirs=$(value_of "$REF" "$sym")
  if [ "$ours" != "$theirs" ]; then
    echo "FATAL: observability setting differs from virtio-linux-detonation: here '$ours', there '$theirs'" >&2
    fail=1
  fi
done
# The kernel version too: the sensor reads this kernel's structures.
ours=$(make -s kernelversion)
theirs=$(sed -n 's/^# Linux\/[^ ]* \([0-9][^ ]*\) Kernel Configuration$/\1/p' "$REF")
if [ "$ours" != "$theirs" ]; then
  echo "FATAL: kernel version $ours here, '$theirs' in virtio-linux-detonation" >&2
  fail=1
fi
[ "$fail" = 0 ] || exit 1

# See virtio-linux-detonation/build.sh for why the host tools need this flag.
make -j"$JOBS" HOSTCFLAGS="-Wno-error=discarded-qualifiers" "$KERNEL_TARGET"

OUT=$OUTPUT_DIR/usr/share/gce-linux-detonation
mkdir -p "$OUT"
cp "$KERNEL_ARTIFACT" "$OUT/vmlinuz"
cp .config "$OUT/config"
cp System.map "$OUT/System.map"

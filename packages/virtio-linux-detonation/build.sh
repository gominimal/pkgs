#!/bin/bash
set -euo pipefail

# virtio-linux-detonation: the virtio-linux session kernel + the BPF-LSM
# observability delta the detonation sandbox needs. Identical base to
# virtio-linux (same 6.12.43 source) so it stays a libkrun-bootable, fast
# session kernel; the only difference is the config block marked DETONATION
# below + the `pahole` (dwarves) build_dep that CONFIG_DEBUG_INFO_BTF requires.
#
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

# --- virtio guest drivers ----------------------------------------------------
# Pin the core virtio transports and every guest-side device driver we'd
# plausibly want from a microVM hypervisor, plus the modern transports
# (MMIO for firecracker-style, PCI for cloud-hypervisor/qemu).
$CFG --enable VIRTIO
$CFG --enable VIRTIO_PCI
$CFG --enable VIRTIO_PCI_LEGACY
$CFG --enable VIRTIO_MMIO
$CFG --enable VIRTIO_MMIO_CMDLINE_DEVICES
$CFG --enable VIRTIO_BLK
$CFG --enable VIRTIO_NET
$CFG --enable VIRTIO_CONSOLE
$CFG --enable VIRTIO_BALLOON
$CFG --enable VIRTIO_INPUT
$CFG --enable VIRTIO_SCSI
$CFG --enable VIRTIO_GPU
$CFG --enable VIRTIO_PMEM
$CFG --enable VIRTIO_IOMMU
$CFG --enable VIRTIO_MEM
$CFG --enable VIRTIO_NET_FAILOVER
$CFG --enable VIRTIO_DMA_SHARED_BUFFER
$CFG --enable HW_RANDOM
$CFG --enable HW_RANDOM_VIRTIO
# vsock + virtio-vsock for host<->guest sockets
$CFG --enable VSOCKETS
$CFG --enable VIRTIO_VSOCKETS
# virtiofs (needs FUSE)
$CFG --enable FUSE_FS
$CFG --enable VIRTIO_FS

# --- namespaces + cgroups (containers / sandboxing) --------------------------
$CFG --enable NAMESPACES
$CFG --enable UTS_NS
$CFG --enable IPC_NS
$CFG --enable PID_NS
$CFG --enable NET_NS
$CFG --enable USER_NS
$CFG --enable TIME_NS
$CFG --enable CGROUPS
$CFG --enable MEMCG
$CFG --enable CPUSETS
$CFG --enable CGROUP_PIDS
$CFG --enable CGROUP_FREEZER
$CFG --enable CGROUP_DEVICE
$CFG --enable CGROUP_CPUACCT
$CFG --enable CGROUP_SCHED
$CFG --enable BLK_CGROUP

# --- container networking ----------------------------------------------------
$CFG --enable VETH
$CFG --enable TUN
$CFG --enable WIREGUARD

# --- bind mounts / pivot_root substrate --------------------------------------
# Bind mounts are part of core VFS, but pivot_root + the filesystems people
# commonly use to assemble container roots are configurable. Make sure the
# usual suspects are present.
$CFG --enable TMPFS
$CFG --enable TMPFS_POSIX_ACL
$CFG --enable TMPFS_XATTR
$CFG --enable PROC_FS
$CFG --enable SYSFS
$CFG --enable DEVTMPFS
$CFG --enable DEVTMPFS_MOUNT

# --- overlayfs ---------------------------------------------------------------
$CFG --enable OVERLAY_FS
$CFG --enable OVERLAY_FS_REDIRECT_DIR
$CFG --enable OVERLAY_FS_INDEX
$CFG --enable OVERLAY_FS_XINO_AUTO
$CFG --enable OVERLAY_FS_METACOPY

# --- fanotify (privileged FS event monitoring + access control) -------------
$CFG --enable FANOTIFY
$CFG --enable FANOTIFY_ACCESS_PERMISSIONS

# --- landlock (unprivileged sandboxing LSM) ----------------------------------
$CFG --enable SECURITY
$CFG --enable SECURITY_LANDLOCK
# Landlock is a stackable LSM; make sure it's actually in the active list.
# `bpf` is already here, which is what makes the BPF LSM (below) active without
# a boot-cmdline change.
$CFG --set-str LSM "landlock,lockdown,yama,integrity,apparmor,bpf"

# === DETONATION: BPF-LSM observability delta =================================
# This is the entire difference from virtio-linux. The detonation observer
# attaches BPF LSM programs (file_open / socket / bprm hooks) and streams events
# over a ringbuf; our consumer (minimal-detonation src/audit.rs) ingests that
# JSONL. CONFIG_LSM already lists `bpf` above, so BPF_LSM=y activates it.
#
# Tracing prerequisites. BPF_LSM depends on BPF_EVENTS, which in turn needs
# (KPROBE_EVENTS || UPROBE_EVENTS) && PERF_EVENTS. The arm64 defconfig ships
# `# CONFIG_FTRACE is not set`, which disables the entire tracing menu and
# therefore KPROBE_EVENTS/UPROBE_EVENTS — so BPF_EVENTS, and thus BPF_LSM,
# silently never appear. Turn the chain on explicitly.
$CFG --enable FTRACE
$CFG --enable KPROBES
$CFG --enable PERF_EVENTS
$CFG --enable KPROBE_EVENTS
$CFG --enable UPROBE_EVENTS
$CFG --enable BPF_EVENTS
# FUNCTION_TRACER -> DYNAMIC_FTRACE -> DYNAMIC_FTRACE_WITH_ARGS (arm64 selects it
# when GCC_SUPPORTS_DYNAMIC_FTRACE_WITH_ARGS). This is what provides BPF
# TRAMPOLINES, which BPF-LSM/fentry programs attach through. Without it,
# attaching an LSM program fails at runtime with bpf_raw_tracepoint_open
# ENOTSUPP (os err 524) even though BPF_LSM is active — the FTRACE menu alone is
# NOT enough; the function tracer itself must be on.
$CFG --enable FUNCTION_TRACER
$CFG --enable DYNAMIC_FTRACE

# BPF core + LSM. BPF_LSM depends on BPF_EVENTS && BPF_SYSCALL && SECURITY && BPF_JIT.
$CFG --enable BPF
$CFG --enable BPF_SYSCALL
$CFG --enable BPF_JIT
$CFG --enable BPF_JIT_ALWAYS_ON
$CFG --enable BPF_LSM
#
# BTF (vmlinux type info) — required for CO-RE BPF programs and exposed at
# /sys/kernel/btf/vmlinux. This is the step that needs `pahole` on PATH at
# build time (provided by the dwarves build_dep) and DWARF debug info to
# convert from. DEBUG_INFO_BTF depends on DEBUG_INFO; pick an explicit DWARF
# level (DWARF5) for a deterministic build rather than DEBUG_INFO_DWARF_TOOLCHAIN
# which defers to whatever the compiler emits.
$CFG --disable DEBUG_INFO_NONE
$CFG --enable DEBUG_INFO
$CFG --enable DEBUG_INFO_DWARF5
# arm64 defconfig sets DEBUG_INFO_REDUCED=y; BTF needs full DWARF
# (DEBUG_INFO_BTF depends on !DEBUG_INFO_REDUCED && !DEBUG_INFO_SPLIT) so pahole
# has enough type info to convert. Clear both before enabling BTF.
$CFG --disable DEBUG_INFO_REDUCED
$CFG --disable DEBUG_INFO_SPLIT
$CFG --enable DEBUG_INFO_BTF
#
# audit subsystem — sandbox-next's audit layer can emit here. Not consumed by
# audit.rs today (it reads only the BPF ringbuf), but cheap to carry and part
# of the documented observability recipe.
$CFG --enable AUDIT
$CFG --enable AUDITSYSCALL
# =============================================================================

# --- nested KVM (let this guest itself host VMs) -----------------------------
# CONFIG_KVM is host-side virtualization; enabling it inside the guest is
# what makes nesting work from the guest's point of view. Whether nesting
# is *actually* available depends on the outer hypervisor exposing
# vmx/svm/EL2-virt to us, but the kernel side has to be built either way.
# KVM_INTEL/KVM_AMD only exist on x86; on arm64 the equivalent is folded
# into CONFIG_KVM. scripts/config silently no-ops on unknown symbols and
# olddefconfig drops them, so listing both arches' symbols here is safe.
$CFG --enable VIRTUALIZATION
$CFG --enable KVM
$CFG --enable KVM_INTEL
$CFG --enable KVM_AMD
$CFG --enable KVM_XFER_TO_GUEST_WORK
$CFG --enable KVM_GENERIC_DIRTYLOG_READ_PROTECT

# Resolve any new dependencies / silently drop options renamed upstream.
make olddefconfig

# Fail loudly if the load-bearing detonation options didn't survive
# olddefconfig (e.g. an unmet dependency silently turned one off). Without
# these the kernel boots fine but is observability-blind, which would be a
# silent, confusing failure downstream.
for sym in CONFIG_BPF_LSM CONFIG_DEBUG_INFO_BTF CONFIG_AUDIT CONFIG_DYNAMIC_FTRACE_WITH_ARGS; do
  if ! grep -q "^${sym}=y" .config; then
    echo "FATAL: ${sym}=y did not survive olddefconfig" >&2
    echo "--- dependency-chain state in .config (find the unmet link) ---" >&2
    for d in FTRACE KPROBES PERF_EVENTS KPROBE_EVENTS UPROBE_EVENTS \
             BPF BPF_SYSCALL BPF_JIT BPF_EVENTS BPF_LSM SECURITY \
             DEBUG_INFO DEBUG_INFO_DWARF5 DEBUG_INFO_BTF PAHOLE_VERSION \
             AUDIT AUDITSYSCALL; do
      line=$(grep -E "^(CONFIG_${d}=|# CONFIG_${d} )" .config || echo "(absent)")
      printf '  %-22s %s\n' "$d" "$line" >&2
    done
    exit 1
  fi
done

# The kernel builds host/BTF tools (tools/bpf/resolve_btfids and its vendored
# libbpf) with -Werror against glibc headers. glibc 2.43's ISO C23
# const-preserving strstr/strchr-family return `const char *` for const args,
# which libbpf assigns to plain `char *` → -Werror=discarded-qualifiers FTBFS
# (same class the elfutils package documents). HOSTCFLAGS flows into those
# tools' EXTRA_CFLAGS (resolve_btfids/Makefile), and a specific -Wno-error=
# overrides the blanket -Werror regardless of order.
make -j"$JOBS" HOSTCFLAGS="-Wno-error=discarded-qualifiers" "$KERNEL_TARGET"

OUT=$OUTPUT_DIR/usr/share/virtio-linux-detonation
mkdir -p "$OUT"
# Always publish as `vmlinuz` regardless of arch — the bytes inside differ
# per-arch (bzImage on x86, Image.gz on arm64) but the path is uniform so
# consumers don't need to care.
cp "$KERNEL_ARTIFACT" "$OUT/vmlinuz"
cp .config "$OUT/config"
cp System.map "$OUT/System.map"

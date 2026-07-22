let { subsetOf, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libkrunfw = import "../libkrunfw/build.ncl" in
let make = import "../make/build.ncl" in
let patch = import "../patch/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.19.4" in
{
  name = "libkrun",

  build_deps = [
    { file = "build.sh" } | Local,
    # Two vsock fixes for a bulk host->guest stream that dies mid-upload with
    # ENOBUFS. Order matters: 0002 is written against the tree 0001 produces,
    # and build.sh applies them by name in that order.
    #
    # 0001 -- the credit-request path sets `push_credit_req` but never
    # `signal_queue`, and push_packet() alone does not raise the IRQ. A proxy
    # that must wait for credit therefore disarms its own polling and never
    # wakes the peer, so the credit update it is waiting on is never sent.
    # Usually masked (a batch normally pushes data packets first, and those
    # set signal_queue), reachable when the first packet of a batch has to
    # wait. A real bug, but NOT the upload fix -- measured 0/6 on its own.
    #
    # 0002 -- the actual fix. recv_to_pkt() issued one recv() per RX
    # descriptor and shipped whatever happened to be buffered, so the muxer
    # outran the writer and fragmented the stream into sub-KiB packets. A
    # Linux peer charges every queued skb SKB_TRUESIZE(0) (576 bytes on
    # arm64) against buf_alloc regardless of payload, so those packets burn
    # queue budget far faster than they deliver bytes and the peer resets the
    # connection with credit still outstanding. Instrumentation over 40,749
    # packets: 74% of reads drained the socket with descriptor space still
    # free, mean 2,199 bytes available against 239,848 bytes of credit -- the
    # window was never the constraint. Loop until the descriptor is full or
    # the socket returns EAGAIN.
    #
    # Byte-identical to the patches the macOS source build carries at
    # vendor/libkrun/patches/ in gominimal/minimal; drop both once they land
    # in an upstream release we can pin.
    # https://github.com/gominimal/minimal/issues/869
    { file = "0001-vsock-signal-the-used-queue-when-requesting-credit.patch" } | Local,
    { file = "0002-vsock-fill-the-rx-descriptor-instead-of-one-recv-per-packet.patch" } | Local,
    {
      url = "https://github.com/containers/libkrun/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "e8775fab2b460972a67ca6cd936296bb79cdb078d852d712a283cb290dd0b284",
      extract = true,
      strip_prefix = "libkrun-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    patch,
    rust,
    pkgconf,
  ],

  # libkrunfw is dlopen()ed at runtime (libkrunfw.so.5), not linked at build.
  runtime_deps = [
    glibc,
    libkrunfw,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  # cargo fetches crates from crates.io during the build.
  needs = {
    dns = {},
    internet = {},
  },

  outputs = {
    libs = { glob = "usr/lib/libkrun.so*" } | OutputLib,
    headers = { glob = "usr/include/libkrun*.h" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libkrun.pc" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    license_spdx = "Apache-2.0",
    source_provenance = {
      category = 'GithubRepo,
      owner = "containers",
      repo = "libkrun",
    },
  },
} | BuildSpec

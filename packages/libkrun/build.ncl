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
    # vsock fix for a bulk host->guest stream that dies mid-upload with
    # ENOBUFS. Since Linux 6.12.92 the guest resets the connection once its
    # queued socket-buffer overhead exceeds buf_alloc:
    # (skb_queue_len + 1) * SKB_TRUESIZE(0) > buf_alloc -- a second,
    # packet-count receive ceiling the vsock credit protocol (which meters
    # bytes only) does not express. A sender that fragments the stream into
    # sub-SKB_TRUESIZE(0) packets (576 B on arm64) exhausts that count ceiling
    # with the byte window mostly unused.
    #
    # The patch meters packet count the same way byte credit is metered:
    # recv_to_pkt() tracks the guest's skb_queue_len exactly (rx_cnt at each
    # emitted packet's tail, retired as fwd_cnt passes it) and, before
    # emitting, waits on the existing WaitForCredit path if one more packet
    # would approach buf_alloc / SKB_OVERHEAD. Unlike coalescing it does not
    # change delivery granularity -- send() stays 1:1 with recv(); it is pure
    # backpressure, invisible until the reader falls behind. It bundles the
    # credit-request wakeup fix (push_credit_req must set signal_queue), which
    # the count ceiling makes reachable during bulk transfer.
    #
    # Identical to the patch the macOS source build carries at
    # vendor/libkrun/patches/ in gominimal/minimal (#926); drop it once the
    # fix lands in an upstream release we can pin.
    # https://github.com/gominimal/minimal/issues/869
    { file = "0001-vsock-bound-outstanding-packets.patch" } | Local,
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

let { Attrs, BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let virtio-linux = import "../virtio-linux/build.ncl" in

# Tracks the virtio-linux kernel version; this package only decompresses it.
let version = "6.12.94" in
{
  name = "virtio-kernel-raw",

  # Produce a raw, directly-loadable kernel Image from the virtio-linux kernel.
  # On aarch64 that is a gzip-compressed Image (Image.gz); decompress it so
  # libkrun can load it via KRUN_KERNEL_FORMAT_RAW, skipping its in-VMM gzip
  # decompress for a faster microVM boot. On x86_64 it is already a bzImage and
  # passes through unchanged. base provides gzip + sh at build time.
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    virtio-linux,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    image = { glob = "usr/share/virtio-linux/Image" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
    } | Attrs,
} | BuildSpec

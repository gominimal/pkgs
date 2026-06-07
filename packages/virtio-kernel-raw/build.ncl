let { BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let virtio-linux = import "../virtio-linux/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
{
  name = "virtio-kernel-raw",

  # Decompress the virtio-linux kernel (Image.gz) to a raw Image. libkrun can
  # load a raw aarch64 Image via KRUN_KERNEL_FORMAT_RAW, skipping its in-VMM
  # gzip decompress for a faster microVM boot.
  build_deps = [
    { file = "build.sh" } | Local,
    virtio-linux,
    gzip,
    bash,
    coreutils,
  ],

  cmd = "./build.sh",

  outputs = {
    image = { glob = "usr/share/virtio-linux/Image" } | OutputData,
  },
} | BuildSpec

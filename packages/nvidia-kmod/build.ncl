let { Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let perl = import "../perl/build.ncl" in
let elfutils = import "../elfutils/build.ncl" in
let zstd = import "../zstd/build.ncl" in
let inetutils = import "../inetutils/build.ncl" in

let linux_modules_build = import "../linux_modules_build/build.ncl" in

let version = "595.58.03" in
let kver = "6.12.43" in
{
  name = "nvidia-kmod",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/NVIDIA/open-gpu-kernel-modules/archive/refs/tags/%{version}.tar.gz",
      sha256 = "e0c4659ddf15e4f4e19cee05b49f88c9ba08ef3add0dfe08249798f58d0fe75e",
      extract = true,
      strip_prefix = "open-gpu-kernel-modules-%{version}",
    } | Source,
    base,
    toolchain,
    bash,
    make,
    gawk,
    perl,
    elfutils,
    zstd,
    inetutils,
    linux_modules_build,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    kernel_version = kver,
  },

  outputs = {
    nvidia = { glob = "lib/modules/%{kver}/kernel/drivers/video/nvidia.ko" } | OutputLib,
    nvidia-uvm = { glob = "lib/modules/%{kver}/kernel/drivers/video/nvidia-uvm.ko" } | OutputLib,
    nvidia-modeset = { glob = "lib/modules/%{kver}/kernel/drivers/video/nvidia-modeset.ko" } | OutputLib,
    nvidia-drm = { glob = "lib/modules/%{kver}/kernel/drivers/video/nvidia-drm.ko" } | OutputLib,
    nvidia-peermem = { glob = "lib/modules/%{kver}/kernel/drivers/video/nvidia-peermem.ko" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "NVIDIA",
        repo = "open-gpu-kernel-modules",
      },
    } | Attrs,
} | BuildSpec

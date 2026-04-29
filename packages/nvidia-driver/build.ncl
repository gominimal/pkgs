let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let tar = import "../tar/build.ncl" in
let zstd = import "../zstd/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "595.58.03" in
{
  name = "nvidia-driver",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://download.nvidia.com/XFree86/Linux-x86_64/%{version}/NVIDIA-Linux-x86_64-%{version}-no-compat32.run",
      sha256 = "b66c59b9bebc191b9c21bad7476da1486dd390198223a548892110bca5fb91f9",
    } | Source,
    base,
    bash,
    tar,
    zstd,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    nvidia-smi = { glob = "usr/bin/nvidia-smi" } | OutputBin,
    nvidia-debugdump = { glob = "usr/bin/nvidia-debugdump" } | OutputBin,
    nvidia-persistenced = { glob = "usr/bin/nvidia-persistenced" } | OutputBin,
    nvidia-modprobe = { glob = "usr/bin/nvidia-modprobe" } | OutputBin,
    nvidia-cuda-mps-control = { glob = "usr/bin/nvidia-cuda-mps-control" } | OutputBin,
    nvidia-cuda-mps-server = { glob = "usr/bin/nvidia-cuda-mps-server" } | OutputBin,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    firmware = { glob = "usr/lib/firmware/nvidia/**" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec

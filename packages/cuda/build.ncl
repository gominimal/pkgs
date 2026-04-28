let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let nvidia-driver = import "../nvidia-driver/build.ncl" in

let version = "13.2.1" in
let redist_url = "https://developer.download.nvidia.com/compute/cuda/redist" in
{
  name = "cuda",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "%{redist_url}/cuda_nvcc/linux-x86_64/cuda_nvcc-linux-x86_64-13.2.78-archive.tar.xz",
      sha256 = "1dc73b03f1d74081866986ca406f7b5981d14306ccbb03127ba45401f36e1862",
      extract = true,
    } | Source,
    {
      url = "%{redist_url}/cuda_cudart/linux-x86_64/cuda_cudart-linux-x86_64-13.2.75-archive.tar.xz",
      sha256 = "9502ab2c7824e5ef3b554d290b9f564c5026994f469b99c72451a53578f386b9",
      extract = true,
    } | Source,
    {
      url = "%{redist_url}/cuda_cccl/linux-x86_64/cuda_cccl-linux-x86_64-13.2.75-archive.tar.xz",
      sha256 = "1801f304d92085a327ab46db58264d7f7f48cce80f5825637c405c3a2410dadd",
      extract = true,
    } | Source,
    {
      url = "%{redist_url}/cuda_crt/linux-x86_64/cuda_crt-linux-x86_64-13.2.78-archive.tar.xz",
      sha256 = "17e731ba749765c2e2e325e3bffecee94226c866cf59f13ba3792aa4f2b1bb31",
      extract = true,
    } | Source,
    {
      url = "%{redist_url}/cuda_nvrtc/linux-x86_64/cuda_nvrtc-linux-x86_64-13.2.78-archive.tar.xz",
      sha256 = "99dec7ff38d8540b0cb7bdc7b3c8b12b87db83f0f1023ad5f1ed8b51b4af1272",
      extract = true,
    } | Source,
    {
      url = "%{redist_url}/cuda_cupti/linux-x86_64/cuda_cupti-linux-x86_64-13.2.75-archive.tar.xz",
      sha256 = "302209ad5e44bfdfdd701d035a70d1f9700cdafe46d31c229d31c2c93b906462",
      extract = true,
    } | Source,
    {
      url = "%{redist_url}/libnvvm/linux-x86_64/libnvvm-linux-x86_64-13.2.78-archive.tar.xz",
      sha256 = "9c665ebec40d0dec4df1858d5a0129972b00351dd674e783d30405cf712d925d",
      extract = true,
    } | Source,
    {
      url = "%{redist_url}/libcublas/linux-x86_64/libcublas-linux-x86_64-13.4.0.1-archive.tar.xz",
      sha256 = "eda8001ac6b9a6ad862d054aa9b502ff39684147f1e86d02cc0a58a5ce67f62e",
      extract = true,
    } | Source,
    {
      url = "%{redist_url}/libcufft/linux-x86_64/libcufft-linux-x86_64-12.2.0.46-archive.tar.xz",
      sha256 = "ad001666bce5986cf0244d7795b6ba0164f30a5d4b1b82bbcc5a8d60af05a8b5",
      extract = true,
    } | Source,
    {
      url = "%{redist_url}/libcurand/linux-x86_64/libcurand-linux-x86_64-10.4.2.55-archive.tar.xz",
      sha256 = "78141da80fa96d9e56ff365e402e27d1873068e5e3e0f528e11c7e1a59cf8bc3",
      extract = true,
    } | Source,
    {
      url = "%{redist_url}/libcusolver/linux-x86_64/libcusolver-linux-x86_64-12.2.0.1-archive.tar.xz",
      sha256 = "893b5b81527626e96b1adf7d3c6733d39d6e058b250e414bb9ca36c41a8c7081",
      extract = true,
    } | Source,
    {
      url = "%{redist_url}/libcusparse/linux-x86_64/libcusparse-linux-x86_64-12.7.10.1-archive.tar.xz",
      sha256 = "b981186fa16f8187c550331182fd719dd88def0527d461059b5ef58c5788fa9e",
      extract = true,
    } | Source,
    {
      url = "%{redist_url}/libnpp/linux-x86_64/libnpp-linux-x86_64-13.1.0.48-archive.tar.xz",
      sha256 = "d95ae34b4ba3a85e87ae3161876032ca6c7e1fc073b87520a1d8269cc818d5fe",
      extract = true,
    } | Source,
    {
      url = "%{redist_url}/libnvjitlink/linux-x86_64/libnvjitlink-linux-x86_64-13.2.78-archive.tar.xz",
      sha256 = "75fb264ce48651095972ab3aaaefab0809f69245f859aabbf2113f4c5e01d400",
      extract = true,
    } | Source,
    base,
    bash,
    tar,
    xz,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    zlib,
    nvidia-driver,
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    nvcc = { glob = "opt/cuda/bin/nvcc" } | OutputBin,
    cudafepp = { glob = "opt/cuda/bin/cudafe++" } | OutputBin,
    ptxas = { glob = "opt/cuda/bin/ptxas" } | OutputBin,
    fatbinary = { glob = "opt/cuda/bin/fatbinary" } | OutputBin,
    nvlink = { glob = "opt/cuda/bin/nvlink" } | OutputBin,
    bin2c = { glob = "opt/cuda/bin/bin2c" } | OutputBin,
    nvcc_device_query = { glob = "opt/cuda/bin/__nvcc_device_query" } | OutputBin,
    nvcc_profile = { glob = "opt/cuda/bin/nvcc.profile" } | OutputData,
    nvvm_bin = { glob = "opt/cuda/nvvm/bin/*" } | OutputBin,
    libs = { glob = "opt/cuda/lib/*.so*" } | OutputLib,
    stubs = { glob = "opt/cuda/lib/stubs/*.so*" } | OutputLib,
    nvvm_libs = { glob = "opt/cuda/nvvm/lib64/*.so*" } | OutputLib,
    includes = { glob = "opt/cuda/include/**" } | OutputData,
    nvvm_libdevice = { glob = "opt/cuda/nvvm/libdevice/*" } | OutputData,
    pkgconfig = { glob = "opt/cuda/pkg-config/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec

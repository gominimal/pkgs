let { Attrs, BuildSpec, Local, OutputBin, Source, Test, standaloneTest, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "1.3.1" in
{
  name = "age",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/FiloSottile/age/v%{version}.tar.gz",
      sha256 = "396007bc0bc53de253391493bda1252757ba63af1a19db86cfb60a35cb9d290a",
      extract = true,
      strip_prefix = "age-%{version}",
    } | Source,
    base,
    go,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    age = { glob = "usr/bin/age" } | OutputBin,
    age-keygen = { glob = "usr/bin/age-keygen" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "FiloSottile",
        repo = "age",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/age --version",

    encrypt_decrypt =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo uwu_text > plaintext"],
          ["/bin/age-keygen", "-o", "key.txt"],
          ["/bin/age", "-e", "-i", "key.txt", "-o", "ciphertext", "plaintext"],
          ["/bin/age", "-d", "-i", "key.txt", "-o", "plaintext2", "ciphertext"],
          ["/bin/diff", "-q", "plaintext", "plaintext2"],
        ],
      } | Test,
  },
} | BuildSpec

let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let attr = import "../attr/build.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "2.8" in
{
  name = "patch",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/patch-%{version}.tar.xz",
      sha256 = "f87cee69eec2b4fcbf60a396b030ad6aa3415f192aa5f7ee84cad5e11f7f5ae3"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    attr,
  ],

  cmd = "./build.sh",
  outputs = {
    patch = { glob = "usr/bin/patch" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "patch",
      source_provenance = {
        category = 'GnuProject,
        name = "patch",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/patch --version",

    diff_and_apply =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'line1\nline2\nline3' > original.txt"],
          ["/bin/bash", "-c", "echo 'line1\nmodified line\nline3' > modified.txt"],
          ["/bin/bash", "-c", "diff -u original.txt modified.txt > changes.patch || true"], # files differ
          ["/bin/bash", "-c", "cp original.txt original_copy.txt"],
          ["/bin/patch", "original_copy.txt", "changes.patch"],
          ["/bin/diff", "-q", "original_copy.txt", "modified.txt"], # files match
        ],
      } | Test,
  },
} | BuildSpec

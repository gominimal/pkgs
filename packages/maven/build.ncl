let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let jdk = import "../jdk/build.ncl" in

let version = "3.9.12" in
{
  name = "maven",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://archive.apache.org/dist/maven/maven-3/%{version}/binaries/apache-maven-%{version}-bin.tar.gz",
      sha256 = "fa2c9948729296c23afd18fd01a90f62cdda09a46191b54a8bc3764c2eee812e",
    } | Source,
    base,
  ],
  runtime_deps = [
    jdk,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    mvn = { glob = "usr/bin/mvn" } | OutputBin,
    maven_home = { glob = "usr/share/maven/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,

  tests = {
    version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "mvn --version 2>&1 | grep -q 'Apache Maven'"],
        ],
      } | Test,
  },
} | BuildSpec

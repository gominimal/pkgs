let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let patchelf = import "../patchelf/build.ncl" in

let version = "3.10.0" in
{
  name = "maven",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://archive.apache.org/dist/maven/maven-3/%{version}/binaries/apache-maven-%{version}-bin.tar.gz",
      sha256 = "a46cc51bc74fa23fd267c7a0b9132b146dcf526da60d31aa5174e565632e9e0e",
    } | Source,
    base,
    binutils, # objdump: verify the version-needs rewrite (build.sh)
    patchelf, # repoints libjlinenative's stale libutil.so.1 dependency at libc (build.sh)
  ],
  runtime_deps = [
    bash, # mvn is a shell script
    glibc, # libjlinenative.so (JLine's native terminal support, 3.10.0+)
    jdk,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    mvn = { glob = "usr/bin/mvn" } | OutputBin,
    # Maven 3.10.0 bundles JLine's native terminal library; bin/mvn points JLine
    # at it with -Dlibrary.jline.path=$MAVEN_HOME/lib/jline-native, which looks
    # under <OS>/<arch>/. build.sh keeps only Linux/<host arch>. Declared as a
    # library, with maven_home's data glob allowed to span it -- the same split
    # packages/jdk uses for usr/lib/jvm/lib.
    jline_native = { glob = "usr/share/maven/lib/jline-native/**/*.so" } | OutputLib,
    maven_home = { glob = "usr/share/maven/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      binary_from = "https://archive.apache.org/dist/maven/",
      license_spdx = "Apache-2.0",
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

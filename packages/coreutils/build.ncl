let { standaloneTest, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash = import "../bash/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let grep = import "../grep/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
# other
let acl = import "../acl/build.ncl" in
let attr = import "../attr/build.ncl" in
let libcap = import "../libcap/build.ncl" in
let gmp = import "../gmp/build.ncl" in

let version = "9.9" in
{
  name = "coreutils",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/coreutils-%{version}.tar.xz",
      sha256 = "19bcb6ca867183c57d77155eae946c5eced88183143b45ca51ad7d26c628ca75"
    } | Source,
    # base
    bash,
    bzip2,
    coreutils,
    diffutils,
    file,
    findutils,
    gawk,
    grep,
    gzip,
    make,
    perl,
    sed,
    tar,
    xz,
    # toolchain
    binutils,
    gcc,
    glibc,
    linux_headers,
    # other
    attr,
    libcap,
  ],
  runtime_deps = [
    acl,
    glibc,
    gmp,
    libcap,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    # Core file operations
    ls = { glob = "usr/bin/ls" } | OutputBin,
    cp = { glob = "usr/bin/cp" } | OutputBin,
    mv = { glob = "usr/bin/mv" } | OutputBin,
    rm = { glob = "usr/bin/rm" } | OutputBin,
    mkdir = { glob = "usr/bin/mkdir" } | OutputBin,
    rmdir = { glob = "usr/bin/rmdir" } | OutputBin,
    ln = { glob = "usr/bin/ln" } | OutputBin,
    chmod = { glob = "usr/bin/chmod" } | OutputBin,
    chown = { glob = "usr/bin/chown" } | OutputBin,
    chgrp = { glob = "usr/bin/chgrp" } | OutputBin,

    # Text utilities
    cat = { glob = "usr/bin/cat" } | OutputBin,
    head = { glob = "usr/bin/head" } | OutputBin,
    tail = { glob = "usr/bin/tail" } | OutputBin,
    sort = { glob = "usr/bin/sort" } | OutputBin,
    uniq = { glob = "usr/bin/uniq" } | OutputBin,
    cut = { glob = "usr/bin/cut" } | OutputBin,
    tr = { glob = "usr/bin/tr" } | OutputBin,
    wc = { glob = "usr/bin/wc" } | OutputBin,

    # System utilities
    date = { glob = "usr/bin/date" } | OutputBin,
    whoami = { glob = "usr/bin/whoami" } | OutputBin,
    id = { glob = "usr/bin/id" } | OutputBin,
    pwd = { glob = "usr/bin/pwd" } | OutputBin,
    uname = { glob = "usr/bin/uname" } | OutputBin,

    # Catch-all
    bins = { glob = "usr/bin/*" } | OutputBin,

    libstdbuf = { glob = "usr/libexec/coreutils/libstdbuf.so" } | OutputLib,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    repology_project = "coreutils",
  },

  replace_on_cycle =
    {
      name = "coreutils (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/coreutils/00a9b94dccfb74f487297cfbb7e89aeb26c615fac4ea2f46ce7b18e3bcdfabe0.tar.zst",
              sha256 = "f9fb6b4833ee57860479f1fa653b1894ef56886c652cd646b0d5fd6a50ddbc8b",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/coreutils/arm64-linux-gnu/coreutils_9.10_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "b6819ee13b556ddcc6e39a2999482bc31fa55128e308b52ceb1a9d76e35afd24",
              extract = true,
            } | Source,
        } target,
      ],
      runtime_deps = [
        acl,
        glibc,
        gmp,
        libcap,
      ],
      outputs = {
        usr_bin = { glob = "usr/bin/**/*" } | OutputLib,
        usr_libexec = { glob = "usr/libexec/**/*" } | OutputLib,
        usr_share = { glob = "usr/share/**/*" } | OutputLib,
      },
    } | BuildSpec,

  tests = {
    smoketest_cut = standaloneTest "/bin/cut --version",

    cut =
      {
        class = 'Standalone,
        test_deps = [bash, diffutils, grep],
        cmds = [
          ["/bin/bash", "-c", "echo 'a,b,c,d\ne,f,g,h' > csv.txt"],
          ["/bin/bash", "-c", "cut -d, -f2 csv.txt > field2.txt"],
          ["/bin/bash", "-c", "echo 'b\nf' > expected_field2.txt"],
          ["/bin/diff", "-q", "field2.txt", "expected_field2.txt"],
          ["/bin/bash", "-c", "echo 'hello world' > text.txt"],
          ["/bin/bash", "-c", "cut -c1-5 text.txt | grep -q '^hello$'"],
        ],
      } | Test,
    sort =
      {
        class = 'Standalone,
        test_deps = [bash, diffutils, grep],
        cmds = [
          ["/bin/bash", "-c", "echo 'zebra\napple\nbanana' > unsorted.txt"],
          ["/bin/bash", "-c", "sort unsorted.txt > sorted.txt"],
          ["/bin/bash", "-c", "echo 'apple\nbanana\nzebra' > expected_sort.txt"],
          ["/bin/diff", "-q", "sorted.txt", "expected_sort.txt"],
          ["/bin/bash", "-c", "echo '10\n2\n1\n20' > numbers.txt"],
          ["/bin/bash", "-c", "sort -n numbers.txt > sorted_nums.txt"],
          ["/bin/bash", "-c", "echo '1\n2\n10\n20' > expected_nums.txt"],
          ["/bin/diff", "-q", "sorted_nums.txt", "expected_nums.txt"],
        ],
      } | Test,
    tr =
      {
        class = 'Standalone,
        test_deps = [bash, diffutils, grep],
        cmds = [
          ["/bin/bash", "-c", "echo 'hello world' | tr 'a-z' 'A-Z' > upper.txt"],
          ["/bin/bash", "-c", "echo 'HELLO WORLD' > expected_upper.txt"],
          ["/bin/diff", "-q", "upper.txt", "expected_upper.txt"],
          # squeeze spaces
          ["/bin/bash", "-c", "echo 'hello  world' | tr -s ' ' | grep -q '^hello world$'"],
          # delete digits
          ["/bin/bash", "-c", "echo 'hello123world' | tr -d '0-9' | grep -q '^helloworld$'"],
        ],
      } | Test,
    wc =
      {
        class = 'Standalone,
        test_deps = [bash, gawk, grep],
        cmds = [
          ["/bin/bash", "-c", "echo 'one two three\nfour five' > count.txt"],
          ["/bin/bash", "-c", "wc -l count.txt | awk '{print $1}' | grep -q '^2$'"], # 2 lines
          ["/bin/bash", "-c", "wc -w count.txt | awk '{print $1}' | grep -q '^5$'"], # 5 words
        ],
      } | Test,
    head_tail =
      {
        class = 'Standalone,
        test_deps = [bash, diffutils, grep],
        cmds = [
          ["/bin/bash", "-c", "seq 1 100 > numbers.txt"],
          ["/bin/bash", "-c", "head -n 5 numbers.txt > first5.txt"],
          ["/bin/bash", "-c", "seq 1 5 > expected_first5.txt"],
          ["/bin/diff", "-q", "first5.txt", "expected_first5.txt"],
          ["/bin/bash", "-c", "tail -n 5 numbers.txt > last5.txt"],
          ["/bin/bash", "-c", "seq 96 100 > expected_last5.txt"],
          ["/bin/diff", "-q", "last5.txt", "expected_last5.txt"],
        ],
      } | Test,
    sha256sum =
      {
        class = 'Standalone,
        test_deps = [bash, diffutils],
        cmds = [
          ["/bin/bash", "-c", "echo 'content' > hashtest.txt"],
          ["/bin/bash", "-c", "sha256sum hashtest.txt > hash1.txt"],
          ["/bin/bash", "-c", "sha256sum hashtest.txt > hash2.txt"],
          ["/bin/diff", "-q", "hash1.txt", "hash2.txt"], # verify match
          ["/bin/bash", "-c", "echo 'different' > hashtest.txt"],
          ["/bin/bash", "-c", "sha256sum hashtest.txt > hash3.txt"],
          ["/bin/bash", "-c", "! diff -q hash1.txt hash3.txt"], # verify hashes differ
        ],
      } | Test,
  },
} | BuildSpec

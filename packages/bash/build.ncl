let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let glibc = import "../glibc/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let readline = import "../readline/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in

let version = "5.3" in
{
  name = "bash",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/bash-%{version}.tar.gz",
      sha256 = "0d5cd86965f869a26cf64f4b71be7b96f90a3ba8b3d74e27e8e9d9d5550f31ba",
      extract = true,
    } | Source,
    bash,
    coreutils,
    gawk,
    grep,
    make,
    sed,
    # toolchain
    binutils,
    gcc,
    linux_headers,
  ],
  runtime_deps = [
    glibc,
    ncurses,
    readline,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bash = { glob = "usr/bin/bash" } | OutputBin,
    sh = { glob = "usr/bin/sh" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "bash",
      source_provenance = {
        category = 'GnuProject,
        name = "bash",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "bash (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/bash/0932485779c77fb91805ea37baf5a97b6c64f1f45d2794b10f61eb0d805928d0.tar.zst",
              sha256 = "bdb617c43eb4ba70f72a3a9750266cd57cb1cbc77db19e50366f50cacc5afcd7",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/bash/arm64-linux-gnu/bash_5.3_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "18e646fe5574af691d2ec7ca85a78faf6abc0b79fbb45b2cd8263e1912771ac6",
              extract = true,
            } | Source,
        } target,
      ],
      runtime_deps = [
        glibc,
        ncurses,
        readline,
      ],
      outputs = {},
    } | BuildSpec,

  tests = {
    arithmetic =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "echo $((2 + 2)) > result.txt"],
          ["/bin/bash", "-c", "grep -q '^4$' result.txt"],
          ["/bin/bash", "-c", "echo $((10 * 5)) | grep -q '^50$'"],
          ["/bin/bash", "-c", "echo $((100 / 4)) | grep -q '^25$'"],
        ],
      } | Test,
    variables =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "VAR='hello world'; echo $VAR > var.txt"],
          ["/bin/bash", "-c", "grep -q '^hello world$' var.txt"],
          ["/bin/bash", "-c", "X=10; Y=20; echo $((X + Y)) | grep -q '^30$'"],
        ],
      } | Test,
    string_ops =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "STR='hello'; echo ${#STR} | grep -q '^5$'"], # string length
          ["/bin/bash", "-c", "STR='hello world'; echo ${STR#hello } | grep -q '^world$'"], # remove prefix
          ["/bin/bash", "-c", "STR='hello world'; echo ${STR% world} | grep -q '^hello$'"], # remove suffix
          ["/bin/bash", "-c", "STR='hello world'; echo ${STR/world/universe} | grep -q '^hello universe$'"], # substitution
        ],
      } | Test,
    conditionals =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "if [ 5 -gt 3 ]; then echo 'yes' > cond.txt; fi"],
          ["/bin/bash", "-c", "grep -q '^yes$' cond.txt"],
          ["/bin/bash", "-c", "if [ 'abc' = 'abc' ]; then echo 'equal'; else echo 'not equal'; fi | grep -q '^equal$'"],
          ["/bin/bash", "-c", "if [ -f /bin/bash ]; then echo 'exists'; fi | grep -q '^exists$'"],
          ["/bin/bash", "-c", "true && echo 'and works' > logic.txt"],
          ["/bin/bash", "-c", "grep -q '^and works$' logic.txt"],
          ["/bin/bash", "-c", "false || echo 'or works' | grep -q '^or works$'"],
          ["/bin/bash", "-c", "[ 1 -eq 1 ] && [ 2 -eq 2 ] && echo 'both true' | grep -q '^both true$'"],
        ],
      } | Test,
    test_exps =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "[ 10 -eq 10 ] && echo 'true' > test1.txt"],
          ["/bin/bash", "-c", "grep -q '^true$' test1.txt"],
          ["/bin/bash", "-c", "[ 5 -lt 10 ] && echo 'less' | grep -q '^less$'"],
          ["/bin/bash", "-c", "[ 'abc' != 'xyz' ] && echo 'different' | grep -q '^different$'"],
          ["/bin/bash", "-c", "touch testfile && [ -f testfile ] && echo 'file exists' | grep -q '^file exists$'"],
        ],
      } | Test,
    for_loop =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "for i in 1 2 3; do echo $i; done > loop.txt"],
          ["/bin/bash", "-c", "wc -l < loop.txt | grep -q '^3$'"],
          ["/bin/bash", "-c", "for i in {1..5}; do echo $i; done > range.txt"],
          ["/bin/bash", "-c", "wc -l < range.txt | grep -q '^5$'"],
          ["/bin/bash", "-c", "tail -n1 range.txt | grep -q '^5$'"],
        ],
      } | Test,
    while_loop =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "i=1; while [ $i -le 3 ]; do echo $i; i=$((i+1)); done > while.txt"],
          ["/bin/bash", "-c", "wc -l < while.txt | grep -q '^3$'"],
        ],
      } | Test,
    case =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "VAR='two'; case $VAR in one) echo 1;; two) echo 2;; *) echo 0;; esac > case.txt"],
          ["/bin/bash", "-c", "grep -q '^2$' case.txt"],
        ],
      } | Test,
    exit_codes =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "true; echo $? > exitcode.txt"],
          ["/bin/bash", "-c", "grep -q '^0$' exitcode.txt"],
          ["/bin/bash", "-c", "false; echo $? | grep -q '^1$'"],
        ],
      } | Test,
    inline_cmds =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "echo \"Today is $(date +%Y)\" > date.txt"],
          ["/bin/bash", "-c", "grep -q '^Today is' date.txt"],
          ["/bin/bash", "-c", "FILES=$(ls /bin/bash); echo $FILES | grep -q '/bin/bash'"],
        ],
      } | Test,
    redirection =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "echo 'test data' | cat > pipe1.txt"],
          ["/bin/bash", "-c", "grep -q '^test data$' pipe1.txt"],
          ["/bin/bash", "-c", "echo 'line1' > redir.txt; echo 'line2' >> redir.txt"],
          ["/bin/bash", "-c", "wc -l < redir.txt | grep -q '^2$'"],
          ["/bin/bash", "-c", "ls /nonexistent 2> error.txt || true"],
          ["/bin/bash", "-c", "test -s error.txt"], # verify error output exists
          ["/bin/bash", "-c", "echo 'out' > both.txt 2>&1; echo 'err' >&2 >> both.txt 2>&1"],
          ["/bin/bash", "-c", "test -s both.txt"],
        ],
      } | Test,
    heredocs =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "cat > heredoc.txt << EOF\nline1\nline2\nline3\nEOF"],
          ["/bin/bash", "-c", "wc -l < heredoc.txt | grep -q '^3$'"],
          ["/bin/bash", "-c", "grep -q '^line2$' heredoc.txt"],
        ],
      } | Test,
    glob =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "touch file1.txt file2.txt file3.log"],
          ["/bin/bash", "-c", "ls file*.txt > glob.txt"],
          ["/bin/bash", "-c", "wc -l < glob.txt | grep -q '^2$'"], # only .txt files
          ["/bin/bash", "-c", "ls file[12].txt | wc -l | grep -q '^2$'"],
          ["/bin/bash", "-c", "echo {a,b,c} | grep -q 'a b c'"],
        ],
      } | Test,
  },
} | BuildSpec

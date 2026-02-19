let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let curl = import "../curl/build.ncl" in
let gettext = import "../gettext/build.ncl" in
let expat = import "../expat/build.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pcre2 = import "../pcre2/build.ncl" in
let python = import "../python/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "2.52.0" in
{
  name = "git",
  inputs = [
    { file = "build.sh" } | Local,
    {
      # https://www.kernel.org/pub/software/scm/git/git-2.52.0.tar.xz
      url = "gs://minimal-staging-archives/git-%{version}.tar.xz",
      sha256 = "3cd8fee86f69a949cb610fee8cd9264e6873d07fa58411f6060b3d62729ed7c5",
      extract = true,
      strip_prefix = "git-%{version}",
    } | Source,
    base,
    gettext,
    make,
    python,
    toolchain,
  ],
  runtime_deps = [
    curl,
    expat,
    openssl,
    pcre2,
    zlib,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    git_core = { glob = "usr/libexec/git-core/*", allow_data = true } | OutputLib,
    git_core_mergetools = { glob = "usr/libexec/git-core/mergetools/*", allow_data = true } | OutputLib,

    locale = { glob = "usr/share/locale/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "git",
      source_provenance = {
        category = 'GithubRepo,
        owner = "git",
        repo = "git",
      },
    } | Attrs,

  tests = {
    basic_repo_ops =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "git config --global user.email 'test@example.com'"],
          ["/bin/bash", "-c", "git config --global user.name 'Test User'"],
          ["/bin/bash", "-c", "mkdir repo && cd repo && git init"],
          ["/bin/bash", "-c", "cd repo && echo 'hello' > file.txt && git add file.txt"],
          ["/bin/bash", "-c", "cd repo && git commit -m 'initial commit'"],
          ["/bin/bash", "-c", "cd repo && git log --oneline | grep -q 'initial commit'"],
          ["/bin/bash", "-c", "cd repo && echo 'world' >> file.txt && git add file.txt"],
          ["/bin/bash", "-c", "cd repo && git commit -m 'second commit'"],
          ["/bin/bash", "-c", "cd repo && git log --oneline | wc -l | grep -q '^2$'"], # verify 2 commits
          ["/bin/bash", "-c", "cd repo && git checkout -b newbranch"],
          ["/bin/bash", "-c", "cd repo && git branch | grep -q '\\* newbranch'"], # verify on new branch
          ["/bin/bash", "-c", "cd repo && echo 'branch content' > branch.txt && git add branch.txt && git commit -m 'branch commit'"],
          ["/bin/bash", "-c", "cd repo && git checkout master || git checkout main"],
          ["/bin/bash", "-c", "cd repo && ! test -f branch.txt"], # verify file doesn't exist on main branch
        ],
      } | Test,
  },
} | BuildSpec

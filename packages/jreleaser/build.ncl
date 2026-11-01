let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let git = import "../git/build.ncl" in
let jdk = import "../jdk/build.ncl" in
let sed = import "../sed/build.ncl" in
let unzip = import "../unzip/build.ncl" in

let version = "1.27.0" in
{
  name = "jreleaser",
  # JReleaser automates releases: changelogs, GitHub/GitLab/Gitea releases,
  # packagers (Homebrew, SDKMAN!, Scoop, ...), Maven Central deploys, and
  # announcements.
  #
  # The upstream JVM distribution (bin/ launcher + lib/ jars), run on our jdk.
  # Upstream also ships per-arch GraalVM native zips; the JVM zip is one
  # architecture-independent artifact (one sha256, no per-arch dispatch) and
  # runs on the same JDK as the rest of the Java tooling. Its bytecode targets
  # Java 8, so any packaged jdk runs it.
  #
  # Prebuilt, not built from source: the build is Gradle resolving from Maven
  # Central. Same tradeoff as maven / gradle / jdtls.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/jreleaser/jreleaser/releases/download/v%{version}/jreleaser-%{version}.zip",
      sha256 = "3e9b9131ad4e8445b007c234d219ea09482f59aaeb891b12bfec4e16c7cdfa44",
    } | Source,
    base,
    unzip,
  ],
  runtime_deps = [
    bash, # usr/bin/jreleaser and bin/jreleaser are /bin/sh scripts (#!/usr/bin/env sh)
    coreutils, # env, uname, ls, tr in the launcher
    findutils, # xargs (the launcher dies without it)
    jdk,
    sed, # the launcher's JAVA_OPTS quoting
  ],
  # Not for jreleaser's own build (that is offline): this is the abstract
  # network dep a consumer inherits. Releasing means talking to git forges,
  # Maven Central, package registries and announcers, like jbang/curl/uv.
  # Local steps (init, config, changelog, assemble) run offline; see tests.
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    jreleaser = { glob = "usr/bin/jreleaser" } | OutputBin,
    # allow_executable: the tree carries upstream's bin/jreleaser launcher,
    # which /usr/bin/jreleaser execs (the same split as pmd and spotbugs).
    jreleaser_home = { glob = "usr/share/jreleaser/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # JReleaser's own code. lib/ also bundles jars under BSD-2-Clause,
      # BSD-2-Clause-FreeBSD, Bouncy Castle (MIT-style), CC0-1.0, EDL-1.0,
      # MIT and the jzlib licence; their texts ship in licenses/ (build.sh).
      license_spdx = "Apache-2.0",
      binary_from = "https://github.com/jreleaser/jreleaser/releases",
      source_provenance = {
        category = 'GithubRepo,
        owner = "jreleaser",
        repo = "jreleaser",
      },
    } | Attrs,

  tests = {
    # Not named `version`: that would shadow %{version} inside the tests block.
    jreleaser_version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "jreleaser --version > out.txt 2>&1; grep -qx 'jreleaser %{version}' out.txt"],
        ],
      } | Test,

    # `init` writes a starter jreleaser.yml from the bundled templates.
    init =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              mkdir proj && cd proj
              jreleaser init --format yml
              grep -q '^# Generated with JReleaser %{version} at ' jreleaser.yml
              grep -qx 'project:' jreleaser.yml
              grep -qx '  name: app' jreleaser.yml
            "%
          ],
        ],
      } | Test,

    # A real offline release step: a git repo with a jreleaser.yml declaring an
    # archive assembler. `config --assembly` must parse and validate it, then
    # `assemble` must build the zip and tar.gz with the declared file. The JVM
    # proxy is pinned to a closed local port, so any HTTP(S) attempt fails
    # instead of reaching the network; nothing here needs a forge token.
    assemble =
      {
        class = 'Standalone,
        test_deps = [base, git],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              export JAVA_OPTS="-Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=9 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=9"
              mkdir proj && cd proj
              git init -q -b main .
              mkdir src && echo hello > src/hello.txt
              cat > jreleaser.yml <<'YML'
              project:
                name: demo
                version: 1.2.3
                description: Demo
                authors: [Someone]
                license: Apache-2.0
                inceptionYear: 2026
              release:
                github:
                  owner: example
                  name: demo
              assemble:
                archive:
                  demo:
                    active: ALWAYS
                    formats: [ZIP, TAR_GZ]
                    fileSets:
                      - input: src
              YML
              git add -A
              git -c user.name=t -c user.email=t@example.com commit -q -m 'feat: init'
              git remote add origin https://github.com/example/demo.git

              jreleaser config --assembly > config.txt 2>&1 || { cat config.txt; exit 1; }
              grep -qF 'Configuring with jreleaser.yml' config.txt
              grep -qE 'name: +demo' config.txt

              jreleaser assemble > assemble.txt 2>&1 || { cat assemble.txt; exit 1; }
              grep -qF 'JReleaser succeeded' assemble.txt
              dir=out/jreleaser/assemble/demo/archive
              tar -tzf "$dir/demo-1.2.3.tar.gz" | grep -qx 'demo-1.2.3/hello.txt'
              jar tf "$dir/demo-1.2.3.zip" | grep -qx 'demo-1.2.3/hello.txt'
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec

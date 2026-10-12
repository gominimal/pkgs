let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
# The TLA+ tools (tla2tools.jar): the TLC model checker, the SANY parser and
# semantic checker, and the PlusCal translator, built from tlaplus/tlaplus
# source with the JDK alone (see build.sh), plus /usr/bin launchers.
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let jdk = import "../jdk/build.ncl" in

let version = "1.7.4" in
# The commit the v1.7.4 tag points at; stamped into the jar manifest, where TLC
# reads its revision from (TLC prints it in its startup banner).
let commit = "5a47802b5c391f59ecdd44117981f4ff8c0656ba" in
{
  name = "tlaplus",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "DeterministicJar.java" } | Local,
    {
      # refs/tags/ is spelled out: upstream also has a *branch* named v1.7.4.
      url = "https://github.com/tlaplus/tlaplus/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "eb4e54b6c8dc4945cbd697dbfe55819b6fc3f13fe9561afd7d6523c18ea4c350",
      extract = true,
      strip_prefix = "tlaplus-%{version}",
    } | Source,
    base,
  ],
  runtime_deps = [
    bash, # the launchers are /bin/sh scripts
    jdk,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include commit,
  },

  outputs = {
    tlc = { glob = "usr/bin/tlc" } | OutputBin,
    sany = { glob = "usr/bin/sany" } | OutputBin,
    pcal = { glob = "usr/bin/pcal" } | OutputBin,
    jar = { glob = "usr/share/tlaplus/tla2tools.jar" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # MIT is TLA+ itself. tla2tools.jar also bundles the class files of two
      # jars upstream vendors prebuilt in lib/javax.mail/ (as upstream's own
      # jar does): Jakarta Mail 1.6.3 (EPL-2.0 / GPL-2.0 with Classpath
      # exception / EDL-1.0 = BSD-3-Clause) and Apache Geronimo Activation 1.1
      # (Apache-2.0).
      license_spdx = "MIT AND Apache-2.0 AND (EPL-2.0 OR GPL-2.0-only WITH Classpath-exception-2.0 OR BSD-3-Clause)",
      source_provenance = {
        category = 'GithubRepo,
        owner = "tlaplus",
        repo = "tlaplus",
      },
    } | Attrs,

  tests = {
    # SANY must accept a well-formed module, report a semantic error, and fail
    # on a parse error.
    sany =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              cat > Good.tla <<'EOF'
              ---- MODULE Good ----
              EXTENDS Naturals
              VARIABLE x
              Init == x = 0
              Next == x' = (x + 1) % 3
              ====
              EOF
              sany Good.tla > good.out 2>&1 || { cat good.out; exit 1; }
              grep -q 'Semantic processing of module Good' good.out
              # A semantic error is reported, but SANY 1.7.4 still exits 0 on
              # one (only parse errors set the exit status), so read the output.
              cat > Bad.tla <<'EOF'
              ---- MODULE Bad ----
              VARIABLE x
              Init == x = Undefined
              ====
              EOF
              sany Bad.tla > bad.out 2>&1 || true
              grep -q "Unknown operator: .Undefined" bad.out
              # A parse error must fail the run.
              cat > Syn.tla <<'EOF'
              ---- MODULE Syn ----
              VARIABLE x
              Init == x = = 0
              ====
              EOF
              if sany Syn.tla > syn.out 2>&1; then cat syn.out; exit 1; fi
              grep -q 'Parse Error' syn.out
            "%,
          ],
        ],
      } | Test,

    # TLC must find a real invariant violation (and exit non-zero) and must
    # verify a correct model to completion.
    tlc =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              cat > Counter.tla <<'EOF'
              ---- MODULE Counter ----
              EXTENDS Naturals
              VARIABLE x
              Init == x = 0
              Next == x' = (x + 1) % 6
              TypeOK == x \in 0..5
              Small == x < 3
              ====
              EOF
              printf 'INIT Init\nNEXT Next\nINVARIANT TypeOK\n' > Good.cfg
              printf 'INIT Init\nNEXT Next\nINVARIANT Small\n' > Bad.cfg
              tlc -workers 1 -config Good.cfg Counter.tla > good.out 2>&1 || { cat good.out; exit 1; }
              grep -q 'Model checking completed. No error has been found.' good.out
              grep -q '6 distinct states found' good.out
              if tlc -workers 1 -config Bad.cfg Counter.tla > bad.out 2>&1; then cat bad.out; exit 1; fi
              grep -q 'Invariant Small is violated.' bad.out
              grep -q 'x = 3' bad.out
            "%,
          ],
        ],
      } | Test,

    # pcal must translate a (fair) PlusCal algorithm into a TLA+ spec that TLC
    # then checks, including the liveness property Termination pcal generates.
    pcal =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              cat > Inc.tla <<'EOF'
              ---- MODULE Inc ----
              EXTENDS Naturals
              (* --fair algorithm inc
              variable x = 0;
              begin
                A: x := x + 1;
                B: x := x + 1;
              end algorithm; *)
              \* BEGIN TRANSLATION
              \* END TRANSLATION
              ====
              EOF
              pcal -nocfg Inc.tla > pcal.out 2>&1 || { cat pcal.out; exit 1; }
              grep -q '^Next ==' Inc.tla
              grep -q '^Spec ==' Inc.tla
              printf 'SPECIFICATION Spec\nPROPERTY Termination\n' > Inc.cfg
              tlc -workers 1 -config Inc.cfg Inc.tla > tlc.out 2>&1 || { cat tlc.out; exit 1; }
              grep -q 'Model checking completed. No error has been found.' tlc.out
              grep -q 'Checking temporal properties' tlc.out
            "%,
          ],
        ],
      } | Test,
  },
} | BuildSpec

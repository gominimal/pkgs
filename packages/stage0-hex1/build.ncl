let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let hex0 = import "../hex0/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
# stage0-hex1 — the FIRST attested from-source rung of the bedrock ladder.
#
# Driven by our attested bash + coreutils (NOT upstream kaem; kaem deferral is
# B1.5). build.sh (1) self-reproduces hex0 from its own auditable hex0-language
# source using ONLY the trusted seed and asserts byte-identity (the bedrock
# fixed point), then (2) assembles the DISTINCT hex1 assembler from auditable
# source, driven by the just-reproduced hex0.
#
# Trust-base note: predecessors are EXACTLY { bash, coreutils } — identical to
# the proven synthetic bedrock-rung{1..4} fixture, so the CHAIN_ENFORCE=1
# fail-shut precondition set is unchanged (no diffutils: the byte-identity
# assertion uses coreutils' sha256sum, not diffutils' cmp). The seed enters as
# the SOLE bootstrap_artifacts terminal leaf via the hex0 build_dep.
#
# The .hex0/.hex1 sources come from a sha256-pinned gs:// Source tarball (the
# full recursive stage0-posix-1.9.1 tree incl. the AMD64 submodule), so the
# source provenance is recorded as a sha-pinned resolvedDependency in the
# attestation. extract=true + `cd stage0-posix-1.9.1` mirrors the bash recipe.
#
# Outputs are static ELFs (no DT_NEEDED, no .interp) -> no runtime_deps and
# allow_missing_interpreter=true on each OutputBin. hex0 is a pure byte
# transform (no timestamps, no -j) so both outputs are bit-reproducible.
{
  name = "stage0-hex1",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/stage0-posix-1.9.1.tar.zst",
      sha256 = "33108c8c1271a12c3eae9509dff4c10c55b7475548cf5d370778eaf7138194df",
      extract = true,
    } | Source,
    hex0, # Build dep -> seed hardlinked into rootfs at /usr/bin/hex0
    bash, # build.sh interpreter (attested base; folded under CHAIN_ENFORCE)
    coreutils, # sha256sum/cut/head/od/tr/cp/mkdir/chmod (attested base)
  ],
  cmd = "./build.sh",
  outputs = {
    # self-reproduced, audited monitor (byte-identical to the seed):
    hex0 = { glob = "usr/bin/hex0", allow_missing_interpreter = true } | OutputBin,
    # the first net-new from-source tool:
    hex1 = { glob = "usr/bin/hex1", allow_missing_interpreter = true } | OutputBin,
  },
} | BuildSpec

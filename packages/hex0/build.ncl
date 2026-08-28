let { BuildSpec, Local, OutputBin, .. } = import "minimal.ncl" in
# hex0 — seed carrier. NEVER built from source: the 229-byte hand-auditable
# hex0-seed (oriansj/stage0-posix Release_1.9.1, AMD64) is delivered via
# trust-config `bootstrap_artifacts` and hydrated into THIS spec's cache slot
# by the builder's Pass-3 (breaker_hydrate.rs). The planner then sees the slot
# as cached and never runs `cmd`. The build.sh is a loud guard that fails if
# the bootstrap_artifacts entry is ever missing/mis-named (so we never silently
# ship an empty or un-pinned seed). allow_missing_interpreter=true because the
# seed is a static ELF with no .interp (same flag gzip uses for static bins).
{
  name = "hex0",
  build_deps = [{ file = "build.sh" } | Local],
  cmd = "./build.sh",
  outputs = {
    hex0 = { glob = "usr/bin/hex0", allow_missing_interpreter = true } | OutputBin,
  },
} | BuildSpec

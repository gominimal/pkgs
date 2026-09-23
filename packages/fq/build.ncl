let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let version = "0.18.0" in
{
  name = "fq",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    go,
    toolchain,
    {
      url = "https://github.com/wader/fq/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "2580de6fb21281a262f99f24d585a925cef71f158c2b24a34125e1b29bc612ef",
      extract = true,
      strip_prefix = "fq-%{version}",
    } | Source,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,
  cmd = "./build.sh",
  outputs = {
    fq = { glob = "usr/bin/fq" } | OutputBin,
  },
  # Empty by design: built CGO_ENABLED=0, so the binary is pure-Go static with
  # no DT_NEEDED at all. Same shape as `helm`. If CGO ever creeps back in, the
  # `missing runtime_deps` checker is what notices.
  runtime_deps = [],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "wader", repo = "fq" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoketest = standaloneTest "/bin/fq --version",

    # DECODE SOMETHING. `fq --version` and even `fq -n '1+1'` pass on a build
    # with every format decoder broken or absent: the jq engine is one Go
    # package and the ~120 format decoders are another, and only the decoders
    # are the reason to ship this tool.
    #
    # The gzip case is the sharp one — asserting on `compression_method`
    # alone would only prove fq read two header bytes. Asserting on
    # `uncompressed` proves it ran the DEFLATE decoder over the payload and
    # got the original bytes back, which is the actual capability.
    decodes =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              msg="hello world hello world"
              printf '%s' "$msg" | gzip -n > /build/t.gz

              # 1. The header field decodes symbolically, not as a raw number.
              m=$(fq -d gzip -r '.members[0].compression_method | tovalue' /build/t.gz)
              [ "$m" = "deflate" ] || { echo "compression_method=$m" >&2; exit 1; }

              # 2. THE REAL ONE: fq inflated the payload and got our bytes back.
              got=$(fq -d gzip -r '.members[0].uncompressed | tostring' /build/t.gz)
              [ "$got" = "$msg" ] || {
                echo "inflate mismatch: '$got' != '$msg'" >&2; exit 1; }
            "%
          ],
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              # 3. A second, unrelated decoder over a real file: fq's own ELF.
              #
              # Derived from uname rather than hardcoded — an earlier package
              # in this loadout pinned an architecture literal and only failed
              # once it reached amd64 CI. fq renders EM_ARM64 as "arm64" and
              # EM_X86_64 as "x86_64" (format/elf/elf.go machineNames).
              case "$(uname -m)" in
                aarch64 | arm64) want=arm64 ;;
                x86_64) want=x86_64 ;;
                *) echo "unsupported arch $(uname -m)" >&2; exit 1 ;;
              esac
              got=$(fq -d elf -r '.header.machine | tovalue' /usr/bin/fq)
              [ "$got" = "$want" ] || {
                echo "elf machine: got '$got', want '$want'" >&2; exit 1; }
            "%
          ],
          # 4. The jq engine itself still works. Last, because on its own it
          #    proves the least.
          ["/bin/bash", "-c", "test \"$(fq -n '1+1')\" = 2"],
        ],
      } | Test,
  },
} | BuildSpec

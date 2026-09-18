# Imported from Wolfi `httpie` by `pkgmgr import wolfi` (python build).
# TODO: REVIEWER — verify the pypi runtime deps (install_requires) + outputs.
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let python = import "../python/build.ncl" in
let version = "3.2.4" in
{
  name = "httpie",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/httpie/httpie/archive/refs/tags/%{version}.tar.gz",
      sha256 = "b185cd8d81325f97c773582e50f1c5e047c2d8575b53d676469c9daf2a52f341",
      extract = true,
      strip_prefix = "cli-%{version}",
    } | Source,
    base,
    toolchain,
    python,
  ],
  cmd = "./build.sh",
  outputs = {
    everything = { glob = "usr/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [python],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "httpie", repo = "httpie" },
      license_spdx = "BSD-3-Clause",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # TODO: REVIEWER — ported from the Wolfi test block; verify each
          # against minimal's toolchain (bins on PATH, flags supported).
          ["/bin/bash", "-c", "http httpie https --version 2>/dev/null || http httpie https version"],
          ["/bin/bash", "-c", "http httpie https --help 2>/dev/null || http httpie https help"],
          ["/bin/bash", "-c", "set -euo pipefail\nINSTALLED=$(\"${{vars.venv-home}}/bin/python\" -c \"from importlib.metadata import version; print(version('httpie'))\")\nif [ \"$INSTALLED\" != \"${{package.version}}\" ]; then\n  echo \"FAIL: Expected httpie==${{package.version}}, got $INSTALLED\"\n  exit 1\nfi\necho \"PASS: httpie==$INSTALLED\"\nDIST_DIR=\"$(\"${{vars.venv-home}}/bin/python\" -c \"from importlib.metadata import distribution; print(distribution('httpie')._path)\")\"\nSBOM=\"${DIST_DIR}/sboms/sbom.spdx.json\"\nif [ ! -f \"$SBOM\" ]; then\n  echo \"FAIL: No SBOM found — httpie must come from Chainguard Libraries\"\n  exit 1\nfi\nif grep -q '\"Organization: Chainguard, Inc\"' \"$SBOM\"; then\n  echo \"PASS: Chainguard Libraries provenance confirmed via SBOM\"\nelse\n  echo \"FAIL: SBOM exists but not from Chainguard Libraries\"\n  exit 1\nfi"],
          ["/bin/bash", "-c", "set -euo pipefail\n# Verify urllib3 version meets CVE fix requirement (GHSA-mf9v-mfxr-j63j)\n\"${{vars.venv-home}}/bin/python\" -c \"\nfrom importlib.metadata import version\nv = version('urllib3')\nparts = [int(x) for x in v.split('.')]\nassert parts >= [2, 7, 0], f'urllib3 {v} is below required 2.7.0 (GHSA-mf9v-mfxr-j63j)'\nprint(f'PASS: urllib3=={v} meets CVE fix requirement')\n\"\n# Verify httpie can print help and version without network\nhttp --help > /dev/null\nhttp --version"],
        ],
      } | Test,
  },
} | BuildSpec

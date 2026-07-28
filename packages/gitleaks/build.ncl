# Imported from Wolfi `gitleaks` by `pkgmgr import-wolfi` (go build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "8.30.1" in
{
  name = "gitleaks",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gitleaks/gitleaks/v%{version}.tar.gz",
      sha256 = "e90fb266d75837e75894c778bf594ab8e2787f12dce5a62651f21b893eaf9abb",
      extract = true,
      strip_prefix = "gitleaks-%{version}",
    } | Source,
    base,
    go,
    toolchain,
  ],
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
    gitleaks = { glob = "usr/bin/gitleaks" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "gitleaks", repo = "gitleaks" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "gitleaks --help"],
          ["/bin/bash", "-c", "set -euo pipefail\n# Test secret detection via stdin\necho 'api_key = \"sk_live_abcdef123456\"' | gitleaks detect --source - --no-git && EXIT_CODE=0 || EXIT_CODE=$?\nif [ \"$EXIT_CODE\" != \"1\" ]; then\n  echo \"ERROR: Expected gitleaks to detect secret in stdin and exit with code 1\"\n  exit 1\nfi\n\n# Test with multiple secrets via stdin\ncat << 'EOF' | gitleaks detect --source - --no-git && EXIT_CODE=0 || EXIT_CODE=$?\naws_access_key_id = AKIAIOSFODNN7EXAMPLE\ngithub_token = ghp_wWPw5k4aXcaajCqbDsLRnJZZzVLgLO0M\nEOF\nif [ \"$EXIT_CODE\" != \"1\" ]; then\n  echo \"ERROR: Expected gitleaks to detect secrets in stdin\"\n  exit 1\nfi"],
          ["/bin/bash", "-c", "# Create custom config\ncat > test-config.toml << 'EOF'\ntitle = \"test config\"\n\n[[rules]]\nid = \"test-rule\"\ndescription = \"Test rule for API keys\"\nregex = '''test_api_key\\s*=\\s*['\"]?([A-Za-z0-9]{32})['\"]?'''\nkeywords = [\"test_api_key\"]\nEOF\n\n# Create file with custom secret pattern\necho 'test_api_key = \"abcdef1234567890abcdef1234567890\"' > test_secret.txt\n\n# Test with custom config\ngitleaks detect --source test_secret.txt --config test-config.toml --no-git --exit-code 1 || EXIT_CODE=$?\nif [ \"$EXIT_CODE\" != \"1\" ]; then\n  echo \"ERROR: Custom rule should have detected the secret\"\n  exit 1\nfi\n\nrm -f test-config.toml test_secret.txt"],
          ["/bin/bash", "-c", "# Create file with secret\necho 'api_key = \"AKIAIOSFODNN7EXAMPLE\" # gitleaks:allow' > allowed_secret.txt\n\n# This should pass because of the gitleaks:allow comment\ngitleaks detect --source allowed_secret.txt --no-git\n\n# Create .gitleaksignore file\necho 'allowed_secret2.txt' > .gitleaksignore\necho 'aws_key = \"AKIAIOSFODNN7EXAMPLE\"' > allowed_secret2.txt\n\n# This should pass because file is in .gitleaksignore\ngitleaks detect --source . --no-git\n\nrm -f allowed_secret.txt allowed_secret2.txt .gitleaksignore"],
          ["/bin/bash", "-c", "# Create initial scan with secrets\necho 'token = \"ghp_1234567890abcdef\"' > baseline_test.txt\ngitleaks detect --source baseline_test.txt --no-git --report-path baseline.json --report-format json --exit-code 1 && EXIT_CODE=0 || EXIT_CODE=$?\nif [ \"$EXIT_CODE\" != \"1\" ]; then\n  echo \"ERROR: Expected gitleaks to exit 1 when leaks found\"\n  exit 1\nfi\n\n# Using baseline should not report the same findings\ngitleaks detect --source baseline_test.txt --no-git --baseline-path baseline.json\n\nrm -f baseline_test.txt baseline.json"],
        ],
      } | Test,
  },
} | BuildSpec

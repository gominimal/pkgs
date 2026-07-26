# Imported from Wolfi `esbuild` by `pkgmgr import-wolfi` (go build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "0.28.1" in
{
  name = "esbuild",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/evanw/esbuild/v%{version}.tar.gz",
      sha256 = "65c756fa87d43178ac4a5242454c2bd0fde325f8ecf77997f8fa4b88f94d5cd2",
      extract = true,
      strip_prefix = "esbuild-%{version}",
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
  outputs = {
    esbuild = { glob = "usr/bin/esbuild" } | OutputBin,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "evanw", repo = "esbuild" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Smoke test ported from the Wolfi recipe's test block.
          ["/bin/bash", "-c", "esbuild --version"],
          ["/bin/bash", "-c", "esbuild --help"],
          ["/bin/bash", "-c", "set -euo pipefail\n\n# Create a JS file with some content that can be minified\necho 'const   x   =   1;   console.log(  x  )' > /tmp/minify-input.js\nesbuild /tmp/minify-input.js --minify --outfile=/tmp/minify-output.js\n\n# Verify the minified output is smaller than the input\ninput_size=$(wc -c < /tmp/minify-input.js)\noutput_size=$(wc -c < /tmp/minify-output.js)\nif [ \"$output_size\" -ge \"$input_size\" ]; then\n  echo \"FAIL: Minified output ($output_size bytes) should be smaller than input ($input_size bytes)\"\n  exit 1\nfi\necho \"SUCCESS: Minified from $input_size to $output_size bytes\""],
          ["/bin/bash", "-c", "set -euo pipefail\n\n# Create a TypeScript file with type annotations\necho 'const x: number = 1; console.log(x)' > /tmp/input.ts\nesbuild /tmp/input.ts --outfile=/tmp/ts-output.js\n\n# Verify the output contains the JS code without type annotations\ngrep -F 'console.log' /tmp/ts-output.js\n\n# Verify type annotation was stripped\nif grep -F ': number' /tmp/ts-output.js; then\n  echo \"FAIL: TypeScript type annotation was not stripped\"\n  exit 1\nfi\necho \"SUCCESS: TypeScript transformed to JavaScript\""],
        ],
      } | Test,
  },
} | BuildSpec

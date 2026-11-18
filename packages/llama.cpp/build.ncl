let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let git = import "../git/build.ncl" in
let patch = import "../patch/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in

let curl = import "../curl/build.ncl" in
let hwdata = import "../hwdata/build.ncl" in
let pciutils = import "../pciutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "b12359" in
{
  name = "llama.cpp",
  build_deps = [
    { file = "build.sh" } | Local,
    # CVE-2023-45663: upstream stb's TGA/HDR fix (nothings/stb cd44845) for the
    # vendored stb_image 2.30. See build.sh.
    { file = "stb-cve-2023-45663.patch" } | Local,
    # License texts and NOTICEs of everything compiled into the embedded web UI
    # (pkgs#994), generated from this version's tools/ui/package-lock.json by
    # gen-ui-notices.py. The build doesn't run it: rerun it on every bump.
    # build.sh fails if the file's header doesn't match the UI and lock it builds.
    { file = "ui-THIRD-PARTY-NOTICES" } | Local,
    {
      url = "gs://minimal-staging-archives/ggml-org/llama.cpp/%{version}.tar.gz",
      sha256 = "e2eadc0fd06f81abea3b8012584e67bea3b403d91bcd1b3072b656cbcb2fb4bb",
      extract = true,
      strip_prefix = "llama.cpp-%{version}",
    } | Source,
    {
      # llama-server's web UI for this build number, mirrored from
      # https://huggingface.co/buckets/ggml-org/llama-ui/resolve/%{version}/dist.tar.gz
      # (sha256 matches upstream's dist.tar.gz.sha256). build.sh unpacks it into
      # tools/ui/dist so the build doesn't fetch the moving `latest` UI.
      # Bump with `version`.
      url = "gs://minimal-staging-archives/ggml-org/llama-ui/%{version}-dist.tar.gz",
      sha256 = "273d1d4e410715f4832579c97868e128d80946c1bde86d682ab06b4b8440933b",
      extract = false,
    } | Source,
    base,
    git,
    patch,
    make,
    cmake,
    toolchain,
  ],
  runtime_deps = [
    curl,
    hwdata,
    pciutils,
    subsetOf gcc ["libgcc", "libstdcpp", "libgomp"],
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    llama-server = { glob = "usr/bin/llama-server" } | OutputBin,
    llama-cli = { glob = "usr/bin/llama-cli" } | OutputBin,

    libs = { glob = "usr/lib/*" } | OutputLib,
    # ui-THIRD-PARTY-NOTICES: the web UI's third-party license texts (pkgs#994).
    licenses = { glob = "usr/share/licenses/llama.cpp/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # llama.cpp itself is MIT. What ships also carries:
      # - vendor/ C++: cpp-httplib, nlohmann/json (MIT); miniaudio, stb,
      #   sheredom/subprocess.h (public domain or Unlicense).
      # - The embedded web UI (llama-ui dist for this build, in
      #   libllama-server-impl.so): 362 npm packages from tools/ui's
      #   package-lock.json. Mostly MIT and ISC, plus BSD-3-Clause (d3 modules,
      #   highlight.js), Apache-2.0 (pdfjs-dist, dexie, @internationalized/date,
      #   @swc/helpers, @chevrotain/types, aria-query, axobject-query),
      #   BSD-2-Clause (entities, json-schema-typed), DOMPurify
      #   (MPL-2.0 OR Apache-2.0; Apache-2.0 taken), robust-predicates
      #   (Unlicense), tslib (0BSD). The KaTeX fonts embedded in its CSS are MIT.
      #   The llama.cpp logo, favicons and app icons are from ggml-org's
      #   llama-brand: CC-BY-NC-4.0, plus its BRAND-USAGE.md grant to
      #   redistribute them, commercially too, in software packages. That grant
      #   has no SPDX id, so CC-BY-NC-4.0 is left out of the expression below.
      # The minified bundle carries no license texts or NOTICE files, so every
      # one is in ui-THIRD-PARTY-NOTICES (pkgs#994), installed under
      # usr/share/licenses/llama.cpp and generated from the lock by
      # gen-ui-notices.py: the npm packages plus 3 libraries vendored in
      # tools/ui/src/lib/vendors (nerdamer-prime, decimal.js: MIT; big-integer:
      # Unlicense).
      license_spdx = "MIT AND Apache-2.0 AND BSD-3-Clause AND BSD-2-Clause AND ISC AND 0BSD AND Unlicense",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ggml-org",
        repo = "llama.cpp",
      },
      build_cost_multiple = 3,
    } | Attrs,

  # No test_deps: base would mask a missing library. Both binaries exited 127
  # (libllama.so.0 etc. not shipped) before build.sh kept the SONAME links.
  tests = {
    llama-cli = standaloneTest "/usr/bin/llama-cli --version",
    llama-server = standaloneTest "/usr/bin/llama-server --version",
    # The web UI's notices ship, for this UI version, with the texts that must
    # travel: svelte (MIT), dompurify (MPL-2.0 OR Apache-2.0, both texts) and
    # pdfjs-dist (Apache-2.0; its npm package has no NOTICE, which is recorded).
    ui-notices =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "grep -qx 'llama-ui version: %{version}' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES"],
          ["/bin/bash", "-c", "grep -qx 'svelte@[0-9.]*' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES && grep -qx 'dompurify@[0-9.]*' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES"],
          ["/bin/bash", "-c", "grep -A4 -x 'pdfjs-dist@[0-9.]*' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES | grep -qx 'License: Apache-2.0'"],
          ["/bin/bash", "-c", "grep -A4 -x 'pdfjs-dist@[0-9.]*' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES | grep -qx 'NOTICE: none in the package'"],
          ["/bin/bash", "-c", "grep -q 'Apache License' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES && grep -q 'Mozilla Public License' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES"],
        ],
      } | Test,
  },
} | BuildSpec

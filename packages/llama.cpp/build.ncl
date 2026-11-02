let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let git = import "../git/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let curl = import "../curl/build.ncl" in
let hwdata = import "../hwdata/build.ncl" in
let pciutils = import "../pciutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "b11960" in
{
  name = "llama.cpp",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ggml-org/llama.cpp/%{version}.tar.gz",
      sha256 = "2b37ffa871595f90b94164f6c510ad9a34bd7f94da21557cc9878587e163af37",
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
      sha256 = "edc6b05ff2621f5f08cee4e79cf8beb02805f21888776354dd1ddcf9fc2609e8",
      extract = false,
    } | Source,
    base,
    git,
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
  },

  attrs =
    {
      upstream_version = version,
      # llama.cpp itself is MIT. What ships also carries:
      # - vendor/ C++: cpp-httplib, nlohmann/json (MIT); miniaudio, stb,
      #   sheredom/subprocess.h (public domain or Unlicense).
      # - The embedded web UI (llama-ui dist for this build, in
      #   libllama-server-impl.so): 402 npm packages per tools/ui's
      #   package-lock.json. Mostly MIT and ISC, plus BSD-3-Clause (d3 modules,
      #   highlight.js), Apache-2.0 (pdfjs-dist, dexie, @internationalized/date,
      #   @swc/helpers, @chevrotain/types, aria-query, axobject-query),
      #   BSD-2-Clause (entities, json-schema-typed), DOMPurify
      #   (MPL-2.0 OR Apache-2.0; Apache-2.0 taken), robust-predicates
      #   (Unlicense), tslib (0BSD). The KaTeX fonts embedded in its CSS are MIT.
      # The minified bundle keeps only pdf.js's Apache-2.0 header and ships no
      # license texts or NOTICE files: tracked in pkgs#994.
      license_spdx = "MIT AND Apache-2.0 AND BSD-3-Clause AND BSD-2-Clause AND ISC AND 0BSD AND Unlicense",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ggml-org",
        repo = "llama.cpp",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec

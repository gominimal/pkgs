let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
# Leaflet, the browser map library. No bin: installed from the sha256-pinned registry
# tarball into a package-private prefix under /usr/libexec (the same layout `npm install
# -g --prefix` produces for `serve` and `next`), so a project can link it into node_modules.
let base = import "../base/build.ncl" in
let version = "1.9.4" in
{
  name = "leaflet",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://registry.npmjs.org/leaflet/-/leaflet-%{version}.tgz",
      sha256 = "84c65a256e50657896f54c33bd857b6849ebe94c817803be818bf32a3dde0b77",
    } | Source,
    base,
  ],
  runtime_deps = [],
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    libexec = { glob = "usr/libexec/leaflet/**" } | OutputData,
  },
  tests = {
    files =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/libexec/leaflet/lib/node_modules/leaflet/dist/leaflet.js"],
          ["/bin/bash", "-c", "test -f /usr/libexec/leaflet/lib/node_modules/leaflet/dist/leaflet.css"],
          ["/bin/bash", "-c", "grep -q '\"version\": \"%{version}\"' /usr/libexec/leaflet/lib/node_modules/leaflet/package.json"],
        ],
      } | Test,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-2-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "Leaflet",
        repo = "Leaflet",
      },
      # The registry tarball ships the rollup-built dist/ (no Leaflet build step here):
      # upstream's `npm run build` is rollup + uglify-js with rollup-plugin-git-version/
      # git-rev-sync, network-fetched devDependencies that also read a .git checkout,
      # which the npm tarball lacks. dist/ is plain JS/CSS (no native code).
      binary_from = "https://registry.npmjs.org/leaflet/-/leaflet-%{version}.tgz",
    } | Attrs,
} | BuildSpec

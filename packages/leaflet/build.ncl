let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
# Leaflet, the browser map library. No bin: installed from the sha256-pinned registry
# tarball into a package-private prefix under /usr/libexec (the same layout `npm install
# -g --prefix` produces for `serve` and `next`), so a project can link it into node_modules.
let base = import "../base/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in
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
    # Resolve and parse leaflet the way a node toolchain (bundler, SSR build) consumes it.
    # It cannot be require()d headless: dist/leaflet-src.js reads window.requestAnimationFrame
    # and document.documentElement at load (lines 230, 1935 of the 1.9.4 tarball), so
    # this compiles each UMD bundle without running it (vm.Script), which catches a
    # truncated or corrupt file, and checks:
    #   - require.resolve finds package.json "main" (dist/leaflet-src.js) under the prefix,
    #   - package.json "version" and the bundle's own `var version = "..."` (line 12, the
    #     value exported as L.version at line 14500) both equal the pinned version,
    #   - dist/leaflet.css is non-empty.
    loads =
      {
        class = 'Standalone,
        test_deps = [node-lts],
        cmds = [
          [
            "/usr/bin/node",
            "-e",
            m%%"
              const fs = require('fs');
              const path = require('path');
              const vm = require('vm');
              const want = '%%{version}';
              const dir = '/usr/libexec/leaflet/lib/node_modules/leaflet';
              const main = require.resolve('leaflet', { paths: ['/usr/libexec/leaflet/lib'] });
              console.log('require.resolve(leaflet) ->', main);
              if (main !== path.join(dir, 'dist/leaflet-src.js')) throw new Error('unexpected main: ' + main);
              const pkg = JSON.parse(fs.readFileSync(path.join(dir, 'package.json'), 'utf8'));
              console.log('package.json version', pkg.version, 'want', want);
              if (pkg.version !== want) throw new Error('package.json version mismatch');
              for (const f of ['leaflet.js', 'leaflet-src.js']) {
                const src = fs.readFileSync(path.join(dir, 'dist', f), 'utf8');
                new vm.Script(src, { filename: f });
                console.log('compiled dist/' + f, src.length, 'chars');
              }
              const decl = 'var version = "' + want + '";';
              const hasDecl = fs.readFileSync(main, 'utf8').includes(decl);
              console.log('leaflet-src.js declares', decl, hasDecl);
              if (!hasDecl) throw new Error('bundle version mismatch');
              const css = fs.statSync(path.join(dir, 'dist/leaflet.css')).size;
              console.log('dist/leaflet.css', css, 'bytes');
              if (css === 0) throw new Error('empty leaflet.css');
              console.log('OK');
            "%%
          ],
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

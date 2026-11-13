let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.413" in
{
  name = "hwdata",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/vcrhonek/hwdata/v%{version}.tar.gz",
      sha256 = "5a71ab7a48c668ef912fcfdbec046949087019f8dd7fb967445d36fbeb778350",
      extract = true,
      strip_prefix = "hwdata-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    hwdata = { glob = "usr/share/hwdata/*" } | OutputData,

    pkgconfigs = { glob = "usr/share/pkgconfig/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
      repology_project = "hwdata",
      source_provenance = {
        category = 'GithubRepo,
        owner = "vcrhonek",
        repo = "hwdata",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -e
              test -s /usr/share/hwdata/pci.ids && test -s /usr/share/hwdata/usb.ids
              while read -r l; do case $l in '8086  Intel Corporation') exit 0;; esac; done < /usr/share/hwdata/pci.ids; exit 1
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec

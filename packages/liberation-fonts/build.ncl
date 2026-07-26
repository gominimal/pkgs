let { BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in

let version = "2.1.5" in
{
  name = "liberation-fonts",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/liberationfonts/liberation-fonts/files/7261482/liberation-fonts-ttf-%{version}.tar.gz",
      sha256 = "7191c669bf38899f73a2094ed00f7b800553364f90e2637010a69c0e268f25d0",
      extract = true,
      strip_prefix = "liberation-fonts-ttf-%{version}",
    } | Source,
    base,
  ],

  cmd = "./build.sh",

  outputs = {
    fonts = { glob = "usr/share/fonts/liberation/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    license_spdx = "OFL-1.1",
    source_provenance = {
      category = 'GithubRepo,
      owner = "liberationfonts",
      repo = "liberation-fonts",
    },
  },
} | BuildSpec

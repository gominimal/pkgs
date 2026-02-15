let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in

let version = "26.0.1" in
{
  name = "pip",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://files.pythonhosted.org/packages/de/f0/c81e05b613866b76d2d1066490adf1a3dbc4ee9d9c839961c3fc8a6997af/pip-%{version}-py3-none-any.whl",
      sha256 = "bdb1b08f4274833d62c1aa29e20907365a2ceb950410df15fc9521bad440122b",
    } | Source,
    base,
    python,
  ],

  runtime_deps = [
    python,
  ],

  cmd = "./build.sh",
  outputs = {
    site_packages = { glob = "usr/lib/python3.13/site-packages/pip/**" } | OutputData,
    dist_info = { glob = "usr/lib/python3.13/site-packages/pip-*.dist-info/**" } | OutputData,
    ensurepip = { glob = "usr/lib/python3.13/ensurepip/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,

  tests = {
    pip_version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "pip3 --version | grep -q 'pip'"],
        ],
      } | Test,
  },
} | BuildSpec

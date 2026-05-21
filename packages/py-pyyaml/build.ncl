let { Attrs, BuildSpec, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let python = import "../python/build.ncl" in

let version = "6.0.3" in
{
  name = "py-pyyaml",
  # PyYAML's sdist requires Cython >= 3.0 + setuptools to build, which
  # turns into a heavy bootstrap chain inside the hermetic sandbox.
  # Pre-built linux/x86_64 wheel sidesteps that — pip just unzips it
  # into /build/output. The wheel is cp314-locked, which is fine
  # because the builder image is pinned to Python 3.14.
  build_deps = [
    {
      url = "https://files.pythonhosted.org/packages/88/f9/16491d7ed2a919954993e48aa941b200f38040928474c9e85ea9e64222c3/pyyaml-6.0.3-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl",
      sha256 = "c458b6d084f9b935061bc36216e8a69a7e293a2f1e68bf956dcd9e6cbcd143f5",
      extract = false,
    } | Source,
    base,
  ],

  runtime_deps = [
    python,
  ],

  cmds = [
    "pip3 install --no-index --no-deps --no-user --root /build/output ./pyyaml-%{version}-cp314-cp314-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl",
  ],

  outputs = {
    python_site_package = { glob = "usr/lib/python*/site-packages/yaml/**" } | OutputData,
    python_so = { glob = "usr/lib/python*/site-packages/_yaml*.so" } | OutputData,
    python_dist_info = { glob = "usr/lib/python*/site-packages/PyYAML-*.dist-info/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "yaml",
        repo = "pyyaml",
      },
    } | Attrs,
} | BuildSpec

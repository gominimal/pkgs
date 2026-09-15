let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let gdbm = import "../gdbm/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let util-linux = import "../util-linux/build.ncl" in
let patch = import "../patch/build.ncl" in

let bash = import "../bash/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let expat = import "../expat/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let xz = import "../xz/build.ncl" in

let version = "3.14.7" in
{
  name = "python",
  build_deps = [
    { file = "build.sh" } | Local,
    # CVE-2026-19672 (PSF-2026-38, gh-155999): tarfile's `data`/`tar` filters
    # create intermediate directories from the member name as given, so a name
    # that leaves the destination and comes back creates them outside it even
    # though the resolved-path containment check passes. Upstream fixed it on
    # the 3.14 branch two weeks AFTER the 3.14.7 tag, so it is in no released
    # 3.14.x -- it first ships in 3.14.8. Drop this patch on that bump.
    { file = "0001-gh-155999-tarfile-normalize-parent-dir-components.patch" } | Local,
    {
      url = "gs://minimal-staging-archives/Python-%{version}.tar.xz",
      sha256 = "3b48dac8fb59f62eaa67ac83c1eb12bda1b7a08406dd286e252c11a66be27f81"
    } | Source,
    base,
    make,
    gdbm,
    ncurses,
    pkgconf,
    sqlite,
    patch,
    toolchain,
    util-linux,
  ],
  runtime_deps = [
    bash,
    libffi,
    expat,
    openssl,
    glibc,
    zlib,
    subsetOf util-linux ["libuuid"],
    xz,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    # Wildcards avoid coupling to a specific python minor version. Future
    # bumps (3.14 → 3.15 → ...) don't require touching this file — the
    # `python3.*` patterns match whichever minor is installed.
    python3 = { glob = "usr/bin/python3" } | OutputBin,
    python3_minor = { glob = "usr/bin/python3.*" } | OutputBin,
    pip3 = { glob = "usr/bin/pip3" } | OutputBin,
    pip3_minor = { glob = "usr/bin/pip3.*" } | OutputBin,
    pydoc3 = { glob = "usr/bin/pydoc3" } | OutputBin,
    pydoc3_minor = { glob = "usr/bin/pydoc3.*" } | OutputBin,
    python3-config = { glob = "usr/bin/python3-config" } | OutputBin,
    python3_minor-config = { glob = "usr/bin/python3.*-config" } | OutputBin,

    libs = { glob = "usr/lib/libpython*.so*" } | OutputLib,
    datas = { glob = "usr/lib/python*/**", allow_executable = true } | OutputData,

    includes = { glob = "usr/include/python*/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Python-2.0.1",
      source_provenance = {
        category = 'GithubRepo,
        owner = "python",
        repo = "cpython",
      },
    } | Attrs,

  tests = {
    smoketest_output =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'print(\"Hello Python\")' > script.py"],
          ["/bin/python3", "script.py"],
          ["/bin/bash", "-c", "python3 script.py > output.txt"],
          ["/bin/bash", "-c", "grep -q '^Hello Python$' output.txt"],
        ],
      } | Test,

    smoketest_math =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'print(2 + 2)' > math.py"],
          ["/bin/bash", "-c", "python3 math.py | grep -q '^4$'"],
          ["/bin/bash", "-c", "echo 'print(10 * 5)' > multiply.py"],
          ["/bin/bash", "-c", "python3 multiply.py | grep -q '^50$'"],
        ],
      } | Test,

    smoketest_imports =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "cat > mymodule.py << 'EOF'\ndef greet(name):\n    return f\"Hello, {name}\"\nEOF"],
          ["/bin/bash", "-c", "cat > use_module.py << 'EOF'\nimport mymodule\nprint(mymodule.greet(\"World\"))\nEOF"],
          ["/bin/bash", "-c", "python3 use_module.py | grep -q '^Hello, World$'"],
        ],
      } | Test,

    # CVE-2026-19672 regression. This test FAILS on stock 3.14.7 and passes
    # only with the gh-155999 patch applied, so it is the thing that would
    # catch the patch silently going missing on a future bump -- including the
    # 3.14.8 bump that is supposed to make it redundant, where dropping the
    # patch is correct but dropping it too early is not.
    #
    # The member name leaves the destination and comes back. The resolved path
    # lands inside, so the containment check passes and the FILE is extracted
    # correctly -- that part is true both before and after the fix. What the
    # fix changes is that the intermediate `escaped.evil` directory is no
    # longer created outside the destination on the way there.
    tarfile_filter_stays_in_destination =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              cat > poc.py <<'PYEOF'
              import io, os, sys, tarfile, tempfile

              work = tempfile.mkdtemp()
              dest = os.path.join(work, 'dest')
              os.makedirs(dest)
              outside = os.path.join(work, 'escaped.evil')

              buf = io.BytesIO()
              with tarfile.open(fileobj=buf, mode='w') as tf:
                  payload = b'content'
                  ti = tarfile.TarInfo('../escaped.evil/../dest/sub/file')
                  ti.size = len(payload)
                  tf.addfile(ti, io.BytesIO(payload))
              buf.seek(0)

              with tarfile.open(fileobj=buf, mode='r') as tf:
                  tf.extractall(dest, filter='data')

              failures = []
              if os.path.isdir(outside):
                  failures.append('directory created OUTSIDE destination: ' + outside)
              if not os.path.isfile(os.path.join(dest, 'sub', 'file')):
                  failures.append('expected file missing at dest/sub/file')

              for f in failures:
                  print('FAIL: ' + f)
              sys.exit(1 if failures else 0)
              PYEOF
              python3 poc.py
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec

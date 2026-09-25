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
    # CVE-2026-15806 (PSF-2026-36, gh-155694): urllib's HTTPPasswordMgr
    # dropped the URL scheme when matching, so credentials added for
    # https://host/ were handed out for http://host/ and sent in cleartext.
    # Fixed on the 3.14 branch after the 3.14.7 tag; first ships in 3.14.8.
    # Drop this patch on the 3.14.8 bump.
    { file = "0003-gh-155694-urllib-scope-credentials-by-scheme.patch" } | Local,
    # CVE-2026-15310 (PSF-2026-39, gh-156002): zipfile decompressed
    # bzip2/LZMA/Zstandard members without a per-read bound, so a tiny member
    # read in small chunks still expanded into one huge allocation. Carries
    # the fix AND its follow-up (monkey-patched decompressors), in that order.
    # Fixed on the 3.14 branch after the 3.14.7 tag; first ships in 3.14.8.
    # Drop this patch on the 3.14.8 bump.
    { file = "0004-gh-156002-zipfile-bound-decompression.patch" } | Local,
    # CVE-2026-17084 (PSF-2026-37, gh-155292): stringprep (IDNA2003 nameprep)
    # case-folded with the current Unicode instead of the 3.2.0 that RFC 3454
    # mandates, so labels with post-3.2 case pairs encoded to non-standard
    # A-labels. Fixed on the 3.14 branch after the 3.14.7 tag; first ships in
    # 3.14.8. Drop this patch on the 3.14.8 bump.
    { file = "0005-gh-155292-stringprep-pin-unicode-3.2.patch" } | Local,
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

    # CVE-2026-15806 regression: FAILS on stock 3.14.7 (the https
    # credentials come back for the http URL, and HTTPPasswordMgrWithPriorAuth
    # pre-emptively sends them), passes only with the gh-155694 patch.
    urllib_credentials_scoped_by_scheme =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              cat > poc.py <<'PYEOF'
              import sys, urllib.request

              failures = []
              mgr = urllib.request.HTTPPasswordMgr()
              mgr.add_password('realm', 'https://example.com/', 'user', 'secret')
              got = mgr.find_user_password('realm', 'https://example.com/')
              if got != ('user', 'secret'):
                  failures.append('https credentials not found for https URL: %r' % (got,))
              got = mgr.find_user_password('realm', 'http://example.com/')
              if got != (None, None):
                  failures.append('https credentials returned for http URL: %r' % (got,))

              prior = urllib.request.HTTPPasswordMgrWithPriorAuth()
              handler = urllib.request.HTTPBasicAuthHandler(prior)
              handler.add_password(None, 'https://example.com/', 'user', 'secret',
                                   is_authenticated=True)
              req = urllib.request.Request('http://example.com/')
              handler.http_request(req)
              if req.has_header('Authorization'):
                  failures.append('pre-emptive Authorization sent to http URL: %r'
                                  % req.get_header('Authorization'))

              for f in failures:
                  print('FAIL: ' + f, file=sys.stderr)
              sys.exit(1 if failures else 0)
              PYEOF
              python3 poc.py
            "%
          ],
        ],
      } | Test,

    # CVE-2026-15310 regression: FAILS on stock 3.14.7, where one read(8192)
    # of a 32 MiB all-zero LZMA (and bzip2, if built) member peaks at ~80+ MiB
    # because the whole first compressed chunk is expanded at once. With the
    # gh-156002 patch the peak is the decoder state plus one bounded chunk.
    zipfile_read_bounds_decompression =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              cat > poc.py <<'PYEOF'
              import io, sys, tracemalloc, zipfile

              methods = []
              for name, mod, const in (('lzma', 'lzma', zipfile.ZIP_LZMA),
                                       ('bzip2', 'bz2', zipfile.ZIP_BZIP2)):
                  try:
                      __import__(mod)
                  except ImportError:
                      print('skip: %s module not built' % mod, file=sys.stderr)
                      continue
                  methods.append((name, const))
              if not any(n == 'lzma' for n, _ in methods):
                  print('FAIL: lzma module missing; nothing exercises the fix', file=sys.stderr)
                  sys.exit(1)

              SIZE = 32 * 1024 * 1024
              # liblzma's decoder state (an 8 MiB dictionary at the default preset) is
              # allocated through PyMem and so counted by tracemalloc; 16 MiB leaves room
              # for it while an unbounded read of the 32 MiB member peaks far above.
              LIMIT = 16 * 1024 * 1024
              failures = []
              for name, const in methods:
                  buf = io.BytesIO()
                  # Explicit timestamp: the test sandbox clock can read 1970,
                  # which a zip header cannot encode (DOS dates start 1980).
                  zi = zipfile.ZipInfo('big', date_time=(1980, 1, 1, 0, 0, 0))
                  zi.compress_type = const
                  with zipfile.ZipFile(buf, 'w') as zf:
                      zf.writestr(zi, b'\0' * SIZE)
                  data = buf.getvalue()
                  with zipfile.ZipFile(io.BytesIO(data)) as zf:
                      with zf.open('big') as f:
                          tracemalloc.start()
                          chunk = f.read(8192)
                          _, peak = tracemalloc.get_traced_memory()
                          tracemalloc.stop()
                  print('%s: archive %d bytes, read(8192) peak %d bytes' % (name, len(data), peak),
                    file=sys.stderr)
                  if chunk != b'\0' * 8192:
                      failures.append('%s: wrong data from read(8192)' % name)
                  if peak > LIMIT:
                      failures.append('%s: read(8192) peaked at %d bytes (> %d)' % (name, peak, LIMIT))

              for f in failures:
                  print('FAIL: ' + f, file=sys.stderr)
              sys.exit(1 if failures else 0)
              PYEOF
              python3 poc.py
            "%
          ],
        ],
      } | Test,

    # CVE-2026-17084 regression: FAILS on stock 3.14.7, where these letters
    # (uncased in Unicode 3.2.0, cased by 16.0) are folded by stringprep and
    # so encode to non-standard A-labels. Expected A-labels are upstream's
    # from test_codecs.test_new_unicode_case_folding.
    idna_nameprep_uses_unicode_3_2_case_folding =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              cat > poc.py <<'PYEOF'
              import sys, stringprep
              from encodings import idna

              failures = []
              # Letters with no case mapping in Unicode 3.2.0 that gained one later.
              # RFC 3454 B.3 is fixed at Unicode 3.2.0, so they must map to themselves.
              for ch in ('\N{CHEROKEE LETTER A}', '\N{GEORGIAN CAPITAL LETTER AN}',
                         '\N{CYRILLIC LETTER PALOCHKA}', '\N{ROMAN NUMERAL REVERSED ONE HUNDRED}'):
                  got = stringprep.map_table_b3(ch)
                  if got != ch:
                      failures.append('map_table_b3(U+%04X) = %r, want identity' % (ord(ch), got))
              # A case mapping that DID exist in 3.2 must still apply.
              if stringprep.map_table_b3('A') != 'a':
                  failures.append('map_table_b3("A") no longer lowercases')

              cases = [
                  ('\N{CHEROKEE LETTER A}\N{CHEROKEE LETTER A}', b'xn--58da'),
                  ('\N{GEORGIAN CAPITAL LETTER AN}.', b'xn--7md.'),
                  ('\N{CYRILLIC LETTER PALOCHKA}.example', b'xn--d5a.example'),
                  ('\N{ROMAN NUMERAL REVERSED ONE HUNDRED}.example.', b'xn--q5g.example.'),
                  ('pyth\xf6n.org', b'xn--pythn-mua.org'),
              ]
              for u, want in cases:
                  got = u.encode('idna')
                  if got != want:
                      failures.append('%a.encode("idna") = %r, want %r' % (u, got, want))

              for f in failures:
                  print('FAIL: ' + f, file=sys.stderr)
              sys.exit(1 if failures else 0)
              PYEOF
              python3 poc.py
            "%
          ],
        ],
      } | Test,
  },
} | BuildSpec

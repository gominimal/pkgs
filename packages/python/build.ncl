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

let version = "3.14.10" in
{
  name = "python",
  build_deps = [
    { file = "build.sh" } | Local,
    # Dropped on the 3.14.9 bump, because 3.14.9 ships each fix (its own
    # Misc/NEWS Security section lists all three): gh-157265 (tarfile,
    # CVE-2026-87910), gh-157579 (tempfile, CVE-2026-12345) and gh-159894
    # (ensurepip bundles pip 26.2.2, the CVE-2026-111943 certifi fix we used to
    # swap in by hand). Earlier drops: gh-155999, gh-155694, gh-156002 and
    # gh-155292 on the 3.14.8 bump. Their regression tests below stay as guards.
    #
    # CVE-2025-15367 (gh-143923): poplib built each command from caller-supplied
    # text and sent it unchecked, so a CR/LF inside an argument injected extra
    # POP3 commands. Fixed on main (b234a2b6, 3.15.0a6) only: the 3.14 branch has
    # no commit touching poplib.py since 2025-03-02, and neither 3.14.9's nor
    # 3.14.10's Misc/NEWS has an entry for gh-143923 (3.14.10's `_putcmd` still
    # sends the line unchecked). A straight cherry-pick (applies at fuzz 0 to
    # 3.14.10); drop it on the first 3.14.x whose changelog lists gh-143923.
    { file = "0003-gh-143923-poplib-reject-control-characters.patch" } | Local,
    # OpenSSL 4: the Modules/ part of python/cpython#149783 (the unmerged 3.14 backport of
    # gh-146207 / gh-148600 / gh-148292). Without it _ssl references TLSv1_method() and the
    # other fixed-version methods 4.0 removed. No-op on OpenSSL 3. Drop it on the first
    # 3.14.x whose Misc/NEWS lists gh-148292, or on 3.15.
    { file = "0004-gh-148292-openssl-4-support.patch" } | Local,
    {
      url = "gs://minimal-staging-archives/Python-%{version}.tar.xz",
      sha256 = "de414a57119abef52784d8993e341d53aed635fc2b05c2607d9f98a2c5b72032"
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

    # base carries tzdata, so zoneinfo resolves IANA zone names without extra packages
    smoketest_zoneinfo =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/python3", "-c", "import zoneinfo; zoneinfo.ZoneInfo('Europe/Paris')"],
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

    # CVE-2026-19672 regression. FAILS on 3.14.7 and passes on 3.14.8, which
    # ships the gh-155999 fix (we carried it as a patch until the 3.14.8 bump).
    # Kept as the guard that the fix is really in the interpreter we ship.
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

    # CVE-2026-87910 regression. FAILS on stock 3.14.7 and 3.14.8 and passes on
    # 3.14.9, which ships the gh-157265 fix (we carried it as a patch until the
    # 3.14.9 bump). Kept as the guard that the fix is really in what we ship.
    #
    # `q` is a hard link to the symlink `a/b/s -> ../escape`. `a/b/s` itself
    # is fine (it resolves inside the destination), so linking fails over to
    # extracting a copy as `q`, where `../escape` DOES leave the destination.
    # The filter rejects that by returning None; unpatched tarfile ignores
    # the None and creates `q -> ../escape` anyway.
    tarfile_link_fallback_honors_filter_none =
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

              buf = io.BytesIO()
              with tarfile.open(fileobj=buf, mode='w') as tf:
                  s = tarfile.TarInfo('a/b/s')
                  s.type = tarfile.SYMTYPE
                  s.linkname = '../escape'
                  tf.addfile(s)
                  q = tarfile.TarInfo('q')
                  q.type = tarfile.LNKTYPE
                  q.linkname = 'a/b/s'
                  tf.addfile(q)
              buf.seek(0)

              def skip_unsafe(member, path):
                  try:
                      return tarfile.data_filter(member, path)
                  except tarfile.FilterError:
                      return None

              with tarfile.open(fileobj=buf, mode='r') as tf:
                  tf.extractall(dest, filter=skip_unsafe)

              failures = []
              if os.path.lexists(os.path.join(dest, 'q')):
                  failures.append('rejected link fallback extracted anyway as dest/q')
              if os.readlink(os.path.join(dest, 'a', 'b', 's')) != '../escape':
                  failures.append('expected dest/a/b/s -> ../escape')

              for f in failures:
                  print('FAIL: ' + f)
              sys.exit(1 if failures else 0)
              PYEOF
              python3 poc.py
            "%
          ],
        ],
      } | Test,

    # CVE-2026-111943 regression: FAILS on stock 3.14.8, whose ensurepip
    # installs pip 26.2.1 with a vendored certifi that still trusts emSign ECC
    # Root CA - G3; passes on 3.14.9, which bundles pip 26.2.2 (we swapped the
    # wheel in by hand until the 3.14.9 bump). Requires pip >= 26.2.2 rather than
    # an exact version, so a later 3.14.x bundling a newer pip still passes. Checks the root by its SHA-256 fingerprint, in both the pip
    # the interpreter ships in site-packages and the wheel ensurepip would
    # install from. No network.
    pip_certifi_distrusts_emsign_ecc_g3 =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              cat > poc.py <<'PYEOF'
              import hashlib, re, ssl, sys, zipfile
              import ensurepip, pip
              from pip._vendor import certifi

              G3 = '86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b'

              def fingerprints(pem):
                  return {hashlib.sha256(ssl.PEM_cert_to_DER_cert(c)).hexdigest()
                          for c in re.findall(r'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----',
                                              pem, re.S)}

              def ver(v):
                  return tuple(int(x) for x in re.match(r'\d+(?:\.\d+)*', v).group().split('.'))

              failures = []
              if ver(pip.__version__) < (26, 2, 2):
                  failures.append('site-packages pip is %s, want >= 26.2.2' % pip.__version__)
              if ver(ensurepip.version()) < (26, 2, 2):
                  failures.append('ensurepip bundles pip %s, want >= 26.2.2' % ensurepip.version())

              installed = fingerprints(open(certifi.where()).read())
              if len(installed) < 100:
                  failures.append('pip certifi bundle has only %d roots' % len(installed))
              if G3 in installed:
                  failures.append('site-packages pip certifi trusts emSign ECC Root CA - G3')

              with ensurepip._get_pip_whl_path_ctx() as whl:
                  with zipfile.ZipFile(whl) as z:
                      bundled = fingerprints(z.read('pip/_vendor/certifi/cacert.pem').decode())
              if G3 in bundled:
                  failures.append('ensurepip wheel certifi trusts emSign ECC Root CA - G3')

              for f in failures:
                  print('FAIL: ' + f, file=sys.stderr)
              sys.exit(1 if failures else 0)
              PYEOF
              python3 poc.py
            "%
          ],
        ],
      } | Test,

    # CVE-2025-15367 regression: FAILS on stock 3.14.10 (poplib sends a command
    # containing CR/LF verbatim, so a username can smuggle in extra POP3
    # commands) and passes only with the gh-143923 patch. Exercises `_putcmd`
    # directly -- no network.
    poplib_rejects_control_characters =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              cat > poc.py <<'PYEOF'
              import poplib, sys

              class Fake(poplib.POP3):
                  def __init__(self):
                      self.encoding = 'UTF-8'
                      self._debugging = 0
                      self.sent = []
                  def _putline(self, line):
                      self.sent.append(line)

              failures = []
              f = Fake()
              f._putcmd('USER alice')
              if f.sent != [b'USER alice']:
                  failures.append('a normal command was not sent: %r' % (f.sent,))
              for bad in ('USER a\r\nDELE 1', 'USER a\nQUIT', 'NOOP\x00', 'USER a\x7f'):
                  try:
                      f._putcmd(bad)
                  except ValueError:
                      continue
                  failures.append('control characters were sent: %r' % (bad,))

              for m in failures:
                  print('FAIL: ' + m, file=sys.stderr)
              sys.exit(1 if failures else 0)
              PYEOF
              python3 poc.py
            "%
          ],
        ],
      } | Test,

    # CVE-2026-12345 regression (gh-157579). The race itself is not
    # reproducible deterministically, so this guards the fix's presence and its
    # normal behaviour: on Linux the fixed cleanup works relative to open
    # directory fds (`tempfile._rmtree_use_dir_fd`) and rmtree passes the fd to
    # its error hook (`_onexc_kwargs`). FAILS on stock 3.14.8 (neither exists);
    # passes on 3.14.9, which ships the fix (carried as a patch until then).
    # Then a tree with a read-only subdirectory, which forces the
    # permission-reset path the fix rewrote, must still clean up completely.
    tempfile_cleanup_race_fix =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              cat > poc.py <<'PYEOF'
              import inspect, os, shutil, stat, sys, tempfile

              failures = []
              if getattr(tempfile, '_rmtree_use_dir_fd', None) is not True:
                  failures.append('tempfile does not clean up via directory fds')
              if '_onexc_kwargs' not in inspect.signature(shutil.rmtree).parameters:
                  failures.append('shutil.rmtree lacks the gh-157579 onexc kwargs')

              d = tempfile.TemporaryDirectory()
              root = d.name
              sub = os.path.join(root, 'ro')
              os.mkdir(sub)
              with open(os.path.join(sub, 'f'), 'w') as fh:
                  fh.write('x')
              os.chmod(sub, stat.S_IRUSR | stat.S_IXUSR)
              d.cleanup()
              if os.path.exists(root):
                  failures.append('cleanup left %s behind' % root)

              for m in failures:
                  print('FAIL: ' + m, file=sys.stderr)
              sys.exit(1 if failures else 0)
              PYEOF
              python3 poc.py
            "%
          ],
        ],
      } | Test,

    # CVE-2026-15806 regression: FAILS on 3.14.7 (the https credentials come
    # back for the http URL, and HTTPPasswordMgrWithPriorAuth pre-emptively
    # sends them) and passes on 3.14.8, which ships the gh-155694 fix.
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
    # because the whole first compressed chunk is expanded at once. 3.14.8
    # ships the gh-156002 fix: the peak is the decoder state plus one bounded
    # chunk.
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

# Imported from Wolfi `gnupg` by `pkgmgr import wolfi` (autotools build).
# TODO: REVIEWER — verify deps/outputs/runtime_deps + the build.sh opts.
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gnutls = import "../gnutls/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let libusb = import "../libusb/build.ncl" in
let npth = import "../npth/build.ncl" in
let libksba = import "../libksba/build.ncl" in
let libassuan = import "../libassuan/build.ncl" in
let libgcrypt = import "../libgcrypt/build.ncl" in
let libgpg-error = import "../libgpg-error/build.ncl" in
let patch = import "../patch/build.ncl" in
# SOURCE: upstream's official release tarball (gnupg.org), mirrored to gs://,
# NOT the GitHub auto-generated archive. Still a full source build — we compile
# every line of C — but the release tarball is `make dist` output, so it also
# carries what upstream generated at release time: the bootstrapped `configure`,
# the pre-built .info, and the four doc diagrams.
#
# That last part is why this matters. doc/Makefile.am renders
# gnupg-module-overview.{png,pdf} and gnupg-card-architecture.{png,pdf} from SVG
# with ImageMagick's `convert`, which we do not package. They are BUILT_SOURCES,
# so make dies Error 127 before anything else, and gnupg's only doc control is
# AM_CONDITIONAL(BUILD_DOC) — all-or-nothing, so --disable-doc would also throw
# away the man pages. The release tarball ships all four already rendered, so
# the rule never fires and we keep the complete docs.
#
# It is also better provenance: gnupg.org publishes a detached PGP signature
# (gnupg-2.4.9.tar.bz2.sig) alongside it, while GitHub's archive/refs/tags
# tarballs are generated on demand, unsigned, and have changed compression in
# the past — silently changing the sha256 for an unchanged tag.
let version = "2.4.9" in
{
  name = "gnupg",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "libassun-version.patch" } | Local,
    { file = "0010-avoid-beta-warning.patch" } | Local,
    { file = "0210-dirmngr-hkp-avoid-potential-race-condition-when-some-host-die.patch" } | Local,
    { file = "fix-i18n.patch" } | Local,
    { file = "make-aes-default-for-fips.patch" } | Local,
    base,
    autoconf,
    automake,
    libtool,
    m4,
    make,
    pkgconf,
    toolchain,
    glibc,
    # gnupg's five-library stack, all packaged alongside it in this bundle.
    libgpg-error,
    libgcrypt,
    libassuan,
    libksba,
    npth,
    # libusb is REQUIRED, not optional: configure aborts with "You need libusb
    # to build the internal ccid driver" (the smartcard reader path).
    # gnutls is what makes dirmngr exist. Without it configure prints
    # "*** Neither NTBTLS nor GNUTLS available - not building dirmngr" and
    # continues happily — so you get a gnupg with no keyserver access, no CRL
    # and no OCSP, and the only symptom is `dirmngr: command not found` much
    # later. We ship gnutls; there is no reason to lose dirmngr.
    gnutls,
    libusb,
    # sqlite is optional but load-bearing — without it configure quietly
    # continues and prints "Building without SQLite support - TOFU and Keyboxd
    # disabled", i.e. you get a gnupg missing trust-on-first-use and the
    # keybox daemon, with no build failure to tell you.
    sqlite,
    patch,
    {
      url = "gs://minimal-staging-archives/gnupg-%{version}.tar.bz2",
      sha256 = "dd17ab2e9a04fd79d39d853f599cbc852062ddb9ab52a4ddeb4176fd8b302964",
      extract = true,
      strip_prefix = "gnupg-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    # Discovery catch-all — rerun with `--from-build <artifact>` to refine
    # into precise, typed outputs (bins/libs/includes/…).
    everything = { glob = "usr/**", allow_executable = true } | OutputData,
  },
  # TODO: REVIEWER — trim to the shared libraries the binary actually links (ldd the build).
  runtime_deps = [
    glibc,
    # gnupg dlinks all of these; declaring only glibc meant gpg died at
    # startup with "libsqlite3.so: cannot open shared object file".
    libgpg-error,
    libgcrypt,
    libassuan,
    libksba,
    npth,
    libusb,
    sqlite,
    gnutls,
  ],
  attrs =
    {
      upstream_version = version,
      # Kept as GithubRepo after checking the corpus rather than taking the
      # review comment at face value. GnuProject renders `pkg:generic/gnu/gnupg`,
      # which matches ZERO advisories here; `pkg:github/gpg/gnupg` matches 1.
      # Switching would have been strictly worse.
      #
      # ⚠ Neither is where the advisories actually live: 305 gnupg advisories are
      # keyed by the NVD CPE `gnupg:gnupg`, and no provenance category reaches a
      # CPE. That needs a curated entry in package_cpe_identity.toml — the same
      # gap that made openssl read 0/0/0 while carrying 1 Critical / 5 High
      # (pkgmgr-rs#441, and the NVD-only false-negative class).
      source_provenance = { category = 'GithubRepo, owner = "gpg", repo = "gnupg" },
      license_spdx = "GPL-3.0-or-later",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # TODO: REVIEWER — ported from the Wolfi test block; verify each
          # against minimal's toolchain (bins on PATH, flags supported).
          ["/bin/bash", "-c", "gpg --version"],
          ["/bin/bash", "-c", "gpg --help"],
          ["/bin/bash", "-c", "export GNUPGHOME=$(mktemp -d)\n\n# Generate a test keypair in batch mode (no passphrase, no pinentry needed)\ngpg --batch --pinentry-mode loopback --passphrase \"\" \\\n  --quick-gen-key \"Test User <test@example.com>\" rsa2048 sign 0\n\n# Verify the key was created and is listed\ngpg --list-keys | grep -F \"Test User\"\ngpg --list-keys | grep -F \"test@example.com\""],
          ["/bin/bash", "-c", "export GNUPGHOME=$(mktemp -d)\n\n# Generate a key for encryption/decryption test\ngpg --batch --pinentry-mode loopback --passphrase \"\" \\\n  --quick-gen-key \"Enc User <enc@example.com>\" rsa2048 encr 0\n\n# Encrypt a message to the key\necho \"gnupg encryption test payload\" | \\\n  gpg --batch --yes --trust-model always \\\n  --encrypt --recipient \"enc@example.com\" \\\n  --output /tmp/test-encrypted.gpg\n\n# Decrypt and verify the original plaintext is recovered\ngpg --batch --pinentry-mode loopback --passphrase \"\" \\\n  --decrypt /tmp/test-encrypted.gpg | grep -F \"gnupg encryption test payload\""],
          ["/bin/bash", "-c", "export GNUPGHOME=$(mktemp -d)\n\n# Generate a key for signing test\ngpg --batch --pinentry-mode loopback --passphrase \"\" \\\n  --quick-gen-key \"Sign User <sign@example.com>\" rsa2048 sign 0\n\n# Create a test file and sign it\necho \"gnupg signature test payload\" > /tmp/test-sign.txt\ngpg --batch --pinentry-mode loopback --passphrase \"\" \\\n  --detach-sign --output /tmp/test-sign.txt.sig /tmp/test-sign.txt\n\n# Verify the signature\ngpg --verify /tmp/test-sign.txt.sig /tmp/test-sign.txt"],
          ["/bin/bash", "-c", "dirmngr --version"],
          ["/bin/bash", "-c", "dirmngr-client --version"],
          ["/bin/bash", "-c", "gpgconf --version"],
          ["/bin/bash", "-c", "gpg-connect-agent --help"],
          ["/bin/bash", "-c", "gpg --version"],
          ["/bin/bash", "-c", "gpg --help"],
          ["/bin/bash", "-c", "gpg --list-keys"],
          ["/bin/bash", "-c", "gpg-agent --version"],
          ["/bin/bash", "-c", "gpg-agent --help"],
          ["/bin/bash", "-c", "gpg-wks-server --version"],
          ["/bin/bash", "-c", "gpg-wks-server --help"],
          ["/bin/bash", "-c", "gpgsm --version"],
          ["/bin/bash", "-c", "gpgsm --help"],
          ["/bin/bash", "-c", "gpgv --version"],
          ["/bin/bash", "-c", "gpgv --help"],
          ["/bin/bash", "-c", "gpgsplit --version"],
          ["/bin/bash", "-c", "gpgparsemail --help"],
        ],
      } | Test,
  },
} | BuildSpec

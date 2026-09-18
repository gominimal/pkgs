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
let patch = import "../patch/build.ncl" in
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
    patch,
    {
      url = "https://github.com/gpg/gnupg/archive/refs/tags/gnupg-%{version}.tar.gz",
      sha256 = "49366c29a7fe2b3fb861a2fdb9011e9e8dd3c0cddf35609bf0d06a83b6b9cdc0",
      extract = true,
      strip_prefix = "gnupg-gnupg-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    # Discovery catch-all — rerun with `--from-build <artifact>` to refine
    # into precise, typed outputs (bins/libs/includes/…).
    everything = { glob = "usr/**", allow_executable = true } | OutputData,
  },
  # TODO: REVIEWER — trim to the shared libraries the binary actually links (ldd the build).
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
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
          ["/bin/bash", "-c", "gpg --version 2>/dev/null || gpg version"],
          ["/bin/bash", "-c", "gpg --help 2>/dev/null || gpg help"],
          ["/bin/bash", "-c", "export GNUPGHOME=$(mktemp -d)\n\n# Generate a test keypair in batch mode (no passphrase, no pinentry needed)\ngpg --batch --pinentry-mode loopback --passphrase \"\" \\\n  --quick-gen-key \"Test User <test@example.com>\" rsa2048 sign 0\n\n# Verify the key was created and is listed\ngpg --list-keys | grep -F \"Test User\"\ngpg --list-keys | grep -F \"test@example.com\""],
          ["/bin/bash", "-c", "export GNUPGHOME=$(mktemp -d)\n\n# Generate a key for encryption/decryption test\ngpg --batch --pinentry-mode loopback --passphrase \"\" \\\n  --quick-gen-key \"Enc User <enc@example.com>\" rsa2048 encr 0\n\n# Encrypt a message to the key\necho \"gnupg encryption test payload\" | \\\n  gpg --batch --yes --trust-model always \\\n  --encrypt --recipient \"enc@example.com\" \\\n  --output /tmp/test-encrypted.gpg\n\n# Decrypt and verify the original plaintext is recovered\ngpg --batch --pinentry-mode loopback --passphrase \"\" \\\n  --decrypt /tmp/test-encrypted.gpg | grep -F \"gnupg encryption test payload\""],
          ["/bin/bash", "-c", "export GNUPGHOME=$(mktemp -d)\n\n# Generate a key for signing test\ngpg --batch --pinentry-mode loopback --passphrase \"\" \\\n  --quick-gen-key \"Sign User <sign@example.com>\" rsa2048 sign 0\n\n# Create a test file and sign it\necho \"gnupg signature test payload\" > /tmp/test-sign.txt\ngpg --batch --pinentry-mode loopback --passphrase \"\" \\\n  --detach-sign --output /tmp/test-sign.txt.sig /tmp/test-sign.txt\n\n# Verify the signature\ngpg --verify /tmp/test-sign.txt.sig /tmp/test-sign.txt"],
          ["/bin/bash", "-c", "dirmngr dirmngr-client --version 2>/dev/null || dirmngr dirmngr-client version"],
          ["/bin/bash", "-c", "dirmngr dirmngr-client --help 2>/dev/null || dirmngr dirmngr-client help"],
          ["/bin/bash", "-c", "gpg-connect-agent gpgconf --version 2>/dev/null || gpg-connect-agent gpgconf version"],
          ["/bin/bash", "-c", "gpg-connect-agent gpgconf --help 2>/dev/null || gpg-connect-agent gpgconf help"],
          ["/bin/bash", "-c", "gpg gpg2 --version 2>/dev/null || gpg gpg2 version"],
          ["/bin/bash", "-c", "gpg gpg2 --help 2>/dev/null || gpg gpg2 help"],
          ["/bin/bash", "-c", "gpg --list-keys"],
          ["/bin/bash", "-c", "gpg-agent --version 2>/dev/null || gpg-agent version"],
          ["/bin/bash", "-c", "gpg-agent --help 2>/dev/null || gpg-agent help"],
          ["/bin/bash", "-c", "gpg-wks-server --version 2>/dev/null || gpg-wks-server version"],
          ["/bin/bash", "-c", "gpg-wks-server --help 2>/dev/null || gpg-wks-server help"],
          ["/bin/bash", "-c", "gpgsm --version 2>/dev/null || gpgsm version"],
          ["/bin/bash", "-c", "gpgsm --help 2>/dev/null || gpgsm help"],
          ["/bin/bash", "-c", "gpgv gpgv2 --version 2>/dev/null || gpgv gpgv2 version"],
          ["/bin/bash", "-c", "gpgv gpgv2 --help 2>/dev/null || gpgv gpgv2 help"],
          ["/bin/bash", "-c", "gpgsplit gpgtar kbxutil watchgnupg --version 2>/dev/null || gpgsplit gpgtar kbxutil watchgnupg version"],
          ["/bin/bash", "-c", "gpgparsemail gpgsplit gpgtar kbxutil watchgnupg --help 2>/dev/null || gpgparsemail gpgsplit gpgtar kbxutil watchgnupg help"],
        ],
      } | Test,
  },
} | BuildSpec

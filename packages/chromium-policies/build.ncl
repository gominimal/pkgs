let { Attrs, BuildSpec, Local, OutputData, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let jq = import "../jq/build.ncl" in
let openssl = import "../openssl/build.ncl" in

# Machine-wide Chromium enterprise policy, shared by every Chromium-branded
# browser package (today chromium-bin; its replacement build should keep this
# runtime dep). Installed as /etc/chromium/policies/managed/<name>.json, the
# directory Chromium-branded builds read (`policy::kPolicyPath` in
# components/policy/core/common/policy_paths.cc). Verified by grepping the
# shipped binaries for the path string: the chromium-browser-snapshots x64
# build, Playwright's arm64 build and ungoogled-chromium 155 all contain
# "/etc/chromium/policies".
#
# NOT read by chromium-headless-shell-bin. chrome-headless-shell has no
# platform policy loader since Chromium removed headless/lib/browser/policy/
# (present at 145, gone by 150), and even before that it handled only a few
# headless policies. The 155.0.8059.84 binary contains no policy directory
# path and no "CADistrustedCertificates" string. See that package's build.ncl.
#
# ca-distrusted-certificates.json — CVE-2026-111943 (eMudhra intermediate key
# compromise, https://bugzilla.mozilla.org/show_bug.cgi?id=2083449).
# `CADistrustedCertificates` (Chrome 132+, Linux included;
# https://chromeenterprise.google/policies/ca-distrusted-certificates/) is a
# list of base64 DER certificates; Chromium extracts each one's SPKI and
# distrusts every certificate with that key for TLS server auth. So one
# certificate per key covers the emSign-issued copy, the Sectigo AAA
# cross-sign and the ECDSA-malleated twins. The file lists:
#   * the 8 compromised intermediate keys, as their emSign-issued certificates
#     (the same 8 certificates Chromium added to its built-in blocklist in
#     chromium/src da63b94c, main@{#1723080}, 2026-10-20);
#   * the emSign ECC Root CA - G3 root, which Mozilla removed (NSS 3.131.1,
#     bug 2084101) and Chrome Root Store v43 removed (chromium/src 8793082f,
#     main@{#1723181}, 2026-10-20). It is the only Chrome-trusted root the
#     emSign-issued chains reach; Sectigo's AAA root is already out of the
#     Chrome Root Store. Collateral: every other site under that root stops
#     validating too, which is what Mozilla and Chrome chose.
# Our pinned 153/155 builds predate both upstream changes (their compiled-in
# root store still holds the root and their blocklist lacks the keys), and
# they get no CRLSet or root-store component updates, so this file is their
# only protection until a release carries the upstream fix.
#
# One file per policy key. Chromium merges every *.json in the directory, but
# a key set in two files is not merged (the lexicographically last file wins),
# so future distrust entries go INTO this file, never into a second one.
# Keep the key set in step with packages/ca-certificates/distrust.txt (`spki`
# lines); .github/scripts/chromium_policy_distrust_check.py checks that in CI.
{
  name = "chromium-policies",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "ca-distrusted-certificates.json" } | Local,
    base,
    jq,
    openssl,
  ],
  cmd = "./build.sh",

  outputs = {
    policies = { glob = "etc/chromium/policies/managed/*.json" } | OutputData,
  },

  attrs =
    {
      license_spdx = "Apache-2.0",
    } | Attrs,

  tests = {
    # The installed file is the policy build.sh checked: one key per entry,
    # exactly the 9 SPKI hashes build.sh's EXPECTED_SPKIS lists.
    policy_installed =
      {
        class = 'Standalone,
        test_deps = [base, jq, openssl],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              f=/etc/chromium/policies/managed/ca-distrusted-certificates.json
              jq -e 'keys == ["CADistrustedCertificates"]' "$f" >/dev/null
              got=$(jq -r '.CADistrustedCertificates[]' "$f" | while read -r b; do
                printf '%s' "$b" | base64 -d | openssl x509 -inform DER -noout -pubkey \
                  | openssl pkey -pubin -outform DER | sha256sum | cut -d' ' -f1
              done | sort)
              want=$(printf '%s\n' \
                43bffa19d6ef651451f6841e019931e96f6f2eaeff28ab4b6f1ce4576de2717b \
                49dd353dc2b919a3770645117d0e60c16115e7d1bc259eefe734b00ea434fe5f \
                5c0660a2b164910d8ff589c18e14552e9e0ec237dcefe2cb736d41a4811f81a0 \
                63ecefee431d49523bc1136c4e72d0206a477086caf606cd5cf025686c109cf8 \
                8d417db2dd8bf5e3084d1e3f196d583849d81bdd4c00c70b9d39369e96b8c782 \
                92c063d67e8f14db71d288e11266ffdaf69cbf115f7bab14f3bc2f68d25e0e30 \
                e0254c7fcdc265e2f0f8a428dabb75ab4ae039b4872d62f5ee57f0877d5a8a41 \
                ebed6475c2c2d80fcb199f3fe8dd6e6b3ce60b77eb15d4e42c3dec0c6f5b5105 \
                ec4ffa1ad0ac88081314b7aaffef6a91f97cd57291bb5ba686c5415f5eb4f6b6)
              [ "$got" = "$want" ]
            "%,
          ],
        ],
      } | Test,
  },
} | BuildSpec

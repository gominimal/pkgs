# The nine sha256-pinned sources of Mathlib v4.35.0: Mathlib itself and the
# Lake packages its lake-manifest.json pins. ONE definition, imported by both
# mathlib-oleans (which compiles them) and mathlib (which installs their
# licences and checks the ProofWidgets widget bundles its notices cover), so
# the two cannot drift.
#
# The dependency pins are Mathlib v4.35.0's own lake-manifest.json. The
# tarballs sit under aeneas-latest/ in staging only because that package
# mirrored the same pins first (Aeneas requires this Mathlib tag).
let { Source, .. } = import "minimal.ncl" in
[
  {
    url = "gs://minimal-staging-archives/aeneas-latest/mathlib-56a0058.tar.gz",
    sha256 = "45567f6e07607b787026d287c8ec1828f6cabc8debe11a45a521750580e3a0d5",
    extract = true,
  } | Source,
  # leanprover-community/plausible @ dfa4f38190d07c37e315953e08b90fe2d95b3c24 (Mathlib lake-manifest.json)
  {
    url = "gs://minimal-staging-archives/aeneas-latest/plausible-dfa4f38.tar.gz",
    sha256 = "3f157cbc2450a6d14f32f18c7a1efd12ee8209a335b3c8ea05248eece9beb342",
    extract = true,
  } | Source,
  # leanprover-community/LeanSearchClient @ d6b4c7be5be75ec4917c873ac50c756dc1436372
  {
    url = "gs://minimal-staging-archives/aeneas-latest/LeanSearchClient-d6b4c7b.tar.gz",
    sha256 = "bdd04cafc4385c3a236568127692ec197a06b97de413436623cba3e7811e010c",
    extract = true,
  } | Source,
  # leanprover-community/import-graph @ a41f0e9a4dea23188ea9cc1c41ac9f8bbafe0b93
  {
    url = "gs://minimal-staging-archives/aeneas-latest/importGraph-a41f0e9.tar.gz",
    sha256 = "578c04f8b0df045c0e4091cf3633336c4785927269ef77bb47a6080e5d3b2ca5",
    extract = true,
  } | Source,
  # leanprover-community/ProofWidgets4 @ df72b022e558978a1c50264cfc4d7fec86fa8e04
  {
    url = "gs://minimal-staging-archives/aeneas-latest/proofwidgets-df72b02.tar.gz",
    sha256 = "1eaae7c4f21d9f0d7595ff7dd8b527b8ac6c59c932c162f5bdd9116f40407dec",
    extract = true,
  } | Source,
  # leanprover-community/aesop @ 4a174c490d8707121c4a9290800489f105d85e07
  {
    url = "gs://minimal-staging-archives/aeneas-latest/aesop-4a174c4.tar.gz",
    sha256 = "51146a125539b3eab0390c94bf90440cbfd4a4af1ab3fc3a1cc65fa49d248d98",
    extract = true,
  } | Source,
  # leanprover-community/quote4 @ dce0ad79c486cb1fb504af04f953c3466b0c6db8
  {
    url = "gs://minimal-staging-archives/aeneas-latest/Qq-dce0ad7.tar.gz",
    sha256 = "ea7f24d48b20dc748c419a57926280de9611769f21d9db1dbb0ef7a5e536335f",
    extract = true,
  } | Source,
  # leanprover-community/batteries @ 66e469188fe07963e5cf666c7d4433f45b8131c5
  {
    url = "gs://minimal-staging-archives/aeneas-latest/batteries-66e4691.tar.gz",
    sha256 = "e186aeb771cc7abaa64a738f0cee2743e89ca34e09e7efcb48520af847e2e92d",
    extract = true,
  } | Source,
  # leanprover/lean4-cli @ c24fe6078c630e89b489bffe59b3e20ac30d12c8
  {
    url = "gs://minimal-staging-archives/aeneas-latest/Cli-c24fe60.tar.gz",
    sha256 = "d9647a8d34708a3ecc8eb075c5c2910be9310017ecfb46c77510b2480f55285e",
    extract = true,
  } | Source,
]

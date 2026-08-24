let { subsetOf, Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# The tree-sitter grammars for helix, as the `<runtime>/grammars/<id>.so` files it
# dlopens at runtime. Helix ships every language's *queries* in its own runtime/
# tree but no compiled grammars: its normal `hx --grammar fetch && hx --grammar
# build` step git-clones ~250 repos. We set
# HELIX_DISABLE_AUTO_GRAMMAR_BUILD=1 in the helix package. This package supplies
# the grammars out-of-band and helix picks them up via runtime_deps, the same
# split neovim uses with its tree-sitter-* parser packages.
#
# Every revision below is the exact `rev` helix 25.07.1's languages.toml pins, so
# `version` here tracks the HELIX release, not any grammar's own version. Do not
# bump grammars independently: helix's bundled queries are written against these
# revisions, and the pins are what keep the parsers inside the tree-sitter ABI
# range helix links (all of these are ABI 13/14). Regenerate the set together
# with a helix bump.
#
# Which grammars: every language with a stack under stacks/
# and the data/config, git-workflow and low-level formats that show
# up in any repo. Two of helix's pins are deliberately absent — tree-sitter-groovy
# has no license grant at all (its Cargo.toml is unedited `YOUR-LANGUAGE-NAME`
# template boilerplate) and tree-sitter-gas is GPL-3.0. If necessary, tree-sitter-gas
# can get its own package in the future if needed. It needs to be separate so
# organizations that ban GPL-3.0 don't block _all_ helix tree sitter grammars.
let version = "25.07.1" in
{
  name = "helix-grammars",

  build_deps = [
    { file = "build.sh" } | Local,
    # bash
    {
      url = "https://github.com/tree-sitter/tree-sitter-bash/archive/487734f87fd87118028a65a4599352fa99c9cde8.tar.gz",
      sha256 = "5314ba34b3c16e5366a91e21ba099f1ef276bf5dd0d7849aa84a68afb74368e6",
      extract = true,
    } | Source,
    # c
    {
      url = "https://github.com/tree-sitter/tree-sitter-c/archive/7175a6dd5fc1cee660dce6fe23f6043d75af424a.tar.gz",
      sha256 = "617ab936681b75d45fb5dc26a58888552167f174d996b7e274fb4af090b62e5b",
      extract = true,
    } | Source,
    # cmake
    {
      url = "https://github.com/uyha/tree-sitter-cmake/archive/6e51463ef3052dd3b328322c22172eda093727ad.tar.gz",
      sha256 = "e89523736d1a9f63bf63660ef6635780d596a503282f8a8f8f3e0056bdce3b3c",
      extract = true,
    } | Source,
    # cpp
    {
      url = "https://github.com/tree-sitter/tree-sitter-cpp/archive/56455f4245baf4ea4e0881c5169de69d7edd5ae7.tar.gz",
      sha256 = "dc9f0a85716331bbf2aedfe8f4ede41ff77b7ba0ab726f782f3b3f28729d46b4",
      extract = true,
    } | Source,
    # css
    {
      url = "https://github.com/tree-sitter/tree-sitter-css/archive/769203d0f9abe1a9a691ac2b9fe4bb4397a73c51.tar.gz",
      sha256 = "ca9610e9a2afecc94731d57e82fa94ebf1bcbd260d9271deec9b27190d68d777",
      extract = true,
    } | Source,
    # diff
    {
      url = "https://github.com/the-mikedavis/tree-sitter-diff/archive/fd74c78fa88a20085dbc7bbeaba066f4d1692b63.tar.gz",
      sha256 = "f52c708d5530e63ca45a2f32ca71b26ef28c0177e44faed2e1436a7209f8dc1c",
      extract = true,
    } | Source,
    # dockerfile
    {
      url = "https://github.com/camdencheek/tree-sitter-dockerfile/archive/087daa20438a6cc01fa5e6fe6906d77c869d19fe.tar.gz",
      sha256 = "8a2d95d4230226c5480ebb21490a57bacd7c6597884a70bcead314247dac0fe3",
      extract = true,
    } | Source,
    # git-config
    {
      url = "https://github.com/the-mikedavis/tree-sitter-git-config/archive/9c2a1b7894e6d9eedfe99805b829b4ecd871375e.tar.gz",
      sha256 = "53f56ab3ca508696fb233b1cc8a9fa61ffe211b2976cba67dff6722de4b0f426",
      extract = true,
    } | Source,
    # git-rebase
    {
      url = "https://github.com/the-mikedavis/tree-sitter-git-rebase/archive/d8a4207ebbc47bd78bacdf48f883db58283f9fd8.tar.gz",
      sha256 = "8a6c3c7086f81da8657eeaa6bd0835cc10a95810c4f4897687283020a8af3928",
      extract = true,
    } | Source,
    # gitattributes
    {
      url = "https://github.com/mtoohey31/tree-sitter-gitattributes/archive/3dd50808e3096f93dccd5e9dc7dc3dba2eb12dc4.tar.gz",
      sha256 = "b921b734d779931fdcb57c5201bf5ef11323b7d056c1588c06a8131e05b80d86",
      extract = true,
    } | Source,
    # gitcommit
    {
      url = "https://github.com/gbprod/tree-sitter-gitcommit/archive/a716678c0f00645fed1e6f1d0eb221481dbd6f6d.tar.gz",
      sha256 = "a6d85de404e2167ad2c18ece0a02b94926a3e4f208d72fac6eadd52f9ef63998",
      extract = true,
    } | Source,
    # gitignore
    {
      url = "https://github.com/shunsambongi/tree-sitter-gitignore/archive/f4685bf11ac466dd278449bcfe5fd014e94aa504.tar.gz",
      sha256 = "15727772801cf49bd85b147dc7f77f6c3ddabbdb3b3d55c6580e7dd8f7aa559c",
      extract = true,
    } | Source,
    # go
    {
      url = "https://github.com/tree-sitter/tree-sitter-go/archive/64457ea6b73ef5422ed1687178d4545c3e91334a.tar.gz",
      sha256 = "039d827c7af2659a3f2d76511602c50c2528e5648f11a13da98c0ba253986093",
      extract = true,
    } | Source,
    # gomod
    {
      url = "https://github.com/camdencheek/tree-sitter-go-mod/archive/6efb59652d30e0e9cd5f3b3a669afd6f1a926d3c.tar.gz",
      sha256 = "c8666d35983fb746408252b44f5727e682a603b2c8540b244b282fd0f9f21f40",
      extract = true,
    } | Source,
    # gowork
    {
      url = "https://github.com/omertuc/tree-sitter-go-work/archive/6dd9dd79fb51e9f2abc829d5e97b15015b6a8ae2.tar.gz",
      sha256 = "341627f8204402d3a45382700ab2d720396817f29b799e0a3cacf3dbc7933606",
      extract = true,
    } | Source,
    # haskell
    {
      url = "https://github.com/tree-sitter/tree-sitter-haskell/archive/0975ef72fc3c47b530309ca93937d7d143523628.tar.gz",
      sha256 = "47dc3c3f6f477a1d09b534f9df87bef86a5adf5e5737dda1950c3603ca514e92",
      extract = true,
    } | Source,
    # hcl
    {
      url = "https://github.com/tree-sitter-grammars/tree-sitter-hcl/archive/9e3ec9848f28d26845ba300fd73c740459b83e9b.tar.gz",
      sha256 = "38ae4ac3fb4dcdefcb67cfa8bf06ad5e280c34dae6bd3b22797085148bca8248",
      extract = true,
    } | Source,
    # html
    {
      url = "https://github.com/tree-sitter/tree-sitter-html/archive/cbb91a0ff3621245e890d1c50cc811bffb77a26b.tar.gz",
      sha256 = "f66eff7a7a29fc26fffc675f71386d2457fe1f6fc414dddea7b2779d32eb0bb5",
      extract = true,
    } | Source,
    # ini
    {
      url = "https://github.com/justinmk/tree-sitter-ini/archive/32b31863f222bf22eb43b07d4e9be8017e36fb31.tar.gz",
      sha256 = "70d4193d666dbb0fe384fd335a8d4130daf9d59b7a8c08b1d01e167c91f4a045",
      extract = true,
    } | Source,
    # java
    {
      url = "https://github.com/tree-sitter/tree-sitter-java/archive/09d650def6cdf7f479f4b78f595e9ef5b58ce31e.tar.gz",
      sha256 = "a45d6f460f32f7c6b59c3f33a315c98a35195696fbcf5aebd53580eb9d83647f",
      extract = true,
    } | Source,
    # javascript
    {
      url = "https://github.com/tree-sitter/tree-sitter-javascript/archive/f772967f7b7bc7c28f845be2420a38472b16a8ee.tar.gz",
      sha256 = "551cb23a93154773138d4545421979444c14b235e663b0822ae1438d6bdd9c47",
      extract = true,
    } | Source,
    # json
    {
      url = "https://github.com/tree-sitter/tree-sitter-json/archive/73076754005a460947cafe8e03a8cf5fa4fa2938.tar.gz",
      sha256 = "8915d65c0cfe9e601de7c1d9df9fe90a750bf7986a08293a901b136c6dc17dde",
      extract = true,
    } | Source,
    # json5
    {
      url = "https://github.com/Joakker/tree-sitter-json5/archive/c23f7a9b1ee7d45f516496b1e0e4be067264fa0d.tar.gz",
      sha256 = "69d1cd7aaa463fcf29fe40a0541a969192fd1057b55299183915ea0ce00be1dc",
      extract = true,
    } | Source,
    # kotlin
    {
      url = "https://github.com/fwcd/tree-sitter-kotlin/archive/c4ddea359a7ff4d92360b2efcd6cfce5dc25afe6.tar.gz",
      sha256 = "42f032cbc1ac701cfd27f23475673d7fa636bdc4a398887237e5fa67c212521e",
      extract = true,
    } | Source,
    # lean
    {
      url = "https://github.com/Julian/tree-sitter-lean/archive/d98426109258b266e1e92358c5f11716d2e8f638.tar.gz",
      sha256 = "616cc21ce819fe5d5f226dc1b9db9250b75b14932f122991c694cb0f8c4ef291",
      extract = true,
    } | Source,
    # llvm
    {
      url = "https://github.com/benwilliamgraham/tree-sitter-llvm/archive/c14cb839003348692158b845db9edda201374548.tar.gz",
      sha256 = "dff58fabae0bf8bd1ec1badbbe28647ae2ce0a84bb5e188a427148c12de2e076",
      extract = true,
    } | Source,
    # make
    {
      url = "https://github.com/alemuller/tree-sitter-make/archive/a4b9187417d6be349ee5fd4b6e77b4172c6827dd.tar.gz",
      sha256 = "a1e078443fc36bfe562b40304c49e044d9230964dc82aba9e09b8cd7079ee3e0",
      extract = true,
    } | Source,
    # markdown, markdown_inline
    {
      url = "https://github.com/tree-sitter-grammars/tree-sitter-markdown/archive/62516e8c78380e3b51d5b55727995d2c511436d8.tar.gz",
      sha256 = "b69eaf8d664b6278e748588b48f613fbec5d4f461c53fa65e22c203240f93dfb",
      extract = true,
    } | Source,
    # meson
    {
      url = "https://github.com/staysail/tree-sitter-meson/archive/32a83e8f200c347232fa795636cfe60dde22957a.tar.gz",
      sha256 = "165213b0b86835a143a862050042eb6f859d615d0e4a6c03e016fe21ae2ed055",
      extract = true,
    } | Source,
    # nasm
    {
      url = "https://github.com/naclsn/tree-sitter-nasm/archive/570f3d7be01fffc751237f4cfcf52d04e20532d1.tar.gz",
      sha256 = "ffc303e1156400e9fe5091a234740b6776135da9d1fe20f9e8310f264912670a",
      extract = true,
    } | Source,
    # nickel
    {
      url = "https://github.com/nickel-lang/tree-sitter-nickel/archive/88d836a24b3b11c8720874a1a9286b8ae838d30a.tar.gz",
      sha256 = "b41a0b01b7149c58c82dfc25554ceccc59540f753f82b063ae7df15bccad54c8",
      extract = true,
    } | Source,
    # ocaml, ocaml-interface
    {
      url = "https://github.com/tree-sitter/tree-sitter-ocaml/archive/9965d208337d88bbf1a38ad0b0fe49e5f5ec9677.tar.gz",
      sha256 = "dd91ffef4b72b5b579938b82a493a38a00ddb2b9330ad953de63bb8a4fafcecb",
      extract = true,
    } | Source,
    # odin
    {
      url = "https://github.com/tree-sitter-grammars/tree-sitter-odin/archive/6c6b07e354a52f8f2a9bc776cbc262a74e74fd26.tar.gz",
      sha256 = "e6a82c6f803710e2a5a87c6b82d834aa45de787ab354a7903e5bed31fe6f6955",
      extract = true,
    } | Source,
    # proto
    {
      url = "https://github.com/sdoerner/tree-sitter-proto/archive/778ab6ed18a7fcf82c83805a87d63376c51e80bc.tar.gz",
      sha256 = "44c1b4ec515fc947c51fa19b422e37eebff1dc52eacab094461ba7ceafe0af9e",
      extract = true,
    } | Source,
    # python
    {
      url = "https://github.com/tree-sitter/tree-sitter-python/archive/4bfdd9033a2225cc95032ce77066b7aeca9e2efc.tar.gz",
      sha256 = "d815b5ecbe3a098ac62127922d617c46ba400347a711d26396fba58e728380b6",
      extract = true,
    } | Source,
    # rust
    {
      url = "https://github.com/tree-sitter/tree-sitter-rust/archive/1f63b33efee17e833e0ea29266dd3d713e27e321.tar.gz",
      sha256 = "b2706e8005340a9ed20b1109989efb31b52f369ced55e38965447a7cbad5d095",
      extract = true,
    } | Source,
    # scss
    {
      url = "https://github.com/serenadeai/tree-sitter-scss/archive/c478c6868648eff49eb04a4df90d703dc45b312a.tar.gz",
      sha256 = "d2178b5ba07e1fea9be0dd2d2c4c083805cc19678362e619144505e14f61dfa2",
      extract = true,
    } | Source,
    # sql
    {
      url = "https://github.com/DerekStride/tree-sitter-sql/archive/b9d109588d5b5ed986c857464830c2f0bef53f18.tar.gz",
      sha256 = "e079bd953640974057e101390b99984b3e83d84e7ed61e950b0e220b5ac52aef",
      extract = true,
    } | Source,
    # toml
    {
      url = "https://github.com/ikatyang/tree-sitter-toml/archive/7cff70bbcbbc62001b465603ca1ea88edd668704.tar.gz",
      sha256 = "93f36067123041867dabfd649c3588186c1643dfb1f69ad1fea3377c5b693294",
      extract = true,
    } | Source,
    # tsx, typescript
    {
      url = "https://github.com/tree-sitter/tree-sitter-typescript/archive/b1bf4825d9eaa0f3bdeb1e52f099533328acfbdf.tar.gz",
      sha256 = "c2015c7b4fbc4c0f609af72e360e58361c92b84cedf1917f9eb1cf9b01595b5e",
      extract = true,
    } | Source,
    # xml
    {
      url = "https://github.com/RenjiSann/tree-sitter-xml/archive/48a7c2b6fb9d515577e115e6788937e837815651.tar.gz",
      sha256 = "c32ea09ba83dd6ece1c22ae59be7ffb21d2ca33b866c1974a233c71ded8dd74c",
      extract = true,
    } | Source,
    # yaml
    {
      url = "https://github.com/ikatyang/tree-sitter-yaml/archive/0e36bed171768908f331ff7dff9d956bae016efb.tar.gz",
      sha256 = "46b6052ab86a14bb23406fbb5c56dc436798cb67b28a0e7fafe3183bc0c87788",
      extract = true,
    } | Source,
    # zig
    {
      url = "https://github.com/tree-sitter-grammars/tree-sitter-zig/archive/eb7d58c2dc4fbeea4745019dee8df013034ae66b.tar.gz",
      sha256 = "cbd7e67a98c9d2d7e4d28e2e87f4965625d864795bf5b46241bf839faae95f2c",
      extract = true,
    } | Source,
    base,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    # The cmake, lean and yaml scanners are C++; those three .so files link libstdc++.
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    grammars = { glob = "usr/lib/helix/runtime/grammars/*.so" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      # Aggregate of the 43 grammar repos: MIT throughout except tree-sitter-hcl
      # and tree-sitter-ini (Apache-2.0) and tree-sitter-gitcommit (WTFPL). Each
      # grammar is a standalone .so — mere aggregation, nothing is linked together.
      license_spdx = "MIT AND Apache-2.0 AND WTFPL",
      # source_provenance is deliberately absent: there is no single upstream to
      # point at, the package aggregates the 43 repositories pinned above.
    } | Attrs,
} | BuildSpec

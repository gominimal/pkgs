let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let tar = import "../tar/build.ncl" in

# Upstream Alpine minirootfs, version-pinned + sha256-verified. This packages a
# foreign (musl/busybox) userland as a guest rootfs — it is deliberately NOT
# built from source (there is no "build Alpine from source" path; consume the
# pinned upstream minirootfs instead). The build is pure file assembly (extract
# + overlay + write), so it runs without executing any guest binary and is
# host-arch-agnostic.
let version = "3.21.7" in
let major_minor = "3.21" in
let socat_version = "1.8.0.3-r0" in
# socat's transitive shared-lib deps (see the socat Source comment below).
let readline_version = "8.2.13-r0" in
let libncursesw_version = "6.5_p20241006-r3" in

let releases = "https://dl-cdn.alpinelinux.org/alpine/v%{major_minor}/releases" in
let main_repo = "https://dl-cdn.alpinelinux.org/alpine/v%{major_minor}/main" in
{
  name = "alpine-minirootfs",

  build_deps = [
    { file = "build.sh" } | Local,

    # Base Alpine minirootfs (per-arch tarball). Not auto-extracted — build.sh
    # unpacks it straight into $OUTPUT_DIR so the captured tree IS the guest /.
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{releases}/x86_64/alpine-minirootfs-%{version}-x86_64.tar.gz",
          sha256 = "8cba1ea3e8b500ea986a313d8eecf3d5952a2a0d23a69117bb81c023d9ceac05",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{releases}/aarch64/alpine-minirootfs-%{version}-aarch64.tar.gz",
          sha256 = "d1d1a3fae5f4d6146e9742790a47fcb116199622cfb8439f218a4d5fbe5000da",
        } | Source,
    } target,

    # socat (vsock-capable, 1.8.0.x). socat1 links libreadline.so.8,
    # libssl.so.3 and libcrypto.so.3; ssl/crypto ship in the base minirootfs,
    # but readline (and its libncursesw.so.6) do not — so they are pinned below
    # and overlaid alongside socat. Without them the guest init dies with a
    # missing-.so exit 127.
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{main_repo}/x86_64/socat-%{socat_version}.apk",
          sha256 = "caaad9c79573220fe100aad81487b20306c0745cb96baf5813f45fb212e8be90",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{main_repo}/aarch64/socat-%{socat_version}.apk",
          sha256 = "7cc3f5bade7fba9cd828b94560ce9f35de61246e19ecb595098110e81cf1c9ae",
        } | Source,
    } target,

    # readline — socat's libreadline.so.8 (and headers-free runtime).
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{main_repo}/x86_64/readline-%{readline_version}.apk",
          sha256 = "fa4ff2347886f5516d021b9064a00259b29fc6e2608eac5588a339de244acf12",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{main_repo}/aarch64/readline-%{readline_version}.apk",
          sha256 = "7dad49f83ecbcfa00c5c7df044a5566b928ac1995651cfff219e1df1c2b93871",
        } | Source,
    } target,

    # libncursesw — readline's libncursesw.so.6 (the `ncurses-libs` package is
    # an empty metapackage at this version; the .so lives in `libncursesw`).
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{main_repo}/x86_64/libncursesw-%{libncursesw_version}.apk",
          sha256 = "3919cf673e841d91865213799ccfd5f77a48f5f9f5402723167470295ee32a49",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{main_repo}/aarch64/libncursesw-%{libncursesw_version}.apk",
          sha256 = "c1a5a3a552ad4d44c94454555f38de71b151dc2d608ea2246d92b3bd845b7f3a",
        } | Source,
    } target,
    base,
    tar,
  ],

  # The minirootfs is a self-contained foreign userland; nothing from the
  # Minimal (glibc) graph is injected into the guest.
  runtime_deps = [],

  cmd = "./build.sh",
  build_args = {
    include version,
    include socat_version,
    include readline_version,
    include libncursesw_version,
  },

  # The whole guest root tree is the output. allow_executable keeps busybox,
  # socat and ld-musl executable. Empty mountpoint dirs (proc/sys/dev/tmp/run)
  # are materialised with a sentinel by build.sh so they survive glob capture.
  outputs = {
    rootfs =
      {
        glob = "{bin,sbin,lib,etc,usr,root,home,opt,srv,media,mnt,var,run,proc,sys,dev,tmp}/**",
        allow_executable = true,
      } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # Alpine is neither a GithubRepo nor a GnuProject, so source_provenance
      # is intentionally omitted (provenance is the pinned sha256 above).
    } | Attrs,
} | BuildSpec

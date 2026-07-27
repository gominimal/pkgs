let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let e2fsprogs = import "../e2fsprogs/build.ncl" in

# Pinned upstream Alpine release the guest userland is assembled from. To bump:
# raise both, then refresh every sha256 below from the same branch — the .apk
# set is version-locked to that branch's APKINDEX, so the closure has to be
# re-resolved as a whole, not package by package.
let alpine_branch = "v3.24" in
let alpine_release = "3.24.1" in

let alpine_arch =
  match {
    { arch = 'Arm64, .. } => "aarch64",
    { arch = 'Amd64, .. } => "x86_64",
  } target
in

# One pinned Alpine binary package. The version is the same on both arches but
# the artifact is not, so each entry records both digests and the build target
# picks one.
let apk = fun pkg arm64_sha256 amd64_sha256 =>
  {
    url = "https://dl-cdn.alpinelinux.org/alpine/%{alpine_branch}/main/%{alpine_arch}/%{pkg}.apk",
    sha256 =
      (
        match {
          { arch = 'Arm64, .. } => arm64_sha256,
          { arch = 'Amd64, .. } => amd64_sha256,
        } target
      ),
  } | Source
in
{
  name = "microvm-rootfs",

  # A read-only ext4 guest userland for a libkrun microVM, assembled entirely
  # from pinned upstream Alpine artifacts: the minirootfs tarball (musl libc +
  # busybox + baselayout) overlaid with a sha256-pinned closure of .apk files.
  # No package from this repo ends up in the image, so it carries no glibc —
  # that closure was the bulk of the previous ~180 MB image, against ~33 MB
  # here. See build.sh for the assembly, and for the sizing decision
  # https://github.com/gominimal/pkgs/issues/531.
  #
  # The image is loaded as a virtio-blk block device (/dev/vda). The guest
  # minimald ships as the initramfs pid-1, mounts this image, and chroots into
  # it — there is no standalone init in the image itself, and no minimald in it
  # either.
  #
  # Nothing here is a runtime_dep: runtime deps are hardlinked into the build
  # sandbox and would drag their glibc closures back in. Both entries below are
  # build-only — base gives build.sh bash/coreutils/tar/findutils, and
  # e2fsprogs gives mke2fs to pack the image.
  runtime_deps = [],
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    e2fsprogs,

    # Alpine minirootfs: a complete rootfs tarball with musl, busybox (which
    # covers coreutils/grep/awk/sed and the ip, nsenter, fstrim and blkid
    # applets), and alpine-baselayout's /etc (passwd, group, hosts) plus the
    # /dev, /proc, /sys, /run, /tmp and /var/lib mountpoints.
    {
      url = "https://dl-cdn.alpinelinux.org/alpine/%{alpine_branch}/releases/%{alpine_arch}/alpine-minirootfs-%{alpine_release}-%{alpine_arch}.tar.gz",
      sha256 =
        (
          match {
            { arch = 'Arm64, .. } => "f55a90f69052c5bd6f92cb09a8f47065970830b194c917a006fb94028e721259",
            { arch = 'Amd64, .. } => "41f73e3cf5fa919b8aa5ca6b30dc48f0da2720776d7423e2a7748211456fe081",
          } target
        ),
    } | Source,

    # Tools the guest needs that busybox does not provide, or provides only as
    # a partial applet. bash because the in-guest minimald chroots in and runs
    # /bin/bash; git because its session bring-up inits a minimal context that
    # shells out to git; e2fsprogs for mkfs.ext4, which the guest uses to format
    # the per-VM writable volume (/dev/vdb) on first boot; iproute2-minimal and
    # util-linux-misc for the real ip and nsenter (network/namespace plumbing —
    # busybox's applets are subsets); fstrim to reclaim space from /dev/vdb.
    apk "bash-5.3.9-r1"
      "95f4f976bdf2f4ca18ff41c32916eb6d7b12a0dae12504d55d04427460d6542f"
      "4ad962f26fb3c68365171233fe61e3c51bbee1cab35e8dc661198233daeab0dd",
    apk "e2fsprogs-1.47.4-r0"
      "52fd401e79ce6b0ff7648733ba4de3135083cd0132543534e72106e7ea767a00"
      "c7a99a18206827b09f0cfa2373e6f1db0963845ad8468a378a3b99a7e716a0e8",
    apk "fstrim-2.42.1-r0"
      "9781870281182e8a349c9ff19e6bbe9493f5fa6911fa64a3762de7580258489e"
      "a9f9419250d9eabbaef57f40d4daa5ef6906b3cc02c2ae3c8919fc3c7e9b0364",
    apk "git-2.54.0-r0"
      "ea41e2f837f1f6a8b66e72a5ece0fc75cca44f76f49cf5500d467fc5627d0ab7"
      "5a2c6782774d2e891fc2fc3fdc50c3c2743b8eb2dc7cda69b6b723af2eedcf78",
    apk "iproute2-minimal-7.0.0-r0"
      "5ef23a7fd11df32dae739de6f3faca463711809eeab0391c38ad268636ee0b70"
      "7a40bb386c19e7945e09683402adf2e30b15ce0003267376aa758280ce96dc27",
    apk "util-linux-misc-2.42.1-r0"
      "4a21ca798bc5b7b0d2db7cbfab5742ad3b3168f09eb8a7634667556123e11c1a"
      "f2d5cc17637ecf9c7c8f38ebd5272841ab8c5d46fa5350332f2595ed2df59f82",

    # Shared-library closure of the six packages above, resolved against the
    # v3.24 main APKINDEX. Alpine deps are recorded as sonames, so this is the
    # transitive set needed for them to load — nothing here is a direct guest
    # tool. It must be re-resolved as a unit on an Alpine bump.
    apk "brotli-libs-1.2.0-r1"
      "e0e7a7892f28326a9f18e09607b1aea72baedda470bc4e3d2b11262b9ae5dda3"
      "f0823de7c6d45859aeb6a7facfc5cfbf2dadb83ad4f27c794cb6ecc74e578cee",
    apk "c-ares-1.34.8-r0"
      "689603d300dc56f0b99e313506e4d7b3a3ffb87cec536324f8a306bc218afe67"
      "123fdeadc5ec884b897787f98d865492bf70402697b251cd1f3591a00b8c9d73",
    apk "e2fsprogs-libs-1.47.4-r0"
      "52124971ae397d599aadd79263fcd68fc9e271922ccf8185b124f35fe24c60c8"
      "2e067395a6981b06cfd2cd3abf0e6c6574f7ef64d02e01f75fc5323d4a337fb9",
    apk "libblkid-2.42.1-r0"
      "5de536dd5f80772946aebf99211695a1f4ad033568d5c9ebd0d7d1dead33de44"
      "c5a5da8aa518196b613ad4654535be5fe22003253535a84e226fce055fe91e1a",
    apk "libcap2-2.78-r0"
      "e13be383f18b1fcfe895361d816ff7cfd2b3c265e442bb371c4a234b29b0e4a9"
      "42886a7b4bcde26347c712925c8dc7db202b6029ef9b8c7ee81577ab7bdd8fad",
    apk "libcom_err-1.47.4-r0"
      "a75b5955ff57046e33fc2842cfe466dc77d8e68305d5c86c6646b38a069490a2"
      "4723d0fb8e286dc6adb54dd3cdaedcd8db54260f75ee778a5acb4c16922c0f52",
    apk "libcurl-8.21.0-r0"
      "df0c0e4b870bf48759fd751116986019e92d40279669e9f0348ea079a7735013"
      "78538a948a4b8453184ddeb85818a82439735c3384c15b04d37c1e69be2bef19",
    apk "libeconf-0.8.3-r0"
      "cf0899d49ded0a6891e3cdf1b37887f2ecd77293afe1d8f3cb8937763c83f183"
      "2a791c7957961f830cf31b04f35f814a63afcf633badc9052425ff1cf2f64380",
    apk "libelf-0.195-r0"
      "1c108314af454a885ac0b053201db57027470c4f2309412c016897e2a2bf5d0e"
      "78c5a1993342ab1bdcdce30639fd0937e8000f6d0d85cea171f573d31decd036",
    apk "libexpat-2.8.2-r0"
      "3c112b8ce1dd8211a6446921654e5f85047db803ed6827147691b4789a523209"
      "cbd8ae7af319512615ae546970112667136ac88e6c18dcb2059bd0dfceb877fb",
    apk "libfdisk-2.42.1-r0"
      "0444bf4ecd3758b6638bf55afc6041c08f5ba080643b4ee8cc54788327ebf5af"
      "b8fb5e44e588e9bd5567f9570f227da65339c7b6e46a835e9eefc7f4dd6f74e7",
    apk "libidn2-2.3.8-r0"
      "d02ffda4510652f89c5fb89cd2e7ff721afb0c74e7d75476ad60bebe7ac0ae20"
      "7d038ac558dde464964b033ce5126dd2eaf84cc414dc15e77c5424a321d0ebee",
    apk "libmnl-1.0.5-r2"
      "0ca382c70f78affef3a4a28016aab25ad8c3ccf1bcdad59f3968d4536a7b2478"
      "3693162ff7c27998dbbb2da1c4bd9072079cd55af1fa3d6d2ade51d276e20157",
    apk "libmount-2.42.1-r0"
      "d2e5eefddf71f538ddbb546bd52783f0c7f20c73c9d6b82e4a809dc6234592ef"
      "fc6fd06c1244b804fc0716d4978c4a9783ad2a461b31e1b49492d4dfcbffb02b",
    apk "libncursesw-6.6_p20260516-r0"
      "51a7aa4b3ec40b144d0801c0544e0a9f62e2a41d04b6067bb5e95786040741c6"
      "cf8caa8a88bc4ce9d9e395567fefaf9ef7fbd55c50ae6155b35c1b58f3755023",
    apk "libpsl-0.21.5-r3"
      "b31e91371425d5f80c1db5cba2a849956b65c802add0b49de844b2ca961aa8da"
      "ec665a344b6e887f00f0a47015cc732c3a281b69e84641dc8662ea234fde6cdb",
    apk "libsmartcols-2.42.1-r0"
      "61763d7e009b483c677a8b760b14041ec52feb267167abb0b5c4e7119491892c"
      "3a117674cf383d5c5d5d61aa3f2a91795d7700911acbbff18a7094889ad01a4b",
    apk "libunistring-1.4.2-r0"
      "58abfcbce2459071c505771a572a79953d6043d72b643ed0d5285ca39cdaf85c"
      "3aa6030e603e34d96192742f327c0509f409c6769ce2e7b1463685dede38d714",
    apk "libuuid-2.42.1-r0"
      "d2f69552b05184ba205dbc8aa0e79f8a080fcf746ec5e5e25eb89d66fbbe6db6"
      "e86120f2d764e9a4e1713a79fd622d815754fbfa19e525170801b174a5a18273",
    apk "ncurses-terminfo-base-6.6_p20260516-r0"
      "e0c546b9461bdce206a90bc720cb69aa4628b5a5b8d908c3e5084e00f28f6a9d"
      "ce83be6d0bd10584a53c3a5868cc1595ce5f0f8e0b621f8f7f70b6144e521fc9",
    apk "nghttp2-libs-1.69.0-r0"
      "10ec950fca526db87bbdc0702ba623fca6639df15abb48229f548d6812563b33"
      "7d7705cea464389989d3ca6b9505dbfce3cf25cfca1eeb06709a9909f93f4f11",
    apk "pcre2-10.47-r1"
      "7bdff8ceaae86798a468382c02ae1548531681c1def07671e0511d8a06931a57"
      "e2be27046bc933ff6716e5c6e08e301fc0cc3ddb28db1db5510057846238f276",
    apk "readline-8.3.3-r1"
      "9f0ae0923c02b0d6aba62e9173542b65396ba3f0efefcbf087ea32f1120e7b34"
      "766911ecb986a6c5cf0841a6b556cd1e9dbbf22b3559726de32416486cd15c81",
    apk "setarch-2.42.1-r0"
      "f4d61b8272088038b8c23b15623edb951212d684ab1e6f1564c463e986b7540c"
      "7529811aead2dfd0d52343a4c7fb83067331f1b73bae3c8058afa22ccfc9f261",
    apk "skalibs-libs-2.15.0.0-r0"
      "7ea58fb512067402b519079fcce8a48381eb2b9c690341c4a017aa15f719c198"
      "3301f6ccbeaea49cdd966c7e636898a8612fb8fe964a15f24f6d204b3944c3f3",
    apk "utmps-libs-0.1.3.3-r0"
      "d6487b6f260728969191314f6706d4cc62527370e757ec3ac6f7fee8ed38cf88"
      "497f0f1cb51f0e6c1acc338fded0dc7722b1d43ea17bdb749f0d556794f8b2d8",
    apk "zstd-libs-1.5.7-r2"
      "2bb5136c89f5b0bbe1554c8915a3b520d5aa63ae2a51d4d821eb81698db5a818"
      "23c6065b0049b2406441564bcf0032515a43f78e80d76fcb85535a3803ef5d4e",
  ],

  cmd = "./build.sh",

  outputs = {
    rootfs = { glob = "usr/share/microvm-rootfs/rootfs.img" } | OutputData,
  },

  attrs =
    {
      upstream_version = alpine_release,
    } | Attrs,
} | BuildSpec

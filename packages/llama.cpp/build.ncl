let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let git = import "../git/build.ncl" in
let patch = import "../patch/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in

let curl = import "../curl/build.ncl" in
let hwdata = import "../hwdata/build.ncl" in
let pciutils = import "../pciutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in

# `version` keys the source tarball (GitHub's archive of the tag: `v1.0.1` for a
# stable release, so `version = "1.0.1"`). `build_num` is the b#### build the
# release was cut from (its nightly-tag.txt): the web UI bundle is published only
# under it, and it is the package's upstream_version, because llama.cpp's
# advisories are written in builds. For a build with no stable release name, the
# two are the same. pkgmgr moves both.
let version = "1.1.0" in
let build_num = "b12774" in
{
  name = "llama.cpp",
  build_deps = [
    { file = "build.sh" } | Local,
    # The CPU backends are dlopen()ed: search only GGML_BACKEND_DIR, never the
    # executable's or the current directory. See build.sh.
    { file = "ggml-backend-dir-only.patch" } | Local,
    # The x86 CPU variant scorer checks CPUID only: also require the OS to have
    # enabled the register state (XCR0). See build.sh.
    { file = "ggml-cpu-feats-xcr0.patch" } | Local,
    # License texts and NOTICEs of everything compiled into the embedded web UI
    # (pkgs#994), generated from this version's ui/apps/chat/package-lock.json by
    # gen-ui-notices.py. The build doesn't run it: rerun it on every bump.
    # build.sh fails if the file's header doesn't match the UI and lock it builds.
    { file = "ui-THIRD-PARTY-NOTICES" } | Local,
    {
      url = "gs://minimal-staging-archives/ggml-org/llama.cpp/%{version}.tar.gz",
      sha256 = "370603b8d973f4c02cd68ff2b815859c0f71878a57075cf2758015ceb7fc7990",
      extract = true,
      strip_prefix = "llama.cpp-%{version}",
    } | Source,
    {
      # llama-server's web UI for this build number, mirrored from
      # https://huggingface.co/buckets/ggml-org/llama-ui/resolve/%{build_num}/dist.tar.gz
      # (sha256 matches upstream's dist.tar.gz.sha256). build.sh unpacks it into
      # ui/apps/chat/dist so the build doesn't fetch the moving `latest` UI.
      # Bump with `build_num`.
      url = "gs://minimal-staging-archives/ggml-org/llama-ui/%{build_num}-dist.tar.gz",
      sha256 = "86deb1840ffa60e1b0d43d1e2efddbd08a0993693b9c9a0d80254bfc8ab6fad0",
      extract = false,
    } | Source,
    base,
    git,
    patch,
    make,
    cmake,
    toolchain,
  ],
  runtime_deps = [
    curl,
    hwdata,
    pciutils,
    subsetOf gcc ["libgcc", "libstdcpp", "libgomp"],
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
    include build_num,
  },
  outputs = {
    llama-server = { glob = "usr/bin/llama-server" } | OutputBin,
    llama-cli = { glob = "usr/bin/llama-cli" } | OutputBin,

    libs = { glob = "usr/lib/*" } | OutputLib,
    # One CPU backend per microarchitecture, dlopen()ed from GGML_BACKEND_DIR
    # (/usr/lib/ggml) at run time; the loader keeps the best one for the host.
    cpu-backends = { glob = "usr/lib/ggml/libggml-cpu-*.so*" } | OutputLib,
    # ui-THIRD-PARTY-NOTICES: the web UI's third-party license texts (pkgs#994).
    licenses = { glob = "usr/share/licenses/llama.cpp/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = build_num,
      # llama.cpp itself is MIT. What ships also carries:
      # - vendor/ C++: cpp-httplib, nlohmann/json (MIT); miniaudio, stb,
      #   sheredom/subprocess.h (public domain or Unlicense).
      # - The embedded web UI (llama-ui dist for this build, in
      #   libllama-server-impl.so): 277 npm packages from ui/apps/chat's
      #   package-lock.json. Mostly MIT and ISC, plus BSD-3-Clause (highlight.js,
      #   fast-uri, qs), Apache-2.0 (pdfjs-dist, dexie, @internationalized/date,
      #   @swc/helpers, aria-query, axobject-query), BSD-2-Clause (entities,
      #   json-schema-typed), DOMPurify (MPL-2.0 OR Apache-2.0; Apache-2.0
      #   taken). The KaTeX fonts embedded in its CSS are MIT. Llama UI's
      #   LlamaSans/LlamaMono fonts (Geist-derived, in the dist as woff2) are
      #   OFL-1.1.
      #   The llama.cpp logo, favicons and app icons are from ggml-org's
      #   llama-brand (npm @ggml-org/llama-brand; its CSS is MIT, its fonts
      #   OFL-1.1): the marks are CC-BY-NC-4.0, plus its BRAND-USAGE.md grant to
      #   redistribute them, commercially too, in software packages. CC-BY-NC
      #   alone would not allow that, and the combination has no SPDX id, so it
      #   is declared as LicenseRef-llama-brand: an SBOM or license scan sees
      #   the marks' terms instead of an expression that silently omits them.
      #   Both texts are in ui-THIRD-PARTY-NOTICES.
      # The minified bundle carries no license texts or NOTICE files, so every
      # one is in ui-THIRD-PARTY-NOTICES (pkgs#994), installed under
      # usr/share/licenses/llama.cpp and generated from the lock by
      # gen-ui-notices.py: the npm packages, the fonts' OFL.txt, and 3 libraries
      # vendored in ui/apps/chat/src/lib/vendors (nerdamer-prime, decimal.js:
      # MIT; big-integer: Unlicense).
      license_spdx = "MIT AND Apache-2.0 AND BSD-3-Clause AND BSD-2-Clause AND ISC AND Unlicense AND OFL-1.1 AND LicenseRef-llama-brand",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ggml-org",
        repo = "llama.cpp",
      },
      # ggml-cpu is compiled once per CPU variant: 8 on arm64, 14 on x86_64.
      build_cost_multiple = 5,
    } | Attrs,

  # No test_deps: base would mask a missing library. Both binaries exited 127
  # (libllama.so.0 etc. not shipped) before build.sh kept the SONAME links.
  tests = {
    llama-cli = standaloneTest "/usr/bin/llama-cli --version",
    llama-server = standaloneTest "/usr/bin/llama-server --version",
    # The CPU backend is not linked in: it is loaded from /usr/lib/ggml at run
    # time, and --version never loads it. `-ot x=CPU` loads every backend and
    # throws "unknown buffer type" (exit 1) unless a CPU backend loaded and
    # registered its "CPU" buffer type; --list-devices then exits 0 with no
    # model. (--list-devices alone lists only non-CPU devices, so it passes with
    # no CPU backend at all.)
    cpu-backend-cli =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["/usr/bin/llama-cli", "-ot", "x=CPU", "--list-devices"]],
      } | Test,
    cpu-backend-server =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["/usr/bin/llama-server", "-ot", "x=CPU", "--list-devices"]],
      } | Test,
    # CVE-2026-133710 (ggml-org/llama.cpp#32601, in since b12556): an hrm_text
    # GGUF whose layers_per_stack * h_cycles * (l_cycles + 1) wraps uint32 to
    # block_count passed the slot-count assert, and load_arch_tensors() then
    # wrote past model.layers. The file below has only the metadata that
    # reaches that check (no vocab, no tensors): 1073741825 * 2 * 2 = 2^32 + 4
    # against block_count 4. The fixed loader must refuse it with its own
    # message and a normal error exit, not a signal. Without the fix the
    # product wraps to 4, the check passes and loading goes on to fail later,
    # for want of a vocab, so the grep fails.
    hrm-slot-overflow =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              le() { # value, byte count: little-endian bytes
                local v=$1 n=$2 s=
                while [ "$n" -gt 0 ]; do s+=$(printf '\\x%02x' $((v & 255))); v=$((v >> 8)); n=$((n - 1)); done
                printf "$s"
              }
              str() { le ${#1} 8; printf %s "$1"; }
              kv_u32() { str "$1"; le 4 4; le "$2" 4; }
              kv_f32() { str "$1"; le 6 4; le "$2" 4; }
              kv_str() { str "$1"; le 8 4; str "$2"; }
              {
                printf GGUF; le 3 4; le 0 8; le 9 8
                kv_str general.architecture hrm_text
                kv_u32 hrm_text.context_length 16
                kv_u32 hrm_text.embedding_length 8
                kv_u32 hrm_text.block_count 4
                kv_u32 hrm_text.attention.head_count 1
                kv_f32 hrm_text.attention.layer_norm_rms_epsilon 0x358637bd
                kv_u32 hrm_text.hrm.layers_per_stack 1073741825
                kv_u32 hrm_text.hrm.h_cycles 2
                kv_u32 hrm_text.hrm.l_cycles 1
              } > /tmp/hrm.gguf
              rc=0
              out=$(/usr/bin/llama-cli -m /tmp/hrm.gguf -st -p hi -n 1 --no-warmup </dev/null 2>&1) || rc=$?
              printf '%s\n' "$out" | grep -qF 'hrm: cache-slot count 4294967300 (layers_per_stack 1073741825, h_cycles 2, l_cycles 1) does not match block_count 4'
              [ "$rc" -ge 1 ] && [ "$rc" -lt 128 ]
            "%,
          ],
        ],
      } | Test,
    # The web UI's notices ship, for this UI version, with the texts that must
    # travel: svelte (MIT), dompurify (MPL-2.0 OR Apache-2.0, both texts) and
    # pdfjs-dist (Apache-2.0; its npm package has no NOTICE, which is recorded).
    ui-notices =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "grep -qx 'llama-ui version: %{build_num}' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES"],
          ["/bin/bash", "-c", "grep -qx 'svelte@[0-9.]*' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES && grep -qx 'dompurify@[0-9.]*' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES"],
          ["/bin/bash", "-c", "grep -A4 -x 'pdfjs-dist@[0-9.]*' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES | grep -qx 'License: Apache-2.0'"],
          ["/bin/bash", "-c", "grep -A4 -x 'pdfjs-dist@[0-9.]*' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES | grep -qx 'NOTICE: none in the package'"],
          ["/bin/bash", "-c", "grep -q 'Apache License' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES && grep -q 'Mozilla Public License' /usr/share/licenses/llama.cpp/ui-THIRD-PARTY-NOTICES"],
        ],
      } | Test,
  },
} | BuildSpec

let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let odin = import "../odin/build.ncl" in
let util-linux = import "../util-linux/build.ncl" in

let version = "dev-2026-06" in
{
  name = "ols",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/DanielGavin/ols/archive/refs/tags/%{version}.tar.gz",
      sha256 = "f8055ff723994dc4debc02817c230d0173c43a23df4a9d6a7104fea69bfeeb79",
      extract = true,
    } | Source,
    base,
    util-linux,
  ],

  runtime_deps = [
    # ols is an Odin program, but odin is a runtime dep rather than a build-only
    # one: the server shells out to `odin root` on initialize to locate the
    # base/core/vendor collections it indexes, and falls back to $ODIN_ROOT or
    # the directory of the `odin` binary on PATH. Without odin present it comes
    # up with no standard library at all.
    odin,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    ols = { glob = "usr/bin/ols" } | OutputBin,
    odinfmt = { glob = "usr/bin/odinfmt" } | OutputBin,
    # ols cannot resolve `builtin`/`intrinsics` declarations without these two
    # source files. It looks for them next to the binary first, then at this
    # fixed path -- which is the one it is packaged at, since /usr/bin/builtin
    # is not somewhere a directory belongs.
    builtin = { glob = "usr/share/ols/builtin/*" } | OutputData,
    license = { glob = "usr/share/ols/LICENSE" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "DanielGavin",
        repo = "ols",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/ols version",

    odinfmt =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "printf 'package main\\nmain::proc(){x:=1;_=x}\\n' > f.odin"],
          ["/bin/odinfmt", "-w", "f.odin"],
          ["/bin/bash", "-c", "grep -q 'main :: proc() {' f.odin"],
        ],
      } | Test,

    # Drives a real LSP session over stdio and asks for hover twice, because the
    # two answers fail for different reasons:
    #
    #   len          resolves out of the `builtin` output above. ols logs an
    #                error and answers everything else normally if that
    #                directory is missing, so nothing but a builtin lookup
    #                notices.
    #   fmt.println  resolves out of the core collection, which ols finds by
    #                running `odin root`. With odin absent from PATH this hover
    #                comes back null while the `len` one still succeeds -- so it
    #                is the half that pins the runtime dep.
    lsp_hover =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
          set -eu
          P=/tmp/olsproj
          mkdir -p $P
          SRC='package main\n\nimport "core:fmt"\n\nmain :: proc() {\n\tn := len([]int{1})\n\tfmt.println(n)\n}\n'
          printf '%b' "$SRC" > $P/main.odin
          # The same text has to go over the wire as a JSON string literal.
          JSON_SRC=${SRC//\"/\\\"}

          send() { printf 'Content-Length: %d\r\n\r\n%s' "${#1}" "$1"; }
          hover() { send "{\"jsonrpc\":\"2.0\",\"id\":$1,\"method\":\"textDocument/hover\",\"params\":{\"textDocument\":{\"uri\":\"file://$P/main.odin\"},\"position\":{\"line\":$2,\"character\":$3}}}"; }

          OUT=$({
            send "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"processId\":null,\"rootUri\":\"file://$P\",\"capabilities\":{}}}"
            send '{"jsonrpc":"2.0","method":"initialized","params":{}}'
            send "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file://$P/main.odin\",\"languageId\":\"odin\",\"version\":1,\"text\":\"$JSON_SRC\"}}}"
            hover 2 5 7
            hover 3 6 8
            send '{"jsonrpc":"2.0","id":4,"method":"shutdown","params":null}'
            send '{"jsonrpc":"2.0","method":"exit","params":null}'
          } | /bin/ols)

          check() { printf '%s' "$OUT" | grep -q "$1" || { printf '%s\n' "$OUT" >&2; exit 1; }; }
          check 'len :: proc(array: Array_Type)'
          check 'fmt.println :: proc'
          "%,
          ],
        ],
      } | Test,
  },
} | BuildSpec

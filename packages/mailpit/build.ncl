let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in

# Mailpit: local SMTP server + web UI that catches outgoing mail in
# development (Rails `config.action_mailer.smtp_settings` -> localhost:1025,
# UI on :8025). Single static binary with the UI embedded; the UI is built
# with npm from the locked package-lock.json before `go build`, as upstream's
# release build does.
let version = "1.31.4" in
{
  name = "mailpit",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/axllent/mailpit/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "cd4d0d40044dde07df8ff5c168f6d95356770dca45627a9f9910ba66e70d7832",
      extract = true,
      strip_prefix = "mailpit-%{version}",
    } | Source,
    base,
    go,
    node-lts,
  ],
  # Go module downloads and the UI's npm install.
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    mailpit = { glob = "usr/bin/mailpit" } | OutputBin,
  },
  runtime_deps = [],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "axllent", repo = "mailpit" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    # Accepts a message over SMTP and serves it back from the HTTP API.
    smtp_roundtrip =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "mailpit version 2>&1 | grep -q %{version} && d=$(mktemp -d) && (mailpit --database \"$d/db\" --smtp 127.0.0.1:1025 --listen 127.0.0.1:8025 >\"$d/log\" 2>&1 &) && for i in $(seq 50); do (exec 3<>/dev/tcp/127.0.0.1/1025) 2>/dev/null && break; sleep 0.2; done && exec 3<>/dev/tcp/127.0.0.1/1025 && printf 'HELO t\\r\\nMAIL FROM:<a@example.com>\\r\\nRCPT TO:<b@example.com>\\r\\nDATA\\r\\nSubject: mailpit-smoke\\r\\n\\r\\nhi\\r\\n.\\r\\nQUIT\\r\\n' >&3 && sleep 1 && exec 4<>/dev/tcp/127.0.0.1/8025 && printf 'GET /api/v1/messages HTTP/1.0\\r\\nHost: localhost\\r\\n\\r\\n' >&4 && grep -q mailpit-smoke <&4"],
        ],
      } | Test,
  },
} | BuildSpec

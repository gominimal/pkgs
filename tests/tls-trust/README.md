# tests/tls-trust

Checks that every TLS client we ship refuses a distrusted CA. It runs once per incident,
and again every week as a regression check.

Each check runs in a min box, built from the packages users actually get. This directory
has its own `minimal.toml`, and its `[upstream]` pins `gominimal/pkgs`. The clients come
from that commit, the same way a user's project gets them. They do not come from the
checkout this file sits in.

```
tests/tls-trust/
  minimal.toml               [upstream] pin + 6 tasks (live / offline x 3 package sets)
  run.sh                     entry point: --mode live|offline --profile <dir> ...
  lib/common.sh              timeouts, classifiers, openssl-verify helpers, JSON
  lib/c-clients.sh           curl, wget, openssl, gnutls-cli (+certtool), git
  lib/python.sh              python3 urllib, pip
  lib/httpie.sh              httpie
  lib/js.sh + probe.mjs      node, node --use-system-ca, bun, deno (one probe for all)
  lib/java.sh + Probe.java   the JDK on PATH
  lib/go.sh + probe.go       go
  lib/rust.sh                uv, uv with UV_SYSTEM_CERTS=1
  lib/controls.sh            SELFTEST and NEGCONTROL
  incidents/<id>/            one directory per incident (the "profile")
    targets.txt              hosts that must be refused: <host> <group> <label>
    positives.txt            hosts that must connect
    expected.txt             verify_at (offline instant), blocklist_rows, expected failure class
    chains/bad/<host>.pem    the chain each target serves (public certs only)
    chains/good/<host>.pem   the chain each positive serves
    chains/anchors.pem       the distrusted roots the bad chains anchor at
    chains/SHA256SUMS        pins every PEM; chains/README.md cites the source
```

The directory is `incidents/`, not `profiles/`, because min treats `profiles/<name>/` as
its own profile convention (`profile.ncl`). A `profiles/` here breaks session creation.

## Running it

From a pkgs checkout, `min task run offline -C tests/tls-trust --no-input` works as is.
That was tested from a worktree of this branch. `min task run` uploads only tracked files,
though. So when you edit the harness or a profile, or need a second pin running alongside,
copy this directory into a scratch git repo, commit it, and run from there:

```sh
X=$(mktemp -d) && cp -R tests/tls-trust/. "$X" && cd "$X" && git init -q && git add -A && git commit -qm tls-trust
min task run live          -C "$X" --config-dir "$(mktemp -d)" --no-input
min task run offline       -C "$X" --config-dir "$(mktemp -d)" --no-input
min task run live-alt      -C "$X" ...     # node-lts + jdk-21
min task run live-jdk27    -C "$X" ...     # jdk-27
min task run offline-alt   -C "$X" ...
min task run offline-jdk27 -C "$X" ...
# task args: --only REGEX  --jobs N  --timeout S  --details fail|all|none  --profile DIR
min task run live -C "$X" --no-input --only '^(curl|go)$' --details all
```

**Why six tasks.** Some packages install the same paths. node and node-lts both install
`usr/bin/node`. jdk-21, jdk-25 and jdk-27 all install `usr/lib/jvm`. If two of them share
a task, one of them silently wins, and its row reports the wrong runtime. So `live` and
`offline` carry everything else plus jdk-25. `*-alt` carries node-lts and jdk-21.
`*-jdk27` carries jdk-27. Each split task restricts itself with `--rows`.

A full `live` run takes about 16 s inside the box (about 30 s wall with session setup).
`offline` takes about 8 s. Probes run 8 at a time (`--jobs`), and each one has a hard
deadline (`--timeout`, default 15 s). The single-threaded harness this replaces took 2 to
3 minutes per task.

## Modes

| mode | what runs | refused | accepted | anything else |
|---|---|---|---|---|
| `live` | a real handshake and HTTP request per client, for every host in targets + positives | `CERT-FAIL` (only a certificate-verification error) | `CONNECTED` | `NET-ERR` (DNS, connect, timeout) or `ERR` |
| `offline` | no network. Each client's verifier validates the captured chains at `verify_at` | `REJECTED` (only trust errors: unknown issuer, untrusted, distrusted, blocked) | `ACCEPTED` | `ERR` (expiry, parse error, crash) |

A live probe that ends in `NET-ERR` or `ERR` is retried once, so one network blip does
not turn a weekly run INCONCLUSIVE. A trust verdict is never retried. A probe that hits
the backstop deadline (exit 124 or 137) counts as `NET-ERR`.

Verdicts:

- `VULNERABLE`: at least one bad target was accepted.
- `FIXED`: every bad target was refused, and every positive was accepted.
- `INCONCLUSIVE`: anything else. A positive failed, a probe hit a network error, a probe
  errored, or a client is missing.

`N/A (live-only)` or `N/A (offline-only)` means the row has no honest check in that mode.
The table legend says why.

**Exit codes:**

| code | meaning |
|---|---|
| 0 | clean |
| 1 | INCONCLUSIVE rows, with no VULNERABLE row |
| 2 | at least one VULNERABLE row |
| 3 | the harness is invalid: SELFTEST is not FIXED, or NEGCONTROL is not VULNERABLE |

`--json -` (every task passes it) prints a `=== json ===` block. It holds per-row
client, version, mode, proof, verdict and per-host results. It also holds run metadata:
profile, pinned pkgs commit, timestamp, verify_at, jobs, timeout, runtime, the selftest
and negcontrol verdicts, and the exit code.

## The control rows (every run)

- **SELFTEST** uses curl (live) or `openssl verify` (offline) against the box's system
  bundle, with `chains/anchors.pem` stripped out. It must read `FIXED`. If it doesn't, the
  classifier or the profile is broken, not the packages.
- **NEGCONTROL** uses the same tools against the bundle plus the anchors. It must accept
  every bad target, which gives `VULNERABLE`. That proves each target is still a working
  probe: the host is up, the chain still anchors at the profile's roots, and nothing has
  expired at `verify_at`. If it reads `BROKEN (n/12 accepted)`, a FIXED anywhere else
  means nothing. To test this guard, `verify_at` was moved to 2031, when every leaf has
  expired. The run gave exit 3 and NEGCONTROL `BROKEN (0/12 accepted)`.

## What offline proves, per row

| row | offline | what it proves |
|---|---|---|
| openssl | **path** | `openssl verify` against OpenSSL's default store (OPENSSLDIR, or SSL_CERT_FILE/DIR). Inside the box that store is our package's, never the host's; the header prints `openssl version -d`. |
| gnutls-cli | **path** | `certtool --verify` with no CA argument, so it uses gnutls's system trust and runs gnutls's real chain verifier. |
| java | **path** | PKIX `CertPathBuilder` over the default JSSE trust store. It applies `blocked.certs` and `disabledAlgorithms`. Its error message hides expiry ("unable to find valid certification path"), so the positives and NEGCONTROL are what catch a stale chain. |
| go | **path** | `x509.Certificate.Verify` with the system pool, which is exactly what `crypto/tls` uses. That includes Go's distrusted-SPKI list. The probe decides on the error type: only `UnknownAuthorityError`, or `NoValidChains` with an empty detail (go1.27.3 returns that only when the distrusted-SPKI list dropped every chain), counts as REJECTED. EKU, policy, name-constraint and expiry failures are ERR. |
| python-urllib | store | Python has no chain-verify API, and a handshake needs a private key we don't have. This row feeds `ssl.get_default_verify_paths()` to `openssl verify -x509_strict -partial_chain`, the 3.13+ default-context flags. Python links that same libssl. |
| pip | store | Same, over the union of the system paths (truststore) and pip's vendored certifi. pip 24.2+ trusts both. |
| httpie | store | Same, over the union of the system paths and requests' bundle. httpie 3.2.x calls `load_default_certs()` (`ensure_default_certs_loaded`) before requests adds certifi. A certifi-only model read FIXED at the pre-fix pin while live connected to all 12 hosts. |
| node, node-sysca | anchor | Checks whether `tls.getCACertificates('default')` (bundled, plus system under `--use-system-ca`) contains a cert that anchors the chain, with links checked by `X509Certificate.checkIssued` and `verify`. There is no time check, and any store member counts as an anchor, so this can only err toward VULNERABLE. |
| bun | anchor + store | The same walk over bun's compiled-in list, unioned with `openssl verify` over the system paths. At the pre-fix pin bun connected to the AAA hosts, and AAA is in no compiled-in list. |
| deno | anchor | The same walk. Deno's `node:tls` list matched live at both pins. |
| curl, wget, git | N/A (live-only) | These clients verify only inside a handshake. The store they read is the one the openssl row checks. |
| deno-sysstore | N/A (live-only) | `node:tls` does not reflect `DENO_TLS_CA_STORE`. |
| uv, uv-system-certs | N/A (live-only) | rustls verifies only inside a handshake, and the webpki roots are compiled in (`pkgmgr truststores` inventories them). |

At the pre-fix pin, the offline cells matched the live cells for every row that has both,
in both target groups. That is the bar for adding an offline probe: if offline disagrees
with live at the baseline, the probe is wrong, and the row is N/A until it is fixed.

### Blocklist rows (opt-in per incident)

`go-blocklist`, `node-blocklist`, `java-blocklist` and `uv-blocklist` run with the
anchors **trusted**: `SSL_CERT_FILE` set to bundle+anchors for Go and uv,
`NODE_EXTRA_CA_CERTS` set to the anchors for node, and explicit trust anchors for Java.
With the anchors trusted, a FIXED can only come from the client's own blocklist. Those
blocklists are Go's distrusted SPKIs, node's `kBlockedSPKIs`, the JDK's `blocked.certs`
and rustls-webpki's list. A row runs only if `expected.txt` names it in `blocklist_rows`.
A client with no blocklist for a given incident would otherwise read VULNERABLE forever.
node's and uv's blocklists fire only inside a handshake, so those rows are live-only.
Java's has no live row, because that would need a keystore built with keytool, and
offline already runs the same PKIX code.

## Incident playbook

1. **Add an incident directory.** Copy `incidents/cve-2026-111943/` to
   `incidents/<id>/` and fill it in:
   - `targets.txt` lists the hosts that must be refused, one per line, as `<host> <group>
     <label>`. Each group becomes a table column.
   - `positives.txt` lists two or more hosts that must connect, on unrelated long-lived
     roots.
   - `chains/bad/<host>.pem` is each target's served chain, leaf first. Take it from the
     disclosure, or from `openssl s_client -showcerts`. Public certs only, never keys.
   - `chains/good/<host>.pem` is each positive's chain.
   - `chains/anchors.pem` holds the distrusted roots. Check their fingerprints against
     `packages/ca-certificates/distrust.txt`.
   - Run `shasum -a 256` over the PEMs to write `chains/SHA256SUMS`, and cite the source
     in `chains/README.md`.
   - In `expected.txt`, set `verify_at` to an instant inside every chain's validity,
     `blocklist_rows` to the rows that apply, and the expected failure class.
2. **Baseline at a pre-fix pin.** It must read VULNERABLE. Set `locked_commit` to a pkgs
   commit from before any fix, then run all six tasks. Expect VULNERABLE rows (exit 2),
   SELFTEST FIXED and NEGCONTROL VULNERABLE. A row that reads FIXED at the baseline is not
   being tested by this incident. Find out why before trusting it later. Save the output.
3. **Per PR.** Point `[upstream]` at the PR head and run the tasks it affects:
   ```toml
   [upstream]
   repo = "https://github.com/gominimal/pkgs"     # a fork PR: the fork's URL
   branch = "<pr-branch>"
   locked_commit = "<pr head sha>"
   ```
   `min task run live -C "$X" --no-input --only '^uv'` on pkgs#967's head
   (`uv-0.13.4-webpki-lock`) gave uv 0.13.4, FIXED on all three uv rows. Packages the
   PR's CI hasn't built yet get built on first use, so a toolchain bump means a long
   first run. As an alternative, `min session activate` a worktree of the PR and run
   `bash run.sh ...` in it with `min session exec`. Use a fresh session name each time,
   because activate snapshots the tree.
4. **After merge.** Run `min update` in the scratch copy to re-pin to main, then run all
   six tasks. Every row must read FIXED, or N/A with the reason above. Exit must be 0.
5. **Weekly regression.** Run `min update`, then all six tasks, for every directory under
   `incidents/`. Any non-zero exit needs a human. Exit 3 most often means a chain has
   gone stale (NEGCONTROL BROKEN), and the fix is to re-capture it.

## Who runs it, and who owns a failure

**Phase 1 (now): a manual playbook.** Nothing runs this on a schedule yet, and it is not
a CI check. Whoever drives an incident runs it, following the playbook above: baseline,
per PR, after merge. Run it too on any PR that changes a trust store or a TLS client
(`ca-certificates`, a runtime that bundles its own roots, a Rust crate lock that pins
webpki). That person owns the result and posts the table on the PR.

**Phase 2: a weekly scheduled run.** `min update`, then all six tasks for every directory
under `incidents/`, retrying once on exit 125. A non-zero exit posts to **#pkgmgr-mgr**
(Slack channel `C0B1J3S34SV`). That is the channel the pkgmgr runner's failure backstop
posts to, so the same pkgsec on-call that watches the nightly runs owns it. Tracked with
the weekly `pkgmgr truststores` scan (gominimal/pkgmgr-rs#1021). Until it exists, there
is no alert, only the manual runs.

## Maintenance

- **Six tasks.** The package lists are split three ways because some packages install
  the same paths (see "Why six tasks"). When you add a client, add its package to every
  task whose rows should see it, and keep `live-*` and `offline-*` identical apart from
  `--mode`. Adding a jdk or node flavour means a new task pair, not another entry in an
  existing one.
- **The pin.** `[upstream] locked_commit` is what gets tested, never the checkout this
  file sits in. Today it pins the pkgs main commit the last full run was verified at. To
  test current main, run `min update` (in a scratch copy, see "Running it") and commit
  the new pin with the run's results. To test a PR, point `[upstream]` at its head (step
  3 of the playbook). Don't commit a PR-head pin.
- **Chain expiry.** Offline verifies at `verify_at`, so captured chains never go stale
  there. Live mode handshakes with the real targets, though, and their leaves expire:
  for cve-2026-111943, all 12 on 2027-05-03. On that day NEGCONTROL reads BROKEN and
  every live run exits 3. run.sh prints the earliest target leaf expiry in its header,
  warns from 60 days before (`EXPIRY_WARN_DAYS` overrides), and puts it in the JSON as
  `earliest_target_leaf_expiry`. Before it passes, re-capture `chains/bad/` from the
  targets (if the disclosure re-issued them) and move `verify_at`. Otherwise retire the
  incident's live tasks and keep offline.
- **The targets are someone else's hosts.** `*.we-have-a-problem.com` are the
  disclosure's demonstration sites. If they go away, NEGCONTROL reads BROKEN in live
  mode, and offline keeps working from `chains/`. The positives (`letsencrypt.org`,
  `www.google.com`) rotate their own certs, so live mode needs no upkeep for them.
- **Exit 125.** run.sh never exits 125. If `min task run` returns 125 with the output
  cut off mid-run, min dropped the task's output stream, and the fix is to rerun.
  During development this hit 3 of about 20 streamed `live` runs. When run.sh ran 6
  times back to back inside a single task, with its output going to files, there were 0
  failures in 6. The scheduled run retries once on 125.

## Security

- Only the hosts in `targets.txt` and `positives.txt` are contacted, and only in `live`
  mode. `offline` opens no sockets. Host names are validated before use.
- There are no secrets and no private keys. `chains/` holds public CA and leaf
  certificates only, pinned by `SHA256SUMS`, with the source cited in `chains/README.md`.
- Nothing is piped from the network into a shell. The Go and Java probes are compiled
  from this directory inside the box, with `GOPROXY=off` and no module downloads.
- All scratch files live under one `mktemp -d`, which is removed on exit. `HOME` and the
  XDG dirs point inside it, so clients write no config or cache anywhere else.

# chromium-headless-shell-bin

Prebuilt Chromium headless-shell binary — the stripped headless build
that Playwright's `chromium.launch()` and Puppeteer drive in default
headless mode. Both arches come from Chrome for Testing **Stable**
(`chrome-headless-shell-linux64.zip` / `chrome-headless-shell-linux-arm64.zip`).
Unlike CfT's full `chrome` bundle, headless-shell ships no Widevine and is
licensed BSD-3-Clause, so it is redistributable (see `build.ncl`).

This is the tree's only Chromium today. The full-browser package,
`chromium-bin`, was pulled: it was stuck at 156 because
ungoogled-chromium-portablelinux had not released 157. It can come back
when a good full-browser source exists. headless-shell has no headed
mode and no extension support.

Provides:

- `/bin/chromium-headless-shell` — headless-shell binary
- `/usr/share/playwright-browsers/chromium_headless_shell-<rev>/...` —
  Playwright's registry layout

## Using with Playwright / Puppeteer

For Puppeteer-based consumers (e.g. mermaid-cli), use Puppeteer's
`headless: "shell"` mode and:

```sh
export PUPPETEER_EXECUTABLE_PATH=/bin/chromium-headless-shell
```

For Playwright there are two routes:

- `PLAYWRIGHT_BROWSERS_PATH=/usr/share/playwright-browsers` (drop-in). The
  directory key is `revision` in `build.ncl` (currently **1243**); a
  playwright-core version that expects a different revision looks for a
  different directory, so use the second route.
- `launchOptions: { executablePath: '/bin/chromium-headless-shell' }`, which
  bypasses Playwright's registry lookup and works under revision drift.

## Sandbox

Chromium uses the user-namespace sandbox where the kernel allows
unprivileged user namespaces; inside containers that don't, pass
`--no-sandbox`.

## Trust store (CVE-2026-111943)

Chromium on Linux verifies TLS only against its compiled-in Chrome Root
Store, not `/etc/ssl/certs`, and headless-shell reads no enterprise policy.
At 157.0.8103.38 its built-in blocklist refuses the 8 compromised eMudhra
intermediate keys, but the root store (v42) still trusts emSign ECC Root
CA - G3; root store v43, which removes it, ships in Chrome 158. Details in
`build.ncl`.

# chromium-headless-shell-bin

Prebuilt Chromium headless-shell binary — the stripped headless build
that Playwright's `chromium.launch()` and Puppeteer drive in default
headless mode. amd64 comes from Google's Chrome for Testing bucket;
arm64 comes from Playwright's own arm64 build hosted on Microsoft's
CDN (Google does not publish arm64 under CfT).

Sibling package: [`chromium-bin`](../chromium-bin/) ships the full
headed Chromium browser. Each pkg fetches and installs only its own
zip, so consumers that need only one variant don't pay for both.

Provides:

- `/bin/chromium-headless-shell` — headless-shell binary
- `/usr/share/playwright-browsers/chromium_headless_shell-<rev>/...` —
  Playwright's registry layout, shared with `chromium-bin`

## Using with Playwright / Puppeteer

For Puppeteer-based consumers (e.g. mermaid-cli):

```sh
export PUPPETEER_EXECUTABLE_PATH=/bin/chromium-headless-shell
```

For Playwright, see the two routes documented in
[`chromium-bin/README.md`](../chromium-bin/README.md): either set
`PLAYWRIGHT_BROWSERS_PATH=/usr/share/playwright-browsers` (drop-in,
requires revision match), or pass `launchOptions.executablePath:
'/bin/chromium-headless-shell'` (works under revision drift).

The revision shipped here is kept lockstep with `chromium-bin`
(currently **1217 ↔ Chrome 147.0.7727.15 ↔ playwright-core ^1.58.0**).

# chromium-bin

Prebuilt full Chrome browser binary, used in headed mode (or headless via
`--headless=new`). Both arches come from **Chrome for Testing (CfT)
Stable** — the `chrome` bundle for `linux64` and `linux-arm64`, at the same
version as [`chromium-headless-shell-bin`](../chromium-headless-shell-bin/).

## Licensing

CfT's `chrome` bundle is Google's branded **Google Chrome for Testing**
build: it ships with no BSD license grant (its `ABOUT` reads "All rights
reserved" and points at the Chrome Terms of Service). It also bundles the
proprietary Widevine CDM (`libwidevinecdm.so`, "not open source software",
no distribution without a separate agreement with Google).

- `build.sh` **deletes the Widevine CDM** and fails the build if any
  Widevine file survives. Chrome runs without it; only DRM (EME) media
  playback is lost.
- `license_spdx` is `LicenseRef-Google-Chrome-for-Testing-ToS`, not
  `BSD-3-Clause`.
- The package is **not served from the public binary cache**: installing it
  fetches the zip from Google's CfT bucket and unpacks it locally.

The headless shell (`chromium-headless-shell-bin`) and chromedriver are
different: their CfT zips carry the Chromium BSD-3-Clause grant and no
Widevine, so they are cache-served as usual.

Sibling package: [`chromium-headless-shell-bin`](../chromium-headless-shell-bin/)
ships the stripped headless-shell variant used by Playwright/Puppeteer
in default headless mode. Each pkg fetches and installs only its own
zip, so consumers that need only one variant don't pay for both.

Provides:

- `/bin/chromium` — full browser
- `/usr/share/playwright-browsers/chromium-<rev>/chrome-linux64/chrome`
  (amd64) or `.../chrome-linux-arm64/chrome` (arm64, plus a `chrome-linux`
  compat symlink) — Playwright's registry layout, shared with
  `chromium-headless-shell-bin`

## Using with Playwright

There are two routes — pick whichever matches how the project consumes
Playwright.

### Route A: `PLAYWRIGHT_BROWSERS_PATH` (drop-in, revision must match)

Install both `chromium-bin` and `chromium-headless-shell-bin` (or just
the one variant your tests actually need), then:

```sh
export PLAYWRIGHT_BROWSERS_PATH=/usr/share/playwright-browsers
npx playwright test
```

This works for both `playwright-core` and `@playwright/test`. The two
pkgs share the `playwright-browsers` directory and Playwright's
registry walks it for `chromium{,_headless_shell}-<rev>/`. The directory
key shipped here is **revision 1243 (playwright-core 1.63.x)**; the
browser inside is the current CfT Stable, not the Chrome 153 that
playwright-core 1.63 was rolled against. CfT's zip layout is exactly what
playwright-core ≥ 1.63 expects on both arches. A different playwright-core
version looks for a different `chromium-<rev>` directory, and there is no
`*_EXECUTABLE_PATH` env override for browsers — use Route B.

### Route B: `executablePath` (works regardless of revision)

Pass the binary explicitly. This bypasses Playwright's registry lookup
entirely, so revision drift doesn't matter:

```js
// playwright-core
import { chromium } from 'playwright-core';
const browser = await chromium.launch({
  executablePath: '/bin/chromium', // headed; or '/bin/chromium-headless-shell' from the sibling pkg
});
```

```js
// playwright.config.{ts,mjs} — for @playwright/test
export default {
  use: {
    launchOptions: { executablePath: '/bin/chromium' },
  },
};
```

## Selenium / chromedriver

ChromeDriver is version-locked to the browser major. `chromedriver-bin`
pins the same CfT Stable version as `chromium-headless-shell-bin`, and this
package moves in lockstep with that one, so the same driver works with
`/bin/chromium` (set Selenium's browser binary / `SE_BROWSER_PATH` to it).

## Why prebuilt?

Building Chromium from source requires depot_tools, a hermetic clang
toolchain, a ~30 GB git checkout, and 4–8 hours of build time — none
of which is packaged in pkgs today. The bare `chromium` name is
intentionally left available for a future source-built package.

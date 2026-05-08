# chromium-bin

Prebuilt full Chromium browser binary, used in headed mode. amd64 comes
from Google's Chrome for Testing bucket; arm64 comes from Playwright's
own arm64 build hosted on Microsoft's CDN (Google does not publish
arm64 under CfT).

Sibling package: [`chromium-headless-shell-bin`](../chromium-headless-shell-bin/)
ships the stripped headless-shell variant used by Playwright/Puppeteer
in default headless mode. Each pkg fetches and installs only its own
zip, so consumers that need only one variant don't pay for both.

Provides:

- `/bin/chromium` — full browser
- `/usr/share/playwright-browsers/chromium-<rev>/...` — Playwright's
  registry layout, shared with `chromium-headless-shell-bin`

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
registry walks it for `chromium{,_headless_shell}-<rev>/`. The
revision shipped here (currently **1217 ↔ Chrome 147.0.7727.15 ↔
playwright-core ^1.58.0**) must match the installed `playwright-core`
version — there is no `*_EXECUTABLE_PATH` env override for browsers,
so revision drift can't be papered over with env vars alone.

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
    launchOptions: { executablePath: '/bin/chromium-headless-shell' },
  },
};
```

## Why prebuilt?

Building Chromium from source requires depot_tools, a hermetic clang
toolchain, a ~30 GB git checkout, and 4–8 hours of build time — none
of which is packaged in pkgs today. The bare `chromium` name is
intentionally left available for a future source-built package.

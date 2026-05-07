# chromium-bin

Prebuilt Chromium browser binaries. amd64 comes from Google's Chrome for
Testing bucket; arm64 comes from Playwright's own arm64 build hosted on
Microsoft's CDN (Google does not publish arm64 under CfT).

Ships two binaries:

- `/bin/chromium` — full browser, used for headed mode
- `/bin/chromium-headless-shell` — stripped headless build, used by
  `chromium.launch()` in default headless mode

Files are also laid out under `/usr/share/chromium-bin/` in Playwright's
registry layout (`chromium-<rev>/` and `chromium_headless_shell-<rev>/`),
which makes the package usable as a drop-in browser source for Playwright.

## Using with Playwright

There are two routes — pick whichever matches how the project consumes
Playwright.

### Route A: `PLAYWRIGHT_BROWSERS_PATH` (drop-in, revision must match)

If the project's installed `playwright-core` revision matches the revision
shipped here (currently **1217 ↔ Chrome 147.0.7727.15 ↔ playwright-core
^1.58.0**), point Playwright at the on-disk layout and you're done — no
launch options, no `npx playwright install`, no browser cache:

```sh
export PLAYWRIGHT_BROWSERS_PATH=/usr/share/chromium-bin
npx playwright test
```

This works for both `playwright-core` and `@playwright/test`. Playwright's
registry walks `$PLAYWRIGHT_BROWSERS_PATH/chromium{,_headless_shell}-<rev>/`
with `<rev>` hardcoded by the installed `playwright-core` version — so if
your `playwright-core` is on a different revision than chromium-bin ships,
Playwright will not find the binary and Route B is required.

### Route B: `executablePath` (works regardless of revision)

Pass the binary explicitly. This bypasses Playwright's registry lookup
entirely, so revision drift doesn't matter:

```js
// playwright-core
import { chromium } from 'playwright-core';
const browser = await chromium.launch({
  executablePath: '/bin/chromium-headless-shell', // or '/bin/chromium' for headed
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
toolchain, a ~30 GB git checkout, and 4–8 hours of build time — none of
which is packaged in pkgs today. The bare `chromium` name is intentionally
left available for a future source-built package.

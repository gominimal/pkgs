# chromium-bin

Prebuilt full Chromium browser, used in headed mode (or headless via
`--headless`). Both arches come from
[ungoogled-chromium-portablelinux](https://github.com/ungoogled-software/ungoogled-chromium-portablelinux)
release tarballs: a Stable-branch Chromium build with the ungoogled-chromium
patch set, published for x86_64 and arm64 for every Stable point release.

This is an **interim** source (2026-10-20). It gets the package back onto
Chromium Stable on both arches; it is not meant to be the long-term answer
(see gominimal/pkgmgr-rs#681 for the source-build path).

Sibling package: [`chromium-headless-shell-bin`](../chromium-headless-shell-bin/)
ships the stripped headless-shell variant used by Playwright/Puppeteer
in default headless mode. Each pkg fetches and installs only its own
artifact, so consumers that need only one variant don't pay for both.

Provides:

- `/bin/chromium` — full browser
- `/usr/share/playwright-browsers/chromium-<rev>/chrome-linux64/` (amd64) or
  `.../chrome-linux-arm64/` (arm64, plus a `chrome-linux` compat symlink) —
  Playwright's registry layout, shared with `chromium-headless-shell-bin`.
  The browser directory also carries the matching `chromedriver` (same
  version as the browser; not on `PATH`).

## What differs from stock Chromium

ungoogled-chromium removes Google service integration. For users of this
package that means:

- **No Chrome Web Store installs.** Installing an extension from the Web
  Store does not work. Unpacked extensions loaded with
  `--load-extension=<dir>` do.
- **No Safe Browsing**, **no Google sign-in / sync**, no Google API keys.
- **No Widevine**, so no DRM (EME) media playback.

Everything a test runner or automation tool uses (DevTools protocol,
headless mode, `--dump-dom`, screenshots, chromedriver) works as in
Chromium.

## Licensing

BSD-3-Clause (ungoogled-chromium) over Chromium's own BSD-3-Clause and the
third-party licenses listed at `chrome://credits`. Redistributable, so it
is served from the binary cache like any other package. It is built with
proprietary codecs enabled (H.264/AAC decoders in the bundled ffmpeg), as
other redistributed Chromium binaries are; patent licensing for those
codecs is a separate question from copyright.

## Using with Playwright

There are two routes. Pick whichever matches how the project consumes
Playwright.

### Route A: `PLAYWRIGHT_BROWSERS_PATH` (drop-in, revision must match)

Install both `chromium-bin` and `chromium-headless-shell-bin` (or just
the one variant your tests actually need), then:

```sh
export PLAYWRIGHT_BROWSERS_PATH=/usr/share/playwright-browsers
npx playwright test
```

The two pkgs share the `playwright-browsers` directory and Playwright's
registry walks it for `chromium{,_headless_shell}-<rev>/`. The directory
key shipped here is **revision 1243 (playwright-core 1.63.x)**. The browser
inside is the current Chromium Stable, not the Chrome 153 that
playwright-core 1.63 was rolled against. A different playwright-core
version looks for a different `chromium-<rev>` directory, and there is no
`*_EXECUTABLE_PATH` env override for browsers, so use Route B.

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

## Sandbox

The tarball has no setuid `chrome-sandbox` helper (and a package could not
install one setuid anyway). Chromium uses the user-namespace sandbox where
the kernel allows unprivileged user namespaces; inside containers that
don't, pass `--no-sandbox`, as before.

## Why prebuilt?

Building Chromium from source requires depot_tools, a hermetic clang
toolchain, a ~30 GB git checkout, and 4–8 hours of build time — none
of which is packaged in pkgs today. The bare `chromium` name is
intentionally left available for a future source-built package.

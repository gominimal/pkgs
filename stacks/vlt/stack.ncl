let { stack, .. } = import "minimal.ncl" in
# Build a JavaScript project with the vlt package manager (vlt.io), the same way
# the pnpm / npm / bun stacks do for theirs. Selected by vlt's lockfile or config.
#
#   vlt install --frozen-lockfile   fails if vlt-lock.json is out of sync with
#                                   package.json (pnpm's --frozen-lockfile, npm ci)
#   vlt build                       runs dependencies' lifecycle scripts and links
#                                   bins; vlt keeps this a separate, idempotent step
#   vlr build                       the project's own `build` script, if it has one
#                                   (`--if-present` only applies across workspaces)
#
# Environment, set on every vlt command (verified with vlt 1.3.6 in a package build):
#   VLT_TELEMETRY=0     vlt sends anonymized usage events to PostHog by default;
#                       a hermetic build must not phone home.
#   VLT_REGISTRIES      vlt has NO default `npm` registry alias (`gh` and `jsr`
#                       have one), and every command, including a frozen install
#                       from an existing lockfile and `vlt build`, fails with
#                       "Missing registry configuration" without it. Set only when
#                       the project's vlt.json does not define its own `npm` alias,
#                       so a project pinned to a private registry keeps it.
#
# The `vlt` package declares needs { dns, internet }, so a build using this stack
# can reach the registry, as with pnpm.
stack {
  name = "vlt",

  runtime_packages = ["node-lts"],
  build_packages = ["vlt", "base"],

  build_cmds_cmd = [
    "/bin/bash",
    "-c",
    m%"
    env='/usr/bin/env VLT_TELEMETRY=0'
    grep -qs '"npm"' vlt.json || env="$env VLT_REGISTRIES=npm=https://registry.npmjs.org/"
    [ -f vlt-lock.json ] && echo "$env /bin/vlt install --frozen-lockfile" || echo "$env /bin/vlt install"
    echo "$env /bin/vlt build"
    grep -q '"build"[[:space:]]*:' package.json 2>/dev/null && echo "$env /bin/vlr build" || true
  "%
  ],

  matches_project_if_any = [
    {
      file_regexes = {
        "vlt-lock.json" = "*",
      },
    },
    {
      file_regexes = {
        "vlt.json" = "*",
      },
    }
  ],
  matches_project_priority = 10, # Higher than npm, like pnpm
}

let { BuildSpec, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let claude-code = import "../claude-code/build.ncl" in
let claude-code-minimal-plugin = import "../claude-code-minimal-plugin/build.ncl" in

# A metapackage: `min add --session claude` gets the agent *and* the Minimal
# session plugin, which is the combination you almost always want in a sandbox.
# It builds nothing and owns no files; the two deps below are its entire
# content.
#
# `claude-code-minimal-plugin` already depends on `claude-code`, so naming both
# here is redundant today. It is deliberate: this package's meaning should not
# be hostage to the plugin's internal dependency choices.
{
  name = "claude",
  build_deps = [],
  runtime_deps = [
    claude-code,
    claude-code-minimal-plugin,
  ],
  cmd = "",
  outputs = {},

  tests = {
    # The whole point of the package is that both halves arrive together, so
    # assert exactly that: the launcher, and the plugin tree its wrapper looks
    # for at /usr/share/claude/plugins/minimal.
    both_halves_present =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "set -e; test -x /usr/bin/claude; test -f /usr/share/claude/plugins/minimal/.claude-plugin/plugin.json"],
        ],
      } | Test,
  },
} | BuildSpec

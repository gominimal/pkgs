let { Attrs, BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let claude-code = import "../claude-code/build.ncl" in

{
  name = "claude-code-minimal-plugin",

  build_deps = [
    { file = "build.sh" } | Local,
    { file = "session-primer.sh" } | Local,
    { file = "min-session.md" } | Local,
    base,
  ],

  # The plugin is only meaningful alongside claude-code, whose /usr/bin/claude
  # wrapper picks up /usr/share/claude/plugins/minimal when it exists. The
  # dependency points this way only — claude-code does not depend on us.
  runtime_deps = [claude-code],

  cmd = "./build.sh",

  outputs = {
    plugin = { glob = "usr/share/claude/plugins/minimal/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      license_spdx = "Apache-2.0",
    } | Attrs,
} | BuildSpec

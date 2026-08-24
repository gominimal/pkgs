let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let claude-code = import "../claude-code/build.ncl" in
let jq = import "../jq/build.ncl" in

let version = "0.3.0" in
{
  name = "claude-code-minimal-plugin",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/gominimal/minimal-skills/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "2d53812d0f4c3a04c466bb9f0f06eef1b7ab3c13127835e19e2d06f46341f19c",
      extract = true,
      # GitHub drops the leading `v` from the tag when naming the archive's
      # top-level directory, so this is the bare version, not the tag.
      strip_prefix = "minimal-skills-%{version}",
    } | Source,
    base,
  ],

  # The plugin is only meaningful alongside claude-code, whose /usr/bin/claude
  # wrapper picks up /usr/share/claude/plugins/minimal when it exists. The
  # dependency points this way only — claude-code does not depend on us.
  runtime_deps = [claude-code],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    plugin = { glob = "usr/share/claude/plugins/minimal/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "gominimal",
        repo = "minimal-skills",
      },
    } | Attrs,

  tests = {
    layout_check =
      {
        class = 'Standalone,
        test_deps = [base, jq],
        cmds = [
          # The assembled plugin tree: manifest, hooks wiring, both hook
          # scripts executable, and the in-sandbox skill. Host-facing skills
          # must NOT be shipped. The hook assertions are structural — a
          # substring match would still pass if an event invoked the wrong
          # script.
          ["/bin/bash", "-c", "set -e; d=/usr/share/claude/plugins/minimal; test -f $d/.claude-plugin/plugin.json; grep -q '\"name\": \"minimal\"' $d/.claude-plugin/plugin.json; grep -q '\"version\": \"%{version}\"' $d/.claude-plugin/plugin.json; test -f $d/hooks/hooks.json; jq -e '.hooks.SessionStart[].hooks[] | select(.command == \"${CLAUDE_PLUGIN_ROOT}/hooks/session-primer.sh\")' $d/hooks/hooks.json >/dev/null; jq -e '.hooks.PostToolUse[] | select(.matcher == \"Bash\") | .hooks[] | select(.command == \"${CLAUDE_PLUGIN_ROOT}/hooks/denial-triage.sh\")' $d/hooks/hooks.json >/dev/null; test -x $d/hooks/session-primer.sh; test -x $d/hooks/denial-triage.sh; grep -q 'name: minimal-sandbox' $d/skills/minimal-sandbox/SKILL.md; test ! -e $d/skills/minimal-setup"],
        ],
      } | Test,
  },
} | BuildSpec

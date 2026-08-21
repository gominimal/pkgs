let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let claude-code = import "../claude-code/build.ncl" in

let version = "0.3.0" in
# Pinned to the head commit of gominimal/minimal-skills#3. Flip the url to
# archive/refs/tags/v%{version}.tar.gz (and drop this pin) once v0.3.0 is
# tagged upstream.
let commit = "1991c9a75290c20afdf2c279e9465681e064d0b2" in
{
  name = "claude-code-minimal-plugin",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/gominimal/minimal-skills/archive/%{commit}.tar.gz",
      sha256 = "3d3589d0332a9b443d28e9b8af6316c98f98e40854080de345aa24774cd3f061",
      extract = true,
      strip_prefix = "minimal-skills-%{commit}",
    } | Source,
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
        test_deps = [base],
        cmds = [
          # The assembled plugin tree: manifest, hooks wiring, both hook
          # scripts executable, and the in-sandbox skill. Host-facing skills
          # must NOT be shipped.
          ["/bin/bash", "-c", "set -e; d=/usr/share/claude/plugins/minimal; test -f $d/.claude-plugin/plugin.json; grep -q '\"name\": \"minimal\"' $d/.claude-plugin/plugin.json; test -f $d/hooks/hooks.json; grep -q denial-triage $d/hooks/hooks.json; test -x $d/hooks/session-primer.sh; test -x $d/hooks/denial-triage.sh; grep -q 'name: minimal-sandbox' $d/skills/minimal-sandbox/SKILL.md; test ! -e $d/skills/minimal-setup"],
        ],
      } | Test,
  },
} | BuildSpec

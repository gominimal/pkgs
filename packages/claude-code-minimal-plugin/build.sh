#!/bin/bash
set -euo pipefail

plugin_dir="$OUTPUT_DIR/usr/share/claude/plugins/minimal"

mkdir -pv "$plugin_dir/.claude-plugin" "$plugin_dir/hooks" "$plugin_dir/skills"

# The manifest comes from upstream, so the plugin version tracks the fetched
# minimal-skills snapshot by construction. Guard against that snapshot and the
# version this package declares drifting apart when the pin is moved.
cp -v .claude-plugin/plugin.json "$plugin_dir/.claude-plugin/plugin.json"

if ! grep -Eq "\"version\"[[:space:]]*:[[:space:]]*\"$MINIMAL_ARG_VERSION\"" \
  "$plugin_dir/.claude-plugin/plugin.json"; then
  echo "error: upstream plugin.json version does not match the declared version $MINIMAL_ARG_VERSION" >&2
  exit 1
fi

# In-sandbox guidance only. The other skills in the repo are host-facing and
# teach commands that do not exist inside a sandbox (min session, min init,
# min bug, mip ...), so they are deliberately not shipped here.
cp -Rv skills/minimal-sandbox "$plugin_dir/skills/minimal-sandbox"

# Hook assets live under sandbox/ upstream so a marketplace install of the
# repo never picks them up; in this build they become the plugin's hooks/.
cp -v sandbox/hooks.json "$plugin_dir/hooks/hooks.json"
cp -v sandbox/session-primer.sh "$plugin_dir/hooks/session-primer.sh"
cp -v sandbox/denial-triage.sh "$plugin_dir/hooks/denial-triage.sh"
chmod -v +x "$plugin_dir/hooks/session-primer.sh" "$plugin_dir/hooks/denial-triage.sh"

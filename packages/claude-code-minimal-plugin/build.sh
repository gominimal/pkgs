#!/bin/bash
set -euo pipefail

plugin_dir="$OUTPUT_DIR/usr/share/claude/plugins/minimal"

mkdir -pv "$plugin_dir/.claude-plugin" "$plugin_dir/hooks" "$plugin_dir/skills/min-session"

cat > "$plugin_dir/.claude-plugin/plugin.json" << 'EOF'
{
  "name": "minimal",
  "description": "Teaches Claude Code how to use the `min` tool inside a Minimal sandbox session.",
  "version": "1.0.0"
}
EOF

cat > "$plugin_dir/hooks/hooks.json" << 'EOF'
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-primer.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
EOF

cp -v session-primer.sh "$plugin_dir/hooks/session-primer.sh"
chmod -v +x "$plugin_dir/hooks/session-primer.sh"

cp -v min-session.md "$plugin_dir/skills/min-session/SKILL.md"

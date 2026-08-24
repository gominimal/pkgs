#!/bin/bash
# SessionStart hook: tell the agent it is inside a Minimal sandbox and how to
# reach for `min` instead of a system package manager.
#
# Keep this short. It is injected into every session's context. Anything that
# is not needed on every turn belongs in the min-session skill instead.
set -euo pipefail

# Stay silent outside a Minimal session, where the shim is not installed.
[ -x /usr/bin/min ] || exit 0

read -r -d '' context << 'EOF' || true
You are running inside a Minimal sandbox session. The host filesystem is not
mounted, and system package managers (apt, apk, dnf, brew) are unavailable. Do
not attempt to install software with them, and do not install into the system
with pip or npm.

Install tools with the min shim instead:

  min search <term>               find a package by name
  min add <pkg>...                install for THIS SESSION ONLY (ephemeral)
  min add --build <pkg>...        install and record in build_deps
  min add --runtime <pkg>...      install and record in runtime_deps
  min add --task <task> <pkg>...  install and record against a minimal.toml task
  min run <task>                  run a minimal.toml task (min build and min test are shorthand)

min add with no flag defaults to --session: the tool works immediately, but
nothing is written to config. If a dependency needs to outlive this session,
pass --build, --runtime, or --task.

Run min with no arguments for this session's authoritative subcommand list. Use
the min-session skill when you need more detail than that.
EOF

# Escape for embedding as a JSON string: backslashes, then quotes, then newlines.
context="${context//\\/\\\\}"
context="${context//\"/\\\"}"
context="${context//$'\n'/\\n}"

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$context"

#!/bin/sh
set -ex

export GOROOT=/usr/go

go build -trimpath -ldflags "-buildid= -w -s -X 'github.com/cli/cli/v2/internal/build.Version=${MINIMAL_ARG_VERSION}'" -o gh ./cmd/gh

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 gh $OUTPUT_DIR/usr/bin/gh

# --- shell completions (gominimal/inbox#470) ------------------------------
#
# gh takes the shell as a FLAG, not a positional: `gh completion -s <shell>`.
#
#   MEASURED TRAP at v2.96.0: `gh completion zsh` exits 0, prints nothing to
#   stderr, and emits BASH — a 15913-byte bash script. pkg/cmd/completion's
#   RunE never reads `args`, and when --shell is empty and stdout is not a TTY
#   it defaults to bash. So the positional is silently discarded and you get a
#   bash script named `_gh`. The content assertions below are the whole point
#   of this block: they are what catches a dropped -s.
#
# gh writes a random UUID to $XDG_STATE_HOME/gh/device-id on first run,
# `completion` included. Pin its state/config dirs inside the build dir so
# nothing lands in $HOME and no UUID can reach the output. The exact-path
# output globs in build.ncl are the second line of defence: a `usr/**`
# catch-all WOULD ship that UUID and break reproducibility.
export GH_NO_UPDATE_NOTIFIER=1
export GH_CONFIG_DIR="$(pwd)/.gh-buildtime-config"
export XDG_STATE_HOME="$(pwd)/.gh-buildtime-state"

./gh completion -s bash > gh.bash
./gh completion -s zsh  > _gh
./gh completion -s fish > gh.fish

# Non-empty: a generator that errors to stdout and exits 0 still yields a file.
[ -s gh.bash ]
[ -s _gh ]
[ -s gh.fish ]

# Content is genuinely for that shell. These fail loudly if the -s is ever
# dropped, which is the failure this block exists to prevent.
head -1 _gh | grep -qx '#compdef gh'
grep -q 'complete -c' gh.fish
grep -qE 'complete .*(-F|-o) ' gh.bash
# Belt and braces: the bash banner must NOT appear in the zsh or fish files.
! grep -qi 'bash completion' _gh
! grep -qi 'bash completion' gh.fish

install -D -m 0644 gh.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/gh"
install -D -m 0644 gh.fish "$OUTPUT_DIR/usr/share/fish/vendor_completions.d/gh.fish"
install -D -m 0644 _gh     "$OUTPUT_DIR/usr/share/zsh/site-functions/_gh"

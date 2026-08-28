#!/bin/sh
# LOUD GUARD — this must NEVER execute.
#
# hex0 is a hand-auditable seed delivered via trust-config `bootstrap_artifacts`
# and hydrated into this spec's cache slot by the builder's Pass-3. When that
# hydration succeeds the planner treats hex0 as cached and skips this command.
#
# If you are reading this in a build log, Pass-3 did NOT populate the slot:
# the `bootstrap_artifacts` entry whose `applies_to_packages` includes "hex0"
# is missing, mis-named, or its mirrored tarball failed the sha256 gate.
# FAIL LOUDLY rather than ship an empty / un-pinned seed.
set -e
echo "FATAL: hex0 cache slot was not hydrated by builder Pass-3." >&2
echo "  - trust-config.json must carry a bootstrap_artifacts entry whose" >&2
echo "    applies_to_packages includes 'hex0'." >&2
echo "  - its tarball must be mirrored to an allowlisted bucket and its" >&2
echo "    sha256 (of the COMPRESSED tarball) must match the entry." >&2
echo "  See B1 runbook section 2 (seed staging + trust-config edit)." >&2
exit 1

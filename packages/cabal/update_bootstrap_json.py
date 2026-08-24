#!/usr/bin/env python3
import sys
import json
import subprocess

# Read existing JSON template
with open(sys.argv[1]) as f:
    data = json.load(f)

# Query actual package versions from GHC
pkg_list_str = subprocess.check_output(['ghc-pkg', 'list', '--simple-output'], text=True)
actual_pkgs = {}
for item in pkg_list_str.strip().split():
    if '-' in item:
        # Split on the last hyphen to handle packages like template-haskell
        parts = item.rsplit('-', 1)
        if len(parts) == 2:
            actual_pkgs[parts[0]] = parts[1]

# Update the builtin list
new_builtin = []
for entry in data.get('builtin', []):
    name = entry['package']
    if name in actual_pkgs:
        new_builtin.append({'package': name, 'version': actual_pkgs[name]})
    else:
        new_builtin.append(entry)

data['builtin'] = new_builtin

# Build-CONFIGURATION overrides only — no version or hash pins.
#
# This block used to pin ~12 packages to specific versions + Hackage hashes,
# because the base plan was cabal's linux-9.8.2.json and its dependencies were
# genuinely too old for the GHC we build with (hence the original comment,
# "too old for GHC 9.10.3").
#
# Since the base plan moved to linux-9.10.3.json (cabal 3.18.1.0), every one of
# those pins became a DOWNGRADE of cabal's own tested set, with stale hashes:
#
#   HTTP              plan 4000.5.0  -> pinned 4000.4.1   <- failed to configure
#   hashable          plan 1.5.1.0   -> pinned 1.4.7.0
#   random            plan 1.3.1     -> pinned 1.2.1.2
#   tar               plan 0.7.1.0   -> pinned 0.6.3.0
#   splitmix          plan 0.1.3.2   -> pinned 0.1.1
#   async, zlib, hackage-security    -> all older than the plan
#
# So the pins are gone: the plan that ships WITH a cabal release is the set
# that cabal release was tested against, and re-deriving it by hand is how it
# drifts. Anything genuinely needed should fail loudly here rather than be
# pre-empted by a guess.
#
# zlib's FLAGS are not a version pin and DO survive: they tell the build to use
# the system zlib rather than the copy bundled in the Haskell package, which is
# a property of our sandbox, not of any zlib version.
dep_updates = {
    'zlib': {
        'flags': ['-bundled-c-zlib', '+non-blocking-ffi', '-pkg-config'],
    },
}
new_deps = []
for dep in data.get('dependencies', []):
    name = dep['package']
    if name in dep_updates:
        new_dep = dict(dep)
        for key, value in dep_updates[name].items():
            new_dep[key] = value
        new_deps.append(new_dep)
    else:
        new_deps.append(dep)

data['dependencies'] = new_deps

# Write back to stdout
json.dump(data, sys.stdout, indent=2)

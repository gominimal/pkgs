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

# Update specific dependencies that are too old for GHC 9.10.3.
# Each entry maps a package name to new version, revision, source hash, and .cabal hash.
# All hashes are from Hackage and verified at packaging time.
dep_updates = {
    'th-compat': {
        'version': '0.1.7',
        'revision': 0,
        'src_sha256': '9e26f12230d38ae56dcf94f8c139799dc3b7376f3434d35ce74847a0a24fd5ff',
        'cabal_sha256': '449be09a4e3f46ea4645700c026624c4b6f066f508187326c284dbdea8884bc9',
    },
    'hashable': {
        'version': '1.4.7.0',
        'revision': 0,
        'src_sha256': '3baee4c9027a08830d148ec524cbc0471de645e1e8426d46780ef2758df0e8da',
        'cabal_sha256': '573f3ab242f75465a0d67ce9d84202650a1606575e6dbd6d31ffcf4767a9a379',
    },
    'async': {
        'version': '2.2.5',
        'revision': 2,
        'src_sha256': '1818473ebab9212afad2ed76297aefde5fae8b5d4404daf36939aece6a8f16f7',
        'cabal_sha256': 'cf9e6afba8e01830ca0d32a12b98d481cf389688762c80d1870a1db2061ebf35',
    },
    'lukko': {
        'version': '0.1.2',
        'revision': 0,
        'src_sha256': '72d86f8aa625b461f4397f737346f78a1700a7ffbff55cf6375c5e18916e986d',
        'cabal_sha256': '8a3004c2de2a0b5ef0634d3da6eae62ba8d8a734bab9ed8c6cfd749e7ca08997',
    },
    'HTTP': {
        'version': '4000.4.1',
        'revision': 6,
        'src_sha256': 'df31d8efec775124dab856d7177ddcba31be9f9e0836ebdab03d94392f2dd453',
        'cabal_sha256': 'ad36c6a1b3bc203b02751c8bffae8a684cc755661a2a567362cd4a0da1193c5e',
    },
    'hackage-security': {
        'version': '0.6.3.2',
        'revision': 0,
        'src_sha256': 'bf8f97868ed5219d0a13a90fcbfad819bbeba4ab368c5cb590b57202c98768f9',
        'cabal_sha256': 'ffb311c0750ff3fa159c101838e48ab79c1ea2a23c29fd5cd8932b208dfedb33',
    },
    'splitmix': {
        'version': '0.1.1',
        'revision': 0,
        'src_sha256': 'd678c41a603a62032cf7e5f8336bb8222c93990e4b59c8b291b7ca26c7eb12c7',
        'cabal_sha256': '8f92088f1c51c8d4569279a07565f8aa6b534a6735615b2295d2961dec8f1783',
    },
    'cryptohash-sha256': {
        'version': '0.11.102.1',
        'revision': 5,
        'src_sha256': '73a7dc7163871a80837495039a099967b11f5c4fe70a118277842f7a713c6bf6',
        'cabal_sha256': 'acb64f2af52d81b0bb92c266f11d43def726a7a7b74a2c23d219e160b54edec7',
    },
    'tar': {
        'version': '0.6.3.0',
        'revision': 0,
        'src_sha256': '50bb660feec8a524416d6934251b996eaa7e39d49ae107ad505ab700d43f6814',
        'cabal_sha256': 'b853b4296cb23386feda17dc0d9065af6709d22d684ec734aab65403d59ed547',
    },
    'random': {
        'version': '1.2.1.2',
        'revision': 0,
        'src_sha256': '790f4dc2d2327c453ff6aac7bf15399fd123d55e927935f68f84b5df42d9a4b4',
        'cabal_sha256': '32397de181e20ccaacf806ec70de9308cf044f089a2be37c936f3f8967bde867',
    },
    'zlib': {
        'version': '0.7.1.0',
        'revision': 0,
        'src_sha256': '6edd38b6b81df8d274952aa85affa6968ae86b2231e1d429ce8bc9083e6a55bc',
        'cabal_sha256': 'd6696f2b55ab4a50b8de57947abca308604eb7cf8287c40bf69cfa26133e24d3',
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

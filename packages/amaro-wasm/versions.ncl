# The amaro (node's built-in TypeScript type stripper) each node line bundles, as ONE value.
#
# node and node-lts read their own entry in `bundled` (their build.sh fails unless
# deps/amaro/package.json is that version), and amaro-wasm builds the swc wasm for every
# distinct version listed there, from that version's tag tarball pinned in `tag_sha256`. So a
# node bump that moves its bundled amaro edits this file (and the shipped-blob pin on that
# node's `splice deps/amaro/dist/index.js` line), and amaro-wasm rebuilds with it in the same
# change. pkgmgr's updater makes those edits: it reads deps/amaro from the new node tarball,
# rewrites the entry, pins the new tag tarball and re-derives the splice pin.
{
  bundled = {
    node = "1.1.11",
    node-lts = "1.1.11",
  },
  # https://github.com/nodejs/amaro/archive/refs/tags/v<version>.tar.gz, one per version
  # `bundled` names (an unlisted one fails evaluation).
  tag_sha256 = {
    "1.1.11" = "f65b4e8ae9ab519e8db1824377eb621d7fce66e21ae1020621d8f54b6ed774fa",
  },
}

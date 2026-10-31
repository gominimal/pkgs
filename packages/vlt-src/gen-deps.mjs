// From vlt-lock.json: the exact versions of every EXTERNAL dependency that a
// runtime (non-dev) edge of the CLI's workspaces (src/*, infra/build) points at.
import { readFileSync, writeFileSync } from 'node:fs'
const lock = JSON.parse(readFileSync('vlt-lock.json', 'utf8'))
const deps = {}, conflicts = {}
for (const [from, to] of Object.entries(lock.edges)) {
  const src = from.split(' ')[0]
  if (!(src.startsWith('workspace~src+') || src === 'workspace~infra+build')) continue
  const [type, , target] = to.split(' ')
  if (!['prod', 'optional', 'peer', 'peerOptional'].includes(type) || !target) continue
  if (target.startsWith('workspace~') || target.startsWith('file~')) continue
  const node = lock.nodes[target]
  if (!node) continue
  const name = node[1]
  const version = target.slice(target.lastIndexOf('@') + 1).split('~')[0] // drop vlt's ~peer.<hash> context suffix
  if (deps[name] && deps[name] !== version) (conflicts[name] ??= new Set([deps[name]])).add(version)
  deps[name] = version
}
delete deps.esbuild // bundling only; not needed to RUN from source (and it is a prebuilt Go binary)
writeFileSync('/tmp/deps/package.json', JSON.stringify({ name: 'vlt-src-deps', private: true, dependencies: deps }, null, 1))
console.log(`external runtime deps: ${Object.keys(deps).length}`)
for (const [n, v] of Object.entries(conflicts)) console.log(`version conflict ${n}: ${[...v].join(' ')}`)

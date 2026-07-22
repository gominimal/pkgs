---
name: min-session
description: How to use the `min` tool inside a Minimal sandbox session — finding and installing packages, persisting a dependency so it outlives the session, running minimal.toml tasks, and validating or building a package. Use whenever a needed CLI tool is missing, a dependency has to be added to a build, or a minimal.toml task needs to run.
---

# Using `min` inside a Minimal session

`/usr/bin/min` is a shell shim that talks to the Minimal daemon over
`/run/minenv_sock`. It is installed by the daemon, not by any package, so its
subcommands track the daemon's version rather than anything in a source tree.

**Run `min` with no arguments to print the authoritative subcommand list for
this session.** If this document and that output disagree, the output is right.

There is a separate, larger `min` CLI on the *host* (`min activate`, `min
attach`, `min destroy`, ...) for managing sessions. Those subcommands do not
exist in here; everything below is the in-session surface.

## Installing tools

Never reach for `apt`, `apk`, `dnf`, `brew`, or a system-wide `pip install` —
they are absent or will not work. Use `min` instead.

```bash
min search ripgrep          # fuzzy name search, prints version and outputs
min add ripgrep             # install into this session
```

Names often differ from what you would type elsewhere: `python` not `python3`,
`node` not `nodejs`, `jdk` not `java`. Search first when unsure.

### Choosing where the dependency is recorded

This is the most common mistake. `min add` takes a flag that decides whether
anything is *persisted*:

| Invocation | Effect |
|---|---|
| `min add <pkg>` | Same as `--session`. Installs now, records nothing. |
| `min add --session <pkg>` | Installs for this session only. Ephemeral. |
| `min add --build <pkg>` | Installs, and records the package in `build_deps`. |
| `min add --runtime <pkg>` | Installs, and records the package in `runtime_deps`. |
| `min add --task <task> <pkg>` | Installs, and records against that `minimal.toml` task. |

If you install a tool with a bare `min add` and then edit a `build.ncl` to
depend on it, the build will still work in your session and fail for everyone
else. Reach for `--build` or `--runtime` when the dependency is real.

Multiple packages can be passed at once: `min add --build gcc make`.

## Running tasks

Tasks are declared in `minimal.toml` at the project root.

```bash
min run <task name>    # run a declared task
min build              # shorthand for: min run build
min test               # shorthand for: min run test
```

**Interactive tasks cannot be launched from inside a session.** Tasks declared
with `interactive = true` — conventionally `shell` and `claude` — only start
from the host. Attempting one in here fails with `cannot run interactive tasks
from within an environment`. That is a structural limit, not a misconfiguration;
do not try to work around it.

## Working on packages

Only relevant inside a packaging repository (one with a `packages/` directory).

```bash
min check                          # lint every package, stack, and profile
min check --packages <name>...     # lint just these packages
min check --stacks <name>...       # lint just these stacks
min check --fix                    # apply the fixes that can be applied automatically
min patched-pkg <name>             # build one package against already-built deps
```

`min patched-pkg` wires dependencies to the most recent locally available build
of each package, so editing a package deep in the graph does not trigger a long
rebuild chain. Use it as the inner loop; `min check` before and after.

Some checks only run against build output, and report as skipped until the
package has been built. Run `min check` again after a successful
`min patched-pkg` to see them.

If `min patched-pkg` reports `resolving dep '<name>' by name: not found`, that
dependency has no local build yet. `min add <name>` fetches it. If the missing
dependency is itself a package you are currently writing, it does not exist
upstream to fetch — build that one with `min patched-pkg` first, then come back.

A packaging repository normally carries an `AGENTS.md` or `CLAUDE.md` at its
root describing its own conventions: how `build.ncl` is structured, which
reproducibility flags each toolchain needs, and how outputs are declared. Read
it before writing a package. This skill covers the tool, not the conventions.

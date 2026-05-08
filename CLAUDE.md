# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# pkgs repository

You are in the packaging repository for the Minimal build system & package manager, containing the
config-as-code declarations for an ecosystem of Linux software packages (like nixpkgs). These
descriptions are fairly precise, describing both the dependencies of the software (in terms of
other packages) as well as the exact steps to build it and what outputs are collected from a build.

You are running in an environment with access to a few specialized tools to help you accomplish your
goals. These tools are all subcommands of the `min` command.
 
 * `min add <package name>` - Installs the package with the given name into your environment, letting you
    use the CLI tools it encapsulates. If you aren't sure of the right package name, you can use
    `min search <term>` to help find it.
 * `min check [--packages] [--profiles] [--harnesses] [--fix] [<name 1>[, <name N>]]` - Runs linters and static checks on the packages/profiles/harnesses with the given names, or all if names are not specified. If none of --profiles, --harnesses, and --packages are set, then checks are run for all three object kinds.
 * `min patched-pkg <package name>` - Runs the build for the named package. Unlike a full build, a patched build will wire dependencies to the most recent available version of the package with the same name, so you won't have long rebuilds when editing packages which are circularly dependent on a lot of other packages.



## General layout

All objects are described using [Nickel](https://nickel-lang.org/) syntax, and objects are roughly located at the path `<object-type>/<name>/<file>.ncl`.

Specifically:

 * Packages: `packages/<package name>/build.ncl`
 * Harnesses: `harnesses/<harness name>/harness.ncl`

The repo-level config lives at `minimal.toml` (declares the minimum `stdlib` version and interactive `tasks` like `min run shell` / `min run claude`).

### Harnesses

A harness describes a reusable build environment for a class of project (e.g. a Go module, a Rust crate, a CMake project). Each harness declares the packages it needs, a default build command, and a set of project-detection rules — `minimal init` uses these rules to auto-select the right harness for a source tree.

Example (`harnesses/go/harness.ncl`):

```ncl
let { harness, .. } = import "minimal.ncl" in
harness {
  name = "go",
  build_packages = ["go", "binutils", "linux_headers"],
  build_cmd = "go build",
  matches_project_if_any = [
    { file_regexes = { "go.mod" = "*", "go.sum" = "*" } },
  ],
}
```

Current harnesses cover: bun, cmake, deno, go, gradle, make, maven, meson, npm, pip, pnpm, pulumi-go, pulumi-nodejs, rust, shell, uv, zig.



## Package declarations

A package is the fundamental unit of software. Packages are reproducible, maintainable, and dependency-aware building blocks designed for environment parity across the SDLC.

Structurally, a package is the union of its declarative build specification and the resulting binary artifacts. This relationship is cemented by a layer of metadata that defines the package's dependencies, architecture, and provenance. By binding the "recipe" to the "result," Minimal ensures that every component of your environment is transparent, verifiable, and maintainable at scale.

### Overview

A package is defined using [Nickel](https://nickel-lang.org/) syntax at the path `packages/<name>/build.ncl`.
This nickel evaluates to a `BuildSpec` structure that describes the package, as well as its dependencies, how to build it, and a bunch of metadata.

A package `build.ncl` looks roughly like this:

```ncl
let { BuildSpec, Local, Source, OutputBin, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let go = import "../go/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.1.0" in
{
  name = "my-go-tool",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/owner/repo/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "abc123...",
      extract = true,
      strip_prefix = "repo-%{version}",
    } | Source,
    bash,
    go,
  ],
  runtime_deps = [glibc],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "owner",
      repo = "repo",
    },
  },
} | BuildSpec
```

Notice the general structure:
 * Imports at the top
 * Followed by variables, which can be used for string substitution or included / set elsewhere
 * The `BuildSpec` structure, including the package name, the build dependencies, runtime dependencies,
   the `Source` structure(s) (which indicates where to get the source code, it will be made present in the cwd
   for the build), and any `Local` structures, which also bring across adjacent files into the build cwd.

### Imports

A Minimal package usually starts with a bunch of imports:

 * Nickel types that need to be applied, such as `BuildSpec`, `Source`, `Local` etc, these
   are imported from the magic 'minimal standard library' path `minimal.ncl`.
 * Other packages needed for dependencies. These are simple lines that import the
   `build.ncl` file that describes that package and assigns them to a variable. These can
   then be used as an element of the `build_deps` array (if the package is needed during
   the build), or as an element of the `runtime_deps` array, or to make a subset or as a test
   dependency.

Example import line for nickel types:

```ncl
let { subsetOf, BuildSpec, Local, Source, OutputBin, Test, .. } = import "minimal.ncl" in
```

The import line for types from `minimal.ncl` should:

1. Be the first line in the file, and
2. Identifiers should be ordered with lowercase identifiers first (in alphabetical order), before uppercase
   identifiers (also in alphabetical order).

Example import line for packages needed as dependencies:

```ncl
let rust = import "../rust/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let bash = import "../bash/build.ncl" in
```

The identifier for an imported package should match the package name being imported. In nickel, identifiers
are allowed to contain hyphens, so `let bash-bootstrap = import "../bash-bootstrap/build.ncl" in` is totally valid.

### Dependencies

There are two places to declare a packages' dependencies: The `build_deps` array, and the `runtime_deps`
array.

A package belongs as a `build_deps` entry if it is needed during the build but not whenever
the package itself is used. An example of this might be `tar` if a source tarball needs to be extracted
by the build script, or `go` for building Golang source code into a binary.

A package belongs as a `runtime_deps` entry if it is needed anywhere the package itself would be deployed.
Examples of this include `glibc` for built binaries that link with glibc, similarly for openssl. Interpreted
languages like packages that are python scripts typically need their intepreter as a runtime dep as well. All
entries in `runtime_deps` will be injected into the build environment, so there's no need to have an identical
entry in `build_deps` if you have a dependency in `runtime_deps`.

Any package listed in `build_deps` that itself has `runtime_deps` (transitive `runtime_deps`) will also be
injected into the build environment.

There are two common packages worth noting: `base` and `toolchain`.

 * `base` - Contains bash,glibc,coreutils,grep,awk etc. All the standard basic linux CLI stuff you expect.
 * `toolchain` - Contains gcc/g++/binutils etc. The 'basic' C toolchain.

These should be used where possible in lieu of exhaustively listing dependencies.

### Subsets: depending on _some_ libraries in a package

Some packages are really large, like `gcc`, but provide important libraries that are used a lot like
`libgcc` or `libstdc++`. To avoid any user of a package needing to download a whole gcc, its possible
to depend on only some _outputs_ of a package. For instance, the `gcc` package represents `libgcc`
and `libstdc++` with outputs `libgcc` and `libstdcpp`, so if a program needed both libraries, you could
use:

```ncl
subsetOf gcc ["libgcc", "libstdcpp"],
```

as an entry to `runtime_deps`. Don't forget to add `subsetOf` to the import line for `minimal.ncl`.


### Build steps/script

The program to run to complete the build is declared using the `cmd` field, and by convention its always
an adjacent shell script `./build.sh`. Theres also a `build_args` field to pass values across from
the config into this invocation as environment variables: each key/value entry shows up as an env var
`MINIMAL_ARG_<KEY>` where key is uppercase.

The usual pattern is to bind `version` at the top of `build.ncl` and forward it through `build_args` so
`build.sh` can refer to it as `$MINIMAL_ARG_VERSION` rather than hardcoding the value. This keeps version
bumps to a single edit in `build.ncl`:

```ncl
let version = "5.3" in
{
  # ...
  build_args = { include version },
}
```

```bash
cd bash-$MINIMAL_ARG_VERSION
```

See `packages/bash/build.ncl` and `packages/bash/build.sh` for a complete example.

All files to be captured from the build must be stored in `$OUTPUT_DIR`, i.e. `make DESTDIR=$OUTPUT_DIR install`.

In addition to creating the executable `./build.sh` script, you need to declare it as a build dependency, so
the system knows the file needs to be placed into the cwd of the build. This can be done by declaring the file
as a `Local` dependency in the `build_deps` array:

```ncl
{ file = "build.sh" } | Local
```


### Source code

The build of some software works on a copy of the source code. This is done by adding a `Source` dependency to
the `build_deps` array:

```ncl
{
    url = "https://someproject.org/downloads/source-tarball.tar.gz",
    sha256 = "abcdef123...",
} | Source,
```

When a source is present in a `build_deps` array, the system will fetch the file and place it in the working directory
of the build. You can also have the system unpack the tarball into the working directory for you:

```ncl
{
    url = "https://someproject.org/downloads/thingy-v1-source-tarball.tar.gz",
    sha256 = "abcdef123...",
    extract = true,
    strip_prefix = "thingy-v1",
} | Source,
```

Note that unpacking is supported for: `.tar.gz`, `.tgz`, `.tar.xz`, `.tar.zst`, `.tar.bz2`, `.tar`.

If you encounter any errors in the automatic unpacking of the tarball, turn off extraction, add `tar` to `build_deps`, and extract manually in `build.sh`:

```ncl
build_deps = [
  { file = "build.sh" } | Local,
  { url = "...", sha256 = "..." } | Source,
  tar,
  ...
],
```

```bash
tar -xf source-tarball-$MINIMAL_ARG_VERSION.tar.gz
cd source-dir-$MINIMAL_ARG_VERSION
```

(Forwarding `version` via `build_args = { include version }` — see "Build steps/script" above — lets
`build.sh` stay untouched across version bumps.)


### Outputs

The files captured from a build and represented by a package are explicitly declared in an `outputs` field,
which is a map of output names to a structure describing a file glob to capture. There are three categories
of output, any of which must be imported if used: `OutputBin` (for binaries), `OutputLib` (for shared libraries),
and `OutputData` (for data files / internals).

Here's an example of setting the `outputs` field to capture a single output named `bins` which is just all the
binaries emitted:

```ncl
outputs = {
  bins = { glob = "usr/bin/*" } | OutputBin,
},
```


### Attributes

Metadata about the package can be captured in an `attrs` field. This is typed - it is not a free-for-all.

#### Use `upstream_version` for the version of the software being packaged

You can set the `upstream_version` entry to be the version of the software being packaged, if known.

eg, assuming a variable defined earlier with `version` in it:

```ncl
attrs = {
upstream_version = version,
},
```

#### Use `source_provenance` to document software from github or if its a GNU project

Do NOT set this to point to a mirror or any unofficial copy/website. Prefer to omit this field if you
are not certain of the canonical origin of source code for this project.

If it came from github:

```ncl
source_provenance = {
  category = 'GithubRepo,
  owner = "<github account>",
  repo = "<github repo>",
},
```


If its a gnu project:

```ncl
source_provenance = {
  category = 'GnuProject,
  name = "<project name, eg gzip>",
},
```

Omit it if its not one of these variants.


### Other fields

#### `needs`

Declares sandbox capabilities the build requires. Most packages don't need this, but builds that fetch dependencies over the network (Go modules, cargo crates, npm packages) must opt in:

```ncl
needs = {
  dns = {},
  internet = {},
},
```

#### `prebuilt`

Declares the package's output as a checked-in prebuilt binary rather than something built from source during the pipeline. Typically used for toolchain-bootstrap packages that need a working binary before the toolchain itself can compile anything — see `packages/bash-bootstrap/build.ncl` as an example.

The source tarball for a `prebuilt = true` package must already match the on-disk layout that the package emits — there's no build step to move files around. For example, a prebuilt `bash` package needs its tarball to contain the binary at `usr/bin/bash` so it lands where the `OutputBin` glob expects it.



## Creating packages workflow

Step-by-step guide to creating a new package for the Minimal registry.

**When to create a package**: If a task needs a tool or library that doesn't exist in the registry,
the correct approach is to create it — never install it on the host system.


### Step 0: Confirm it's missing

```bash
min search <name>
```

Which will print similarly-named packages. Check alternate names: `python` not `python3`, `node` not `nodejs`, `jdk` not `java`.


### Step 1: Create the package directory

```bash
mkdir packages/<name>
```


### Step 2: Write build.ncl

At minimum, a build spec needs:
- `name` matching the directory name
- `build_deps` with a Local entry for `build.sh` and a Source entry for the upstream archive
- `cmd = "./build.sh"`
- `outputs` declaring what the package produces


### Finding the source URL and SHA256

1. Find the upstream release (GitHub releases, project website)
2. Get the archive URL (prefer `archive/refs/tags/` for GitHub)
3. Compute the hash:
   ```bash
   curl -sL <url> | sha256sum
   ```

**Verify the canonical upstream repo before using it.** GitHub projects get renamed, transferred, or forked — a repo you find via search or an older link may be stale and silently redirect. Before locking in a URL:

- Resolve the repo with `curl -sIL https://github.com/<owner>/<repo> | grep -i '^location:'` (or open it in a browser) and check whether it redirects. If it does, use the new canonical owner/repo in both the `url` and `source_provenance`.
- Cross-check the project's own README, homepage, or package registry page (npm, crates.io, PyPI) to confirm you have the current canonical source.

Getting this wrong means future version bumps chase a dead repo and `source_provenance` lies about where the code came from.

**Build from source — do not package prebuilt release binaries.** When the upstream project's toolchain is available in pkgs (bun, go, rust, cargo, node, etc.), the package must build from the source tarball rather than downloading a prebuilt binary from the release page. Reasons:

- Prebuilt artifacts can be mutated after the fact; source builds give us a real supply-chain guarantee.
- Source builds let us tweak flags for reproducibility and patch issues without waiting on upstream.
- The toolchain is already there — there's no meaningful cost saving from shipping the prebuilt.

Only fall back to a prebuilt binary if the required toolchain genuinely isn't packaged yet, and call that out explicitly in the package.

#### Example: C library (autotools)

```nickel
let { BuildSpec, Local, Source, OutputBin, OutputLib, OutputData, Test, .. } = import "minimal.ncl" in

let version = "1.4.1" in

let gcc = import "../gcc/build.ncl" in
let make = import "../make/build.ncl" in
let bash = import "../bash/build.ncl" in

{
  name = "my-library",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/owner/repo/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "abc123def456...",
      extract = true,
      strip_prefix = "repo-%{version}",
    } | Source,
    bash,
    gcc,
    make,
  ],

  runtime_deps = [],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    headers = { glob = "usr/include/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "owner",
      repo = "repo",
    },
  },

  tests = {
    version_check = {
      class = 'Standalone,
      test_deps = [],
      cmds = [["my-tool", "--version"]],
    } | Test,
  },
} | BuildSpec
```

#### Example: Go tool

```nickel
let { BuildSpec, Local, Source, OutputBin, Test, .. } = import "minimal.ncl" in

let version = "2.1.0" in

let go = import "../go/build.ncl" in
let bash = import "../bash/build.ncl" in

{
  name = "my-go-tool",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/owner/repo/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "abc123...",
      extract = true,
      strip_prefix = "repo-%{version}",
    } | Source,
    bash,
    go,
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
  },

  needs = {
    dns = {},
    internet = {},
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "owner",
      repo = "repo",
    },
  },
} | BuildSpec
```

#### Example: Rust tool

```nickel
let { BuildSpec, Local, Source, OutputBin, Test, .. } = import "minimal.ncl" in

let version = "0.5.0" in

let rust = import "../rust/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let bash = import "../bash/build.ncl" in

{
  name = "my-rust-tool",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/owner/repo/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "abc123...",
      extract = true,
      strip_prefix = "repo-%{version}",
    } | Source,
    bash,
    gcc,
    rust,
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "owner",
      repo = "repo",
    },
  },
} | BuildSpec
```


### Step 3: Write build.sh

The build script must install everything to `$OUTPUT_DIR`.

#### Autotools pattern

```bash
#!/bin/bash
set -euo pipefail

cd my-library-$MINIMAL_ARG_VERSION

export CFLAGS="-march=x86-64-v3 -O3 -pipe"
export CXXFLAGS="$CFLAGS"

./configure --prefix=/usr
make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
```

#### CMake pattern

```bash
#!/bin/bash
set -euo pipefail

cd repo-$MINIMAL_ARG_VERSION

cmake -B build -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_BUILD_TYPE=Release
ninja -C build
DESTDIR=$OUTPUT_DIR ninja -C build install
```

#### Go pattern

```bash
#!/bin/bash
set -euo pipefail

cd repo-$MINIMAL_ARG_VERSION

export GONOSUMCHECK=*
export GONOSUMDB=*

go build -o $OUTPUT_DIR/usr/bin/my-tool .
```

#### Rust pattern

```bash
#!/bin/bash
set -euo pipefail

cd repo-$MINIMAL_ARG_VERSION

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/my-tool $OUTPUT_DIR/usr/bin/
```


### Step 4: Validate

```bash
min check --packages <name>
```

This validates that the Nickel spec parses correctly and conforms to the schema.


### Step 5: Build

```bash
min patched-pkg <name>
```

If the build fails:
- Check that all build dependencies are in `build_deps`
- Check dependencies needed at runtime are in `runtime_deps`
- Check that `build.sh` installs to `$OUTPUT_DIR` (not `/usr/` directly)
- Check the source URL and SHA256
- Check that output globs match what `build.sh` actually installs
- And keep iterating running the `patched-pkg` and `check` commands.


### Step 6: Validate again

```bash
min check --packages <name>
```

Some validation checkers run on the compiled output, and show up as skipped when a package hasn't been built yet.

Run `min check` again to make sure these checkers are run, and iterate by fixing issues, running `patched-pkg`, and then
running `min check` until all addressed.



## Troubleshooting FAQ

### error: other: resolving dep '<package name>' by name: not found

When using `min patched-pkg`, you can get an error if a package is not available locally, that looks
like this:

```
error: other: resolving dep '<package>' by name: not found
```

To fix this, you need to make the package available locally, typically by forcing it to be fetched:

`min add <package>`

If the package thats not found is one that you are presently trying to package, `min add` will fail
because it does not yet exist upstream. Instead, you should get it building with `min patched-pkg` first,
so the completed build populates the package locally, and only then move on to packages that depend on it.

### Rust build errors, `cc` not found

Sandbox doesn't have the standard `cc` symlink, so try adding:

```bash
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"
```

### Go: disable sum database

No network access to sum.golang.org:

```bash
export GONOSUMCHECK=*
export GONOSUMDB=*
```

### Python: install package to system

```bash
pip3 install --no-build-isolation --prefix=/usr --root=$OUTPUT_DIR .
```

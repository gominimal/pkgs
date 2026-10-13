# Switch for the amd64 hex0-rooted bootstrap chain (the stage0-* ladder,
# glibc-bedrock-2.42, gcc/binutils-*-glibc, the go-1.4..1.24.9 and
# mrustc/rustc-1.91..1.97 rungs; 38 packages).
#
# false (interim, 2026-10-07): amd64 works like arm64. Every chain package's
# amd64 spec is an empty stub, and the chain's only consumers take sha-pinned
# tarballs of its last rungs instead: `go` takes go-1.24.9, and the
# `rustc-1.98.1` rung takes rustc-1.97.1 as its stage0 (so `rust` is unchanged).
# Why: those rungs depend on the live tree (bash/coreutils/... are their build
# tools), so any change under openssl/python/glibc rebuilt all 38 on every PR
# and backed up build-bot. The tarballs are build-bot's own outputs of those
# rungs at gominimal/pkgs 9d20a830 (sha = its commit map).
#
# NEW CONSUMERS: the three bedrock roots (gcc-15.2.0-glibc, binutils-2.46-glibc,
# glibc-bedrock-2.42) take the same sealed artifacts the production toolchain
# anchors on, so importing them works either way. Every OTHER chain package is
# an EMPTY stub on amd64 while this is off, and git cannot see that: give a new
# consumer of one a sealed tarball the same way, or flip this back first.
#
# The amd64 rustc tarball loads the LIVE llvm's libLLVM (see rustc-1.98.1):
# an llvm soname bump needs the tarball regenerated while this is off.
#
# true: build the chain from hex0 again. The longer-term fix is to seal the
# chain's build tools so it stops depending on the tree, then flip this back.
# Tracked in gominimal/pkgs#864.
{ enabled = false }

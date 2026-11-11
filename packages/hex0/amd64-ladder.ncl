# Switch for the amd64 hex0-rooted bootstrap chain still in pkgs: hex0, the
# stage0-* ladder and glibc-bedrock-2.42 (23 packages). The rest of the old
# chain (the gcc/binutils glibc seeds, the go-1.4..1.24.9 and
# mrustc/rustc-1.91..1.97 rungs) is built in gominimal/bootstrap now, and pkgs
# pins its gen-13 outputs (go-1.24.9, rustc-1.98.1, gcc, binutils).
#
# false (interim, 2026-10-07): amd64 works like arm64. Every chain package's
# amd64 spec is an empty stub, and consumers take sealed tarballs instead.
# Why: the rungs depend on the live tree (bash/coreutils/... are their build
# tools), so any change under openssl/python/glibc rebuilt the whole chain on
# every PR and backed up build-bot.
#
# NEW CONSUMERS: glibc-bedrock-2.42 takes the same sealed gen-13 artifact the
# production toolchain anchors on, so importing it works either way (today
# glibc-bedrock-2.42-sysroot does, for ghc-9.6.7, ghc and openjdk-21/25/26).
# Every OTHER chain package is an EMPTY stub on amd64 while this is off, and
# git cannot see that: give a new consumer of one a sealed tarball the same
# way, or flip this back first.
#
# The amd64 rustc tarball loads libLLVM.so.21.1 at run time (see rustc-1.98.1).
# It takes it from the frozen, prefixed llvm-21, so the default llvm can move
# on; moving that stage0 off LLVM 21 needs the tarball regenerated while this
# is off.
#
# true: build the chain from hex0 again. The longer-term fix is to seal the
# chain's build tools so it stops depending on the tree, then flip this back.
# Tracked in gominimal/pkgs#864.
{ enabled = false }

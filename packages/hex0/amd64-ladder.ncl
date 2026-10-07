# Switch for the amd64 hex0-rooted bootstrap chain (the stage0-* ladder,
# glibc-bedrock-2.42, gcc/binutils-*-glibc, the go-1.4..1.24.9 and
# mrustc/rustc-1.91..1.97 rungs; 38 packages).
#
# false (interim, 2026-10-07): amd64 works like arm64. Every chain package's
# amd64 spec is an empty stub, and `go` / `rust` take sha-pinned tarballs of
# the chain's last rung (go-1.24.9, rustc-1.97.1) instead of building it.
# Why: those rungs depend on the live tree (bash/coreutils/... are their build
# tools), so any change under openssl/python/glibc rebuilt all 38 on every PR
# and backed up build-bot. The tarballs are build-bot's own outputs of those
# rungs at gominimal/pkgs 9d20a830 (sha = its commit map).
#
# true: build the chain from hex0 again. The longer-term fix is to seal the
# chain's build tools so it stops depending on the tree (hash-proven on branch
# ladder-sealed-tools), then flip this back.
{ enabled = false }

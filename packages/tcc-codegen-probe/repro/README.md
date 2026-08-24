# tcc-codegen-probe reproducer LIBRARY (component b)

Each case is `repro/<name>.c` (+ optional `repro/<name>.lib.c` companion for cross-object cases) and a
`repro/<name>.expected` (the gcc-verified stdout, trailing-newline-insensitive). Line 1 of every `.c`
carries a `//shape:<tag>` marker naming the bug-class it guards. `build.sh` compiles each with the SEALED
`tcc-musl2` the way R5+ link (musl-cc wrapper, libc-twice, `-static`), RUNS it, and compares output.

## How to ADD a case (the loop this whole toolkit exists to make fast)
1. Shrink the offending binutils/gcc TU to a minimal `.c` with `tcc-ddmin.sh` (see scratchpad scripts).
2. Get its correct output from gcc:  `gcc -O0 -w <min.c> -o /tmp/x && /tmp/x > repro/<name>.expected`.
3. Drop `<name>.c` (+ `//shape:` line) into `repro/`, re-tar, `orch push-pkg tcc-codegen-probe && orch enqueue`.
4. Mirror it into `stage0-tcc-0.9.27-musl-s4/torture/` so the SEAL gate also enforces it forever.

## Seeded shapes (this draft)
- `cg_bitfield`   — struct bitfield pack/extract + signed truncation
- `cg_fnptrtab`   — static fn-pointer table + indirect call (.data R_X86_64_64 relocs)
- `cg_compgoto`   — GCC labels-as-values / `goto *ptr` (gcc bootstrap uses it)
- `cg_args7`      — 7-arg call (6 reg + 1 stack), the lb#470 register/stack passing class
- `cg_xcall`      — cross-object DEFINED-GLOBAL NON-LEAF call under -static (fix C / static-PLT regression)

## IMPORT at wire time — the proven s4 torture set (already gcc-verified, do NOT re-derive)
Copy the 12 s4 cases in so the probe is a strict superset of the seal gate:
```
cp ../stage0-tcc-0.9.27-musl-s4/torture/t_*.c        repro/
cp ../stage0-tcc-0.9.27-musl-s4/torture/t_*.expected repro/
# t_xobj is a 2-file case: rename so the harness pairs it (main + .lib companion):
mv repro/t_xobj_main.c repro/t_xobj.c ; mv repro/t_xobj_lib.c repro/t_xobj.lib.c
```
That folds in: t_shift (constant shift-count / fix-shift), t_mul (strength-reduction / BUG2), t_args (>=4-arg),
t_varargs (va_list / BUG6), t_struct (struct-by-value/return), t_float (tcc float + musl strtod/printf),
t_longlong (`__udivdi3` libtcc1.a helper), t_recursion, t_bigframe (large stack frame), t_switch (jump table),
t_setjmp.  Each is a bug we already found by RUNNING a binary — now a permanent regression guard.

## Shapes to ADD before each new rung (anticipatory — "shift left" the bug)
- before R6 gcc-4.0.4:  `long double`/x87 (real.c), nested struct >16B by value, alloca/VLA, `__builtin` shims
- before R9 gcc-4.7.4 (first C++):  vtable/indirect virtual call, exception-free C++ name-mangled calls
- general:  unsigned/signed div+mod by non-constant, 64-bit variable-count shifts, >256-case sparse switch

# amd64 patchset → public scrutiny — plan (workflow `wf_ad481a1a-6d3`, 2026-07-02)

7-agent workflow (4 layer inventories + upstream research + adversarial verify + synthesis).
⚠ CAVEAT: the **tcc-layer inventory agent failed** its schema (retry cap); `layers_covered` = seed/musl/
gcc-binutils only. The synthesis reconstructed the tcc patches accurately from the other agents + the files,
but **when assembling, enumerate the tcc patches directly from disk** (they're in stage0-tcc-0.9.26/0.9.27).

## Answer: YES, we have the raw material — ASSEMBLED
> **UPDATE 2026-07-03:** the patches are ALREADY assembled in-repo at `bedrock-amd64/`. The
> "not yet assembled" / "Scaffold `bedrock-amd64/`" framing below is superseded — the scaffold + copy
> is done. The non-claims / licensing (SPDX) / Option-B/C roadmap remain LIVE. When updating the
> assembled set, still enumerate the tcc patches directly from disk (see the tcc-inventory caveat above).

Clean patches already in live-bootstrap's own format, scattered across ~20 rung dirs, not SPDX-headered,
not greened in lb's tree. **Recommend Option A: a standalone `bedrock-amd64` repo, shippable this week.**

## The genuinely-novel core (verified)
- **`amd64-syscall-arch.patch` (FLAGSHIP)** — rewrites musl `__syscall4/5/6` dropping GCC register-asm r10/r8/r9 for explicit `movq;syscall` (mescc/tcc-mes can't honor register-asm vars). No lb analog (they build `--host=i386`).
- **`skip-pic-crt.patch` + `drop-dynamic-crt.patch`** — the amd64 `_DYNAMIC(%rip)` static-crt pair; RIP-relative defects i386 structurally can't hit. Frame as build workarounds, NOT "musl bug fixes".
- **`amd64-va-list.patch`** — amd64 SysV `__va_list_struct` shim; content-novel analog of lb's i386-only va_list.patch.
- **tcc source fixes** — fix-shift/fix-mul/fix-swapf/fix-swapb/fix-vararg/cast-signed-direct/neg-float-const; directly the lb#470 defect class (fix-swapb/swapf hit the EXACT `assert` SIGSEGV stikonas posted in lb#470).
- **`fix-plt`** — the ONE genuine tcc static-link defect (PLT32→direct for defined syms); best tinycc-upstream candidate, BUT novelty vs modern tinycc mob (PLT32 rework ~2019) is UNVERIFIED — diff before claiming.
- **mes-m2 GC-arena lottery DIAGNOSIS** — a legitimate upstream MES bug *report*, NOT a patch (R1 uses upstream no-growth values; handling is orch infra).
- **THE RESULT (strongest)** — a working amd64-DIRECT mescc→tcc→musl→gcc bootstrap. **lb#470 is OPEN; upstream has NO green amd64 path** (maintainers stikonas/Googulator call it post-1.0; stikonas pasted our exact SIGSEGV).

## HARD NON-CLAIMS (the honesty guardrails — do not violate)
1. NOT "we resolved lb#470" — our green is in OUR harness (Nickel/TEE), not `./rootfs.py -a amd64` in lb's tree.
2. NOT "we fixed tcc" — fix-shift/mul/swap*/vararg/cast-signed are **mescc (and self-) MIScompiles worked around in tcc source** ("we made tcc mescc-safe"); only fix-plt is a genuine tcc bug (novelty unverified).
3. NOT "we invented" `--disable-multilib` / `gnu99+fgnu89-inline` / libc-twice — standard bootstrap practice lb's i386 path never exercises (**novel-vs-lb ≠ novel**).
4. Do NOT present harness items (stage0.answers, anti-pollution wrappers, single-writer sysroot, correctness gate, Model-B stubs) as bootstrap contributions — minimal-platform-specific; EXCLUDE.
5. SSE `.s`-removal / `@PLT`-strip = "delete asm, use portable C" — an availability choice, and inline (not yet patches).
6. Qualify ALL novelty as "vs live-bootstrap mainline" until **FransFaase's parallel MES-replacement fork** (commits f31525ea/263ea265) is cross-checked.
7. Credit live-bootstrap, stage0-posix, GNU Mes, FransFaase generously.

## Licensing (inbound=outbound, clean in principle; one mechanical gap)
Patches inherit the patched project's license: musl=MIT, tcc=LGPL-2.1, mes/mescc=GPL-3.0-or-later. **HARD GAP:**
the 4 novel amd64 musl patches carry **ZERO SPDX headers** (grep-confirmed) while the verbatim-from-lb ones do —
lb's CI runs reuse-lint and would reject ours. Mechanical fix (add SPDX + move prose preambles into PATCHSET.md).

## Publication options
| Opt | What | Effort |
|---|---|---|
| **A ✅ (do first)** | Standalone `bedrock-amd64` repo: ~8 `.patch` + ~24 `.before/.after` novel files, SPDX-headered, lb's `steps/<pkg>-<version>/` layout, + PATCHSET.md (defect→lb#470-symptom→file table), README (scope + non-claims), EXCLUDED.md, LICENSES/ + REUSE.toml. NO build.ncl/stage0.answers/wrappers. | LOW (days) |
| D (alongside) | Technical writeup — the diagnosis narratives (the real intellectual contribution). | MED |
| B (gate for C) | live-bootstrap-shaped FORK greened for `./rootfs.py -a amd64` — re-express fixes into passN.kaem, extract inline logic, gen amd64.checksums. The honest precondition for any "resolves lb#470" claim. | HIGH (weeks) |
| C | Upstream PR series to fosslinux/live-bootstrap. Maintainers receptive-in-principle. Gated on B green. | HIGH+ |

## NEXT CONCRETE STEP (Option A, first artifact)
Scaffold `bedrock-amd64/`, copy the ~30 novel files from `packages/{stage0-musl-1.1.24,stage0-tcc-0.9.26,
stage0-tcc-0.9.27}` into `steps/<pkg>-<version>/{patches,simple-patches}/`, add SPDX headers to the 4 novel
musl patches (musl=MIT), move their prose preambles into PATCHSET.md. That single move fixes the only hard
licensing gap AND produces the first scrutinizable artifact. Copy the SOURCE OF TRUTH (the patch + its build.sh
application), NOT stale build.ncl comments (R4a's header wrongly says amd64-va-list was DROPPED).

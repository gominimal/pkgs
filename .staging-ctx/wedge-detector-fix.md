# Wedge-detector fix: total-active-time cap for the `--retry-on-lottery` watch

Date: 2026-07-01
Scope: DESIGN ONLY — no edits to `main.rs`. This is a spec + diff-style snippet.

## The bug (observed 2026-07-01)

A build task stayed `active` for **125 minutes** with a **FRESH status heartbeat**
(the builder's 60s heartbeat kept rewriting `status.json`, so status-age oscillated
0-166s) while making **NO real progress** — a network-stalled attestation/chain-probe
walk. The task never auto-recovered; it needed a manual `orch drop … --from active`
+ re-enqueue.

## Root cause (verified in code)

The Active-arm auto-recovery in `watch_and_retry_lottery`
(`crates/orch/src/main.rs`) fires on ONE discriminator only: **status-age**
(`now - status.updated_at`, via `status_age_secs`, main.rs:6615). It recovers iff
`status_age > STALE_STATUS_SECS` (1800s, main.rs:6605):

```
main.rs:6712   Some(a) if a > STALE_STATUS_SECS => { … drop + re-enqueue … }
```

A wedge that keeps the heartbeat fresh (the builder process is alive and touching
`status.json`, it's a *downstream* op — the chain probe — that has stalled) has a
small `a` forever, so this guard NEVER trips. The comment at main.rs:6700-6702
explicitly chose status-age over wall-clock ("a 90-min build with a fresh heartbeat
is healthy") — correct for the *frozen-heartbeat* wedge it was built for, but it
leaves the **fresh-heartbeat-but-stalled** class uncovered.

### Why a true "no-progress" signal isn't available today

The only per-task progress signals in `orch_queue::Status` (lib.rs:154-162) are
`updated_at` (heartbeat, oscillates), `phase`, and `artifact_sha256` (None until
done). I checked every builder writer of `phase`
(`hermetic-builder-rs/src/queue_mode.rs`): in queue mode it is the **constant
string `"building"`** for the entire build (claim write line 115, every heartbeat
line 149), only flipping to `"built"`/`"failed"` at terminal. So `phase` is INERT
mid-build — it carries no progress. The struct doc's `"building #44 python"`
example is aspirational; queue_mode never emits it. **Conclusion: there is no
within-`Status` signal that advances during a healthy build, so a real
"no-cache-progress" AND-gate cannot be built without a builder-side change
(see Mitigation 4).**

## The fix: total-active-time cap (belt-and-suspenders backstop)

Add a SECOND, generous discriminator that keeps climbing regardless of heartbeat
freshness: **total active time of the current claim = `now - status.started_at`**.
`started_at` is written once at claim (queue_mode.rs:113) and carried unchanged
through every heartbeat (line 147), so it is a clean "actively-building-since"
stamp. It resets per claim: `enqueue()` clears `Status`, so a recovered task reads
`None` (age=None arm) until its fresh sandbox writes `started_at = now` — the cap
can't instantly re-trip.

### Proposed threshold

`MAX_ACTIVE_SECS = 6000` (**100 minutes**). Justification:

- This watch is **opt-in per `--retry-on-lottery` invocation** (main.rs:6561-6564),
  used for the **bedrock rungs** (mes/tcc/gcc lottery pkgs). It does NOT supervise
  bun/opencode/or-tools (those enqueue without the flag), so the ~88-min bun build
  is **out of scope** and cannot be false-killed.
- Within scope, the longest legit build is the **gcc cold closure ~30-45 min**.
  100 min is >2x that worst case.
- 100 min sits **above** the code's own "90-min fresh-heartbeat build is healthy"
  boundary (so no legit build is killed), yet **below** the 125-min wedge (so
  today's hang WOULD have auto-recovered).
- Still bounded by the existing `WEDGE_RECOVERY_CAP` (3), so a builder that wedges
  every claim can't loop forever.

## Specific code change

### 1. New constant (insert right after `STALE_STATUS_SECS`, ~main.rs:6606)

```rust
/// Belt-and-suspenders backstop for the wedge class where the heartbeat stays
/// FRESH (the builder keeps touching status.json) but the task makes NO real
/// progress — observed 2026-07-01: a 125-min network-stalled attestation/chain
/// probe walk with status-age oscillating 0-166s, which STALE_STATUS_SECS can
/// NEVER catch. Total active time (now - Status.started_at) keeps climbing
/// regardless of heartbeat freshness, so it catches this. 100 min: generous —
/// >2x the ~45-min gcc cold-closure worst case among the bedrock rungs this
/// `--retry-on-lottery` watch supervises, above the "90-min fresh-heartbeat
/// build is healthy" boundary below (so a legit long build is never killed),
/// yet below the 125-min wedge (so today's hang auto-recovers). Bounded by
/// WEDGE_RECOVERY_CAP like the stale path.
const MAX_ACTIVE_SECS: i64 = 6000;
```

### 2. Keep the `Status` (compute active-time) + broaden the guard

Insertion point: the Active arm's status read + `match age` head,
**main.rs:6703-6712**. Diff-style (context lines unmarked, `-` removed, `+` added):

```rust
                 let elapsed_m = (poll as u64 * POLL_SECS) / 60;
-                let age = queue
-                    .read_status(&task)
-                    .await?
-                    .map(|s| status_age_secs(&s, Utc::now()));
-                match age {
+                let now = Utc::now();
+                let status = queue.read_status(&task).await?;
+                let age = status.as_ref().map(|s| status_age_secs(s, now));
+                // Total time THIS claim has been active (now - started_at).
+                // Unlike status-age it climbs even while the heartbeat stays
+                // fresh, so it catches the fresh-heartbeat-but-stalled wedge
+                // (network-stalled chain probe) status-age alone misses.
+                // Resets per claim: enqueue() clears Status, so a recovered
+                // task reads None here until its fresh sandbox re-stamps
+                // started_at, so this can't instantly re-trip.
+                let active_over_cap = status
+                    .as_ref()
+                    .map(|s| (now - s.started_at).num_seconds() > MAX_ACTIVE_SECS)
+                    .unwrap_or(false);
+                match age {
                     // Heartbeat present AND frozen past the stale threshold — the
                     // SAME condition `orch health` warns on. Auto-recover
-                    // (bounded): drop from active/ + re-enqueue a fresh task.
-                    Some(a) if a > STALE_STATUS_SECS => {
+                    // (bounded): drop from active/ + re-enqueue a fresh task.
+                    // OR: active past MAX_ACTIVE_SECS despite a fresh heartbeat
+                    // (the 125-min stalled chain-probe walk, 2026-07-01) — same
+                    // recovery, same WEDGE_RECOVERY_CAP bound.
+                    Some(a) if a > STALE_STATUS_SECS || active_over_cap => {
+                        // Which trigger fired — the frozen heartbeat, or the
+                        // total-active-time backstop (heartbeat still fresh).
+                        let reason = if a > STALE_STATUS_SECS {
+                            format!("builder status stale {a}s")
+                        } else {
+                            let active_m = status
+                                .as_ref()
+                                .map(|s| (now - s.started_at).num_seconds() / 60)
+                                .unwrap_or(0);
+                            format!(
+                                "active {active_m}m with a FRESH heartbeat but no \
+                                 progress (> {}m cap)",
+                                MAX_ACTIVE_SECS / 60
+                            )
+                        };
```

### 3. Reword the two log lines inside the arm to use `reason`

Both existing `wlog`s in this arm hardcode `builder status stale {}s` with `a`;
that reads wrong when the active-cap (fresh `a`) fires. Swap the interpolation:

- **main.rs:6714-6721** (cap-reached):
  ```rust
  -   "{}@{} WEDGED again (builder status stale {}s) but wedge-recovery cap {} …",
  -   task.package, task.version, a, WEDGE_RECOVERY_CAP, task.package
  +   "{}@{} WEDGED again ({}) but wedge-recovery cap {} reached — stopping …",
  +   task.package, task.version, reason, WEDGE_RECOVERY_CAP, task.package
  ```
- **main.rs:6743-6747** (recovered):
  ```rust
  -   "WEDGE detected on {} (builder status stale {}s) — dropped + re-enqueued …",
  -   task.package, a, wedge_recoveries, WEDGE_RECOVERY_CAP
  +   "WEDGE detected on {} ({}) — dropped + re-enqueued (wedge-recovery {}/{})",
  +   task.package, reason, wedge_recoveries, WEDGE_RECOVERY_CAP
  ```

The drop + `wedge_recoveries += 1` + `queue.enqueue(&task)` body is REUSED
unchanged — the active-cap piggybacks on the existing recovery machinery. The
`Some(a) =>` fresh arm and `None =>` pre-build arm are unchanged (with `a` fresh
and under the cap, control still falls to the fresh arm; `None` implies no
`started_at`, so `active_over_cap` is `false`).

Also update the main.rs:6700-6702 comment ("STATUS-AGE, NEVER wall-clock elapsed")
to note the new belt-and-suspenders: status-age is the PRIMARY signal;
total-active-time is a generous BACKSTOP for the fresh-heartbeat-stalled class.

## Risk + mitigation

**Risk:** killing a legitimately-long build that legitimately exceeds 100 min.
A re-enqueue restarts the pkg's OWN compile from scratch (RemoteCache skips
*dependencies*, not intra-build steps), so a false positive is genuinely costly
for that pkg.

Mitigations, in order of what this design relies on:

1. **Scope.** The cap lives ONLY in `watch_and_retry_lottery`, which runs ONLY
   under `--retry-on-lottery > 0` (bedrock rungs). Heavy frontier pkgs (bun ~88m,
   or-tools, opencode) enqueue WITHOUT the flag and are never subject to it. This
   is what makes 100 min safe — the in-scope worst case is gcc at ~45 min.
2. **Generous cap.** 100 min is >2x the in-scope worst case and above the stated
   "90-min fresh-heartbeat is healthy" line.
3. **Bounded blast radius.** `WEDGE_RECOVERY_CAP = 3` already caps total
   recoveries; after 3 the watch stops and tells the operator to investigate.
4. **Per-session / per-pkg override (recommended follow-up).** Thread a
   `--max-active-mins <N>` flag through `Command::Enqueue` → `enqueue()` →
   `watch_and_retry_lottery(queue, task, max_retries, max_active_mins)`, defaulting
   to 100, so a session on a known-heavy rung can raise it (or a fast-rung session
   can lower it to, say, 75 to catch wedges sooner). Small, additive; not required
   for the core fix.
5. **The honest "require BOTH" form needs a builder change.** The task suggested
   requiring long-active AND no-cache-progress. That AND-gate is NOT implementable
   today because `phase` is the constant `"building"` in queue mode (verified) — no
   progress signal exists to AND against. Proper fix: have queue_mode write a
   *monotonic progress token* into `Status` (e.g., `phase = "building #<n> <file>"`
   or a `steps_done` counter), then the watcher can require `active > cap AND phase
   unchanged for > K min`. Until then, the generous scoped cap + WEDGE_RECOVERY_CAP
   is the safe substitute. Recommend filing this builder-side progress-field change
   as the real long-term hardening.

## Observations

- **`phase` is dead weight in queue mode.** It's written as a constant and the
  operator-facing `orch status`/`orch health` can't distinguish a stalled build
  from a healthy one by phase. Making `phase` carry real progress (Mitigation 5)
  would improve `orch status`, enable a true no-progress AND-gate, AND let
  `orch health` flag stalls without a wall-clock heuristic — it's the higher-value
  fix, the active-time cap is the cheap-now backstop.
- The 125-min wedge cause (network-stalled attestation/chain-probe walk) is worth
  a separate look: a *hung network op* inside the build ideally gets a **timeout**
  at the call site (so the build fails cleanly and the existing transient-retry
  path handles it) rather than relying on the operator watch to notice hours later.
  The active-time cap is a safety net; a bounded timeout on the chain-probe HTTP
  walk is the root-cause fix.

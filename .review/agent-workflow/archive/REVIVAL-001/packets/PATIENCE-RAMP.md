---
id: PATIENCE-RAMP
title: Patience ramp: shift 3+ of a session trims NPC patience
priority: P2
role: Mason
worker_tier: sonnet
release_gate: before
depends_on: [SERVE-PAYPOPUP, NPC-REACTIONS]
status: READY
source_commit: 098175c
read_scope:
  - src/server/Modules/CustomerService/Rules.luau (Rules.PatienceSeconds, Rules.VariantPatience)
  - src/shared/Configuration/CustomerConfig.luau (PATIENCE_* block, FIRST_SESSION_*)
  - src/server/Modules/CustomerService/init.luau (_assign, KnitStart ClockedInChanged block, PlayerRemoving, field list)
  - src/server/Modules/ShiftService.luau (ShiftEnding signal, summary.Shift; read only)
  - src/server/Tests/CustomerService.spec.luau
write_scope:
  - src/server/Modules/CustomerService/Rules.luau
  - src/shared/Configuration/CustomerConfig.luau
  - src/server/Modules/CustomerService/init.luau
  - src/server/Tests/CustomerService.spec.luau
invariants:
  - serve-path no-yield (WORKER-PRIMER 1): nothing yields between the serve guards and the payout in _onServeTriggered. This packet does not touch _onServeTriggered or the payout. All new code runs in _assign (assignment time), a signal handler, and pure Rules functions; none of it yields. Patience seconds never feed Rules.Payout, so pay is unchanged.
  - First-session scripted orders keep frozen patience (they do not tick) and are never trimmed.
  - DEC-013 not applicable (no UI). Economy-adjacent numbers are tagged PROPOSED and listed in _meta/ECONOMY-LEDGER.md.
acceptance:
  - Rules.PatienceSeconds(items, config, sessionShift) returns the old value when sessionShift is nil, 1 or 2; 5% less at shift 3; 10% less at shift 4 and every later shift.
  - A non-scripted NPC assigned during a player's third shift of the session has PatienceTotal 5% smaller; during shift 4+ 10% smaller. A scripted NPC is unchanged.
  - Rules.VariantPatience composes after the ramp (Karen and VIP multipliers apply to the trimmed seconds).
  - The session shift counter resets when the player leaves; it never reads or writes the profile.
  - The spec cases listed below exist and pass in Studio (Jack runs them).
checks:
  - "wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/server/Modules/CustomerService/Rules.luau src/shared/Configuration/CustomerConfig.luau src/server/Modules/CustomerService/init.luau src/server/Tests/CustomerService.spec.luau'"
  - rojo build default.project.json -o <scratchpad>/out.rbxlx
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/PATIENCE-RAMP
forbidden: [WORKER-PRIMER 8, editing TESTS_ENABLED or RunTests.server.luau, changing existing spec expectations, changing PATIENCE_BASE_SECONDS or any bonus value, touching Rules.Payout, touching the profile or ProfileTemplate]
---

Primer: `_meta/WORKER-PRIMER.md` (rules, gate, evidence). Not repeated here.

## Source excerpt
C6 (review, HEAD c77e20c): What: Patience ramp by shift: shift 3+ of a session trims patience by 5-10%. Why: Raises tension as skill rises. Files: Rules.PatienceSeconds. Effort: XS. Risk: Med. Tag: JACK (core pacing; delegated by DEC-053).

## Decisions made
- D1. "Session shift N" = (shifts the player has completed since joining this server) + 1. CustomerService counts it itself from `self._shift.ShiftEnding` (fires once per ended shift with the player). Rationale: avoids a ShiftService or profile change (ShiftService belongs to SHIFT-END; profile fields are out of scope); Q-G10 real-player serves already count toward shift end, so they advance this counter without extra work.
- D2. Trim schedule: shift 1 and 2 multiplier 1.00; shift 3 multiplier 0.95; shift 4 and later multiplier 0.90 (floor). Rationale: inside the 5-10% brief; the 10% cap keeps the Fast window (patience fraction >= 0.5) at 90% of today's seconds, so Perfect play still earns Fast bonuses.
- D3. Formula in a new pure function `Rules.PatienceRampMult(sessionShift: number?, config: Config?): number`: if sessionShift is nil or below PATIENCE_RAMP_FIRST_SHIFT return 1; else return `1 - math.min((sessionShift - PATIENCE_RAMP_FIRST_SHIFT + 1) * PATIENCE_RAMP_TRIM_PER_SHIFT, PATIENCE_RAMP_MAX_TRIM)`. Rationale: three constants, no tables, testable.
- D4. `Rules.PatienceSeconds(items, config?, sessionShift?)` multiplies the existing sum by `Rules.PatienceRampMult(sessionShift, config)`. No rounding (patience may be fractional; PatienceTotal is a number and the bar uses fractions). Rationale: rounding half cases would make tests brittle and the gain is nil.
- D5. Only the assignment call site is changed: in `CustomerService:_assign`, `Rules.PatienceSeconds(orders)` becomes `Rules.PatienceSeconds(orders, nil, if scripted then nil else self:_sessionShiftOf(player))`. The spawn-time call in `_spawnIfNeeded` (`Rules.PatienceSeconds({ order })`) stays unchanged because the NPC has no barista yet and `SetAssignment` overwrites the patience at assignment. Rationale: the only patience that ticks is the one set at assignment.
- D6. Scripted (first-session) NPCs pass nil, so they are never trimmed. Rationale: their patience is frozen (design 4.4).
- D7. `_sessionShifts` is a new field `{ [Player]: number }` on the CustomerService table, incremented in a `ShiftEnding` handler and cleared in `PlayerRemoving`. The handler is wrapped in pcall and never yields. Rationale: session memory only, same pattern as `_combo`.
- D8. Real-player orders (RealOrderService) do not use PatienceSeconds and are untouched.

## Exact strings
None. Code comments: tag the constants `-- PROPOSED (REVIVAL-001 C6, DEC-053)`.

## Exact numbers
Add to CustomerConfig directly after `PATIENCE_RED_FRACTION` (all PROPOSED, also in the ledger):
- `PATIENCE_RAMP_FIRST_SHIFT = 3` -- PROPOSED: first session shift that is trimmed
- `PATIENCE_RAMP_TRIM_PER_SHIFT = 0.05` -- PROPOSED: extra trim per shift from the first trimmed one
- `PATIENCE_RAMP_MAX_TRIM = 0.10` -- PROPOSED: the trim never exceeds this
Resulting seconds (single order): Boba 70 -> shift 3: 66.5, shift 4+: 63. Coffee 60 -> 57, 54. Brownie 55 -> 52.25, 49.5. Karen (PatienceMult applied after) trims proportionally.

## Signatures and event names
- `function Rules.PatienceRampMult(sessionShift: number?, config: Config?): number`
- `function Rules.PatienceSeconds(items: { OrderItem }, config: Config?, sessionShift: number?): number`
- `function CustomerService:_sessionShiftOf(player: Player): number` returns `(self._sessionShifts[player] or 0) + 1`.
- Field `_sessionShifts = {} :: { [Player]: number }` (comment: shifts completed this session, memory only).
- In KnitStart, immediately before the comment "Clock-in restarts the idle clock", add `self._shift.ShiftEnding:Connect(function(player) ... end)` that does `self._sessionShifts[player] = (self._sessionShifts[player] or 0) + 1` inside pcall.
- In `CustomerService:PlayerRemoving`, add `self._sessionShifts[player] = nil`.
- Config table type note: `type Config = typeof(CustomerConfig)` already covers the new constants.

## UI spec
None.

## Spec text for the worker (src/server/Tests/CustomerService.spec.luau)
Add inside the existing top-level function, new `describe("PatienceRampMult (C6)")` and `describe("PatienceSeconds with a session shift (C6)")` after the existing "PatienceSeconds (design 4.5)" block. Existing cases stay untouched and must pass unchanged. Use `expect(x).to.be.near(expected, 0.001)` for fractional values.
PatienceRampMult cases:
1. nil -> 1 (equal).
2. shift 1 -> 1.
3. shift 2 -> 1.
4. shift 3 -> near 0.95.
5. shift 4 -> near 0.90.
6. shift 5 -> near 0.90 (capped).
7. shift 50 -> near 0.90.
PatienceSeconds cases:
8. single Boba, shift nil -> 70 (equal).
9. single Boba, shift 2 -> 70 (equal).
10. single Boba, shift 3 -> near 66.5.
11. single Boba, shift 4 -> near 63.
12. single Coffee, shift 5 -> near 54.
13. empty order, shift 3 -> near 42.75 (45 x 0.95).
14. boba plus brownie (80), shift 4 -> near 72.
15. config override: `local c = table.clone(CustomerConfig); c.PATIENCE_RAMP_FIRST_SHIFT = 2; c.PATIENCE_RAMP_TRIM_PER_SHIFT = 0.1; c.PATIENCE_RAMP_MAX_TRIM = 0.2` (cast to any), Boba, shift 3 -> near 56 (70 x 0.8).
16. Karen composition: `Rules.VariantPatience(Rules.PatienceSeconds({ item("Boba Teas") }, nil, 3), "Karen")` -> near `66.5 * CustomerConfig.VARIANTS.Karen.PatienceMult`.
17. Constants sanity: `PATIENCE_RAMP_FIRST_SHIFT >= 3`, `PATIENCE_RAMP_MAX_TRIM <= 0.10`.

## Studio checks (Jack, batched)
- S1: Clock in as a fresh join and finish two shifts; during shift 3 read an assigned NPC's `PatienceTotal` attribute (Explorer, workspace.Customers): a Boba order reads 66.5, in shift 4 reads 63.
- S2: Rejoin: the next shift is shift 1 again (Boba reads 70).
- S3: As a brand-new profile, the first three scripted NPCs still do not tick and show a full bar.
- S4: The bar still turns yellow at 50% and red at 25% of the smaller total; payout for a Perfect is unchanged for the same grade and speed fraction.
- S5: Run the TestEZ CustomerService spec; all old and new cases pass.

## Asset prerequisites
None.

Open items: none

## Summary
- New pure `Rules.PatienceRampMult` and optional third arg on `Rules.PatienceSeconds`.
- Numbers (PROPOSED): trim starts shift 3, 5% per shift, capped at 10% (shift 3 = 0.95, shift 4+ = 0.90); ledger rows added.
- Session shift count lives in CustomerService from ShiftService.ShiftEnding; no profile or ShiftService edit.
- Only the `_assign` call site is ramped; spawn-time call and scripted first-session NPCs are unchanged.
- No serve-path edit; no yields added; pay untouched.
- 17 spec cases listed in the packet for the worker to write.
- Lease: after SERVE-PAYPOPUP and NPC-REACTIONS in the init.luau chain; before BIG-B1 in Rules/CustomerConfig/spec.

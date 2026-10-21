---
id: BIG-B4
title: Living cafe - served NPCs sit, drink, then leave (design doc)
priority: P1
role: Mason
worker_tier: opus
release_gate: after
depends_on: [PATIENCE-RAMP, NPC-REACTIONS, SERVE-PAYPOPUP, SERVE-FEEDBACK]
status: BLOCKED-ON-ASSET
source_commit: 098175c
read_scope:
  - src/server/Modules/CustomerService/Npc.luau (Context, NpcFields, State, ANIMATION_NAMES, resolveAssets, buildNpcModel, buildBubble, Npc.Leave, Npc.Destroy, Npc._walkTo, Npc._waitOutPatience, Npc._run)
  - src/server/Modules/CustomerService/init.luau (_makeContext, _spawnIfNeeded, _pacingTarget, _pacingLoop, _onServeTriggered, _onCustomerLeft, KnitStart)
  - src/shared/Configuration/CustomerConfig.luau (SERVER_CAP), src/shared/Configuration/RatingConfig.luau (RUSH_CAP_BONUS, RUSH_NPC_MULT)
  - src/shared/Utility/WorldPath.luau (find), src/server/Tests/RunTests.server.luau (Studio-only attribute precedent)
write_scope: [see phase packets; this doc writes no code]
invariants:
  - serve-path no-yield (WORKER-PRIMER 1): B4 adds nothing to CustomerService:_onServeTriggered. The only Leave edit is two field assignments. The seat claim runs in the NPC's own _run thread (already a task.spawn thread) after _waitOutPatience returns, i.e. after the payout.
  - Counter flow is never blocked: Leave still calls Release (line and counter spot freed) before any seat logic; seat code never touches _line or _counter.
  - DEC-008 / HARD STOP 1: no seat folder, animation or prop is built or substituted. Missing content = seating silently off (one warning).
  - SeatingConfig.ENABLED = false disables every B4 behaviour with zero code removal.
acceptance: [see phase packets]
checks: [see phase packets]
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/BIG-B4
forbidden: [WORKER-PRIMER 8, any edit to _onServeTriggered, Seat furniture edits, building seats/props/animations]
---

Primer: `_meta/WORKER-PRIMER.md`. Phases: `BIG-B4-P1-PERFCHECK.md`, `BIG-B4-P2-SEATS.md`, `BIG-B4-P3-LEAVE.md`, `BIG-B4-P4-POLISH.md`.

## 1. Source excerpt
B4 (review section 6, verbatim; one word normalised to pass packet lint, marked [ ]):
Living cafe: NPCs sit and drink
 Pitch: served customers carry their drink to a free seat, sit (BoothSit, CafeSit, ComfySit, CouchSit animations exist), drink for 20-40 s, [optionally] react with a heart emote, then leave.
 Why: the cafe looks busy and alive, the player sees the result of their work, screenshots and thumbnails improve.
 Risks: NPC count and performance (more NPCs present: SERVER_CAP is 16 for waiting NPCs); seat pathing with MoveTo (fallback PivotTo exists); seats taken by players.
 Dependencies: an authored seat contract (Rigger names the seat folder; 243 seats exist per the plan, but the paths must be confirmed, per DEC-008); NPC-LOOK for the drink prop.
 Plan: a separate "seated" NPC budget (for example 8), the nearest free seat from an authored workspace.Assets.NPC.Seats folder (Rigger), and leave after a timer. Never block the counter flow.
 Recommendation: phase 1 before release only if a Studio perf check is clean; otherwise in the first update.

C4 (review, HEAD c77e20c): What: NPCs sit and drink after a serve (243 seats; BoothSit, CafeSit, ComfySit and CouchSit exist in NPCStorage.Animations); they leave after 20-40 s. Why: A full cafe is the fantasy; the room fills with your work. Big bet B4. Files: Npc.luau, CustomerService (seat reservation); authored seats. Effort: L. Risk: Med (perf, pathing). Tag: JACK.

Binding: DEC-054 Q-G13: B4 ships before release only if the Studio perf check (P1 protocol) is clean, otherwise in the first update.

## 2. What exists at HEAD 098175c (verified)
- `Npc._run` (Npc.luau): Entry -> Path -> Queue -> Counter -> `_waitOutPatience` -> `self:Leave("PatienceOut")` (no-op when already Left) -> `_walkTo(nodes.Exit)`; `Start` destroys the NPC after `_run` returns or errors.
- A serve calls `npc:Leave("Served")` after the payout (`_onServeTriggered`); NPC-REACTIONS changes it to `npc:Leave("Served", grade)` and computes `thanked` inside Leave. `_waitOutPatience` exits within 0.25 s because State becomes "Leaving".
- `Leave` calls `ctx.Release` (frees line slot and counter spot) and `ctx.OnLeft`. The NPC stays counted in `_npcCount` until `Destroy` -> `ctx.OnDestroyed`.
- `_spawnIfNeeded` stops at `_npcCount >= _pacingTarget()`. `Rules.PacingTarget` caps at `CustomerConfig.SERVER_CAP = 16`; Rush Hour: `min(16 + RUSH_CAP_BONUS 4, ceil(target * 1.5))` = 20 max.
- `buildNpcModel` disables `HumanoidStateType.Seated` ("a Path that brushes a Seat must not sit the NPC").
- `resolveAssets` loads only `ANIMATION_NAMES = { "Wave", "Confused", "Idle" }` from `ReplicatedStorage.SharedStorage.NPCStorage.Animations`.
- Sit animations: not in source. Evidence only: RIG-1/evidence.md lists BoothSit 139797831117693, ComfySit 99196153493320, CafeSit 124224206331430, CouchSit 99196153493320 (ComfySit and CouchSit share one id), docs/SYSTEMS.md lists the names. Ids unverified in Studio.
- Seats: no seat code at HEAD. S3/evidence.md (legacy source recon) says the legacy game used `Workspace.Assets.Seating` (34 groups, each a Table model plus a Seating model of `Seat`s) and played `<GroupName>Sit`; recon-memo.md counts 243 seats in the map. Neither path is verified in the current place. `workspace.Assets.NPC.Seats` does not exist yet (Rigger authors it, see section 6).
- Drink prop: none in source or evidence (NPC-LOOK covers looks and animations only). Heart icon: none (REALORDER-HEARTS HARD-STOP).
- No perf diagnostics exist in src or tools (grep `HeartbeatTimeMs|GetTotalMemoryUsageMb` = 0 hits). Precedent for a Studio-only attribute switch: `RunTests.server.luau` (`RunService:IsStudio() and workspace:GetAttribute("RunTests") == true`).

## 3. Decisions made
- D1. All B4 constants live in a NEW file `src/shared/Configuration/SeatingConfig.luau` (single writer: the B4 phases). B4 does not write CustomerConfig.luau or Rules.luau, so the INVENTORY edge BIG-B1 -> BIG-B4 on CustomerConfig is not needed. Rationale: removes a lease edge and keeps the flag in one place.
- D2. Feature flag `SeatingConfig.ENABLED = false` (P1 ships it false). When false, `TryClaimSeat` returns nil before any lookup, so `_run` behaves exactly as at HEAD. P1's perf result sets the default (section 8). Rationale: Q-G13 fallback with zero code removal.
- D3. Studio-only overrides (ignored outside `RunService:IsStudio()`), all workspace attributes: `B4SeatingForce` (true = seating on regardless of ENABLED), `B4SeatBudgetOverride` (number), `B4Stress` ("Run" | "Drain"), `B4StressRush` (true). Rationale: Prime can run on/off perf passes without editing code; follows the RunTests precedent.
- D4. Separate seated budget `SEATED_BUDGET = 8`: an NPC enters the "seat phase" when it claims a seat and leaves it only on Destroy (including its walk to Exit). Pacing counts `_npcCount - BudgetUsed()`. Rationale: seated NPCs never take spawn slots from waiting NPCs, and the extra population is capped.
- D5. SERVER_CAP interplay: the waiting/walking population is unchanged (<= PacingTarget <= 16; Rush <= 20). Seat-phase NPCs add at most 8. Hard ceiling of NPC models: 24 normal, 28 Rush. `#_line >= #Queue` spawn guard unchanged. The perf check measures the 28 case.
- D6. Who sits: an NPC that left with reason "Served" and `Thanked == true` (NPC-REACTIONS D2: not a Karen after a Close), passes `SIT_CHANCE = 0.8`, and finds a free seat within 80 studs. Everyone else walks to Exit as today. Scripted first-session NPCs sit too. Rationale: the room fills with the player's results; a stomping Karen does not stay.
- D7. Seat claim timing: in `Npc._run`, after `_waitOutPatience` and `Leave("PatienceOut")`, in the NPC's own thread. `Leave` only records `self.LeftReason = reason` and `self.Thanked = thanked`. No task.spawn is added: `_run` already runs inside `Npc.Start`'s task.spawn, after the payout. Rationale: serve-path invariant with no new thread.
- D8. Seat choice: nearest free entry by straight distance from the NPC root at claim time, tie -> lower entry number. Free = not reserved by the pool, `Seat.Occupant == nil` (players count), `Seat.Disabled == false`, Seat and ObjectValue still parented. Rationale: NPCs settle in view of the counter; 243 entries scan in microseconds.
- D9. Seat contract (Rigger, section 6): `workspace.Assets.NPC.Seats` Folder of ObjectValues named 1..n, `Value` = an existing `Seat`, attribute `SitAnim` in {BoothSit, CafeSit, ComfySit, CouchSit}. Furniture is never moved or edited. Reservation attribute `NpcReservedBy` (string, NPC model name) is set on the ObjectValue at runtime. Rationale: authored seats stay untouched; one class to resolve.
- D10. Sitting uses the real `Seat:Sit(humanoid)` (re-enabling `HumanoidStateType.Seated` only for the sit, disabled again on stand-up) plus the entry's sit animation looped at Action priority. An entry whose animation is not loaded is skipped at resolve. Rationale: SeatWeld gives the authored posture the legacy animations were made for; no standing-on-seat pose when an animation is missing.
- D11. Walking to a seat: `MoveTo` toward `Seat.Position` with `SEAT_WALK_TIMEOUT_SECONDS = 8`; on stall, `Seat:Sit` snaps the NPC onto the seat (this is the PivotTo-equivalent fallback); it does not count toward `MAX_FALLBACKS_IN_A_ROW`. P4 adds PathfindingService waypoints in front of it. Rationale: MoveTo with fallback, as the review asks, without despawning stuck NPCs.
- D12. Players: if the seat is occupied on arrival, release it and claim once more (`SEAT_RETRY_COUNT = 1`), else walk to Exit. An NPC never ejects a player. A seated NPC makes the Seat occupied, so players cannot sit on it.
- D13. Sit duration `Seats.SitSeconds(roll)` = 20 + floor(roll * 21), i.e. 20..40 s uniform (PROPOSED tuning, not economy). The NPC stands early if it loses the seat (Occupant no longer its Humanoid).
- D14. On entering the seat phase: destroy the NPC's `ServePrompt`, set model attribute `PromptAction` nil, hide the order card (`OrderBubble.Card.Visible = false`; the Speech label stays usable). Rationale: no "Serve"/"Rescue" prompt or stale patience bar over a seated customer (KitchenController re-enables prompts locally from AssignedUserId/PatienceEnd).
- D15. Heart emote: no icon (none exists, REALORDER-HEARTS). P4 shows one seated speech line through `_say("Seated")` with chance 0.5, 6 s after sitting. Rationale: DEC-013, reuses the existing bubble.
- D16. Drink prop: P4 equips a clone of `ReplicatedStorage.SharedStorage.NPCStorage.Props.Drink` (Tool with a `Handle`) if present; missing = skipped with one warning. Not built by agents (HARD-STOP 1c).
- D17. Cleanup: `ctx.OnDestroyed` calls `pool:Forget(npc)` (frees reservation, budget and a stale SeatWeld). `game:BindToClose` calls `pool:Close()` (no new claims, all reservations cleared). Stand-up calls `ctx.ReleaseSeat`.
- D18. Phases and gates: P1 (flag, overrides, stress hook, protocol, baseline) release_gate before (inert). P2 (Seats module, contract, pool wiring) and P3 (NPC sit/drink/leave behaviour) release_gate after, promoted to before when the P1 protocol run B passes. P4 (polish) after.

## 4. State machine
NPC `State` attribute (Npc.State type gains "ToSeat" and "Seated"):
```
Walking -> Queued -> Walking -> AtCounter --Leave(reason)--> Leaving
Leaving --(reason=="Served" and Thanked and SIT_CHANCE and claim ok)--> ToSeat
ToSeat --(Sit ok)--> Seated --(timer or seat lost)--> Leaving --walk--> Exit -> Destroy
ToSeat --(occupied, retry claim ok)--> ToSeat (once) ; ToSeat --(fail)--> Leaving --walk--> Exit
any --(error / Destroy)--> Destroy (OnDestroyed -> pool:Forget)
```
Model attributes added: `SeatId` (entry Name, set at ToSeat, nil at stand-up). ObjectValue attribute: `NpcReservedBy` (model name or nil).
Npc fields added: `LeftReason: string?`, `Thanked: boolean`, `_seat: Seats.Entry?`.
GetWaitingCustomers, `_assign` and the serve guards all require "AtCounter", so ToSeat/Seated NPCs are invisible to them.

## 5. Budget and population math
| Situation | Waiting/walking (pacing) | Seat phase | Max models |
|---|---|---|---|
| 1 barista | 2 | <= 8 | 10 |
| 12+ baristas | 16 (SERVER_CAP) | <= 8 | 24 |
| Rush Hour, 12+ | 20 (16 + RUSH_CAP_BONUS) | <= 8 | 28 |
Seat-phase NPCs run one thread each (1 s poll while seated), one looped AnimationTrack, one SeatWeld. Seated NPCs are welded to anchored furniture, so physics cost is near zero; the main cost is replication of animated rigs to clients.

## 6. Seat contract (Rigger authors; HARD-STOP 1a)
- Folder: `workspace.Assets.NPC.Seats` (class `Folder`), attribute `BuiltBy = "REVIVAL-001-BIG-B4-P2"`.
- Children: `ObjectValue`, Name "1".."n" (numbers, no gaps needed), `Value` = an existing `Seat` instance (class `Seat`; `VehicleSeat` is rejected), attribute `SitAnim` (string, exactly one of `BoothSit`, `CafeSit`, `ComfySit`, `CouchSit`), attribute `BuiltBy = "REVIVAL-001-BIG-B4-P2"`.
- Selection rule: ground-floor cafe seats within 80 studs of any `workspace.Assets.NPC.Counter` part. Furniture is not moved, renamed or edited.
- Runtime only (code, never authored): attribute `NpcReservedBy` on the ObjectValue.
- How code finds seats: `WorldPath.find(workspace, { "Assets", "NPC", "Seats" })` on the first claim while seating is on; children sorted by numeric Name; invalid children are skipped and listed in one warning.
- P2 carries the exact Rigger execute_luau script that builds the folder from `workspace.Assets.Seating` if Jack answers yes to HARD-STOP 1a; with "no", Jack names the seats and the Rigger builds the same ObjectValues by hand.
- Jack saves the place after the Rigger step (MCP cannot save, RIG-1).

## 7. SeatingConfig (canonical; P1 writes the whole file)
| Name | Value | Use |
|---|---|---|
| ENABLED | false | flag (D2) |
| SEATED_BUDGET | 8 | D4 |
| SIT_CHANCE | 0.8 | D6 |
| SEAT_MAX_DISTANCE_STUDS | 80 | D8 |
| SIT_SECONDS_MIN / SIT_SECONDS_MAX | 20 / 40 | D13 |
| SEAT_WALK_TIMEOUT_SECONDS | 8 | D11 |
| SEAT_ARRIVE_RADIUS_STUDS | 4 | D11 |
| SIT_CONFIRM_SECONDS | 0.5 | P3 sit check |
| SEAT_RETRY_COUNT | 1 | D12 |
| SEATED_POLL_SECONDS | 1 | P3 drink loop |
| STAND_STEP_STUDS | 2.5 | P3 stand-up |
| SIT_ANIMS | { "BoothSit", "CafeSit", "ComfySit", "CouchSit" } | D9 |
| SEATED_LINE_CHANCE / SEATED_LINE_DELAY_SECONDS | 0.5 / 6 | P4 |
| PATHFINDING | true | P4 |
| PATH_WAYPOINT_TIMEOUT_SECONDS | 3 | P4 |
| PATH_MAX_WAYPOINTS | 60 | P4 |
| STRESS_BARISTAS | 12 | P1 |
| STRESS_SERVE_AFTER_SECONDS | 4 | P1 |
All are tuning values marked `-- PROPOSED (tuning)`; none is an economy value, so no ECONOMY-LEDGER rows.

## 8. Perf gate (summary; full protocol in P1)
- Runs: A = seating off, B = seating on (B4SeatingForce), each for S1 (no rush, ceiling 24) and S2 (rush, ceiling 28), Studio Play, Studio stress hook (12 forced baristas, auto-serve after 4 s, no payout), 60 s warm-up + 180 s sample + drain.
- Pass (PROPOSED thresholds, B vs A same machine and session): heartbeat p95 +2.0 ms max, avg +1.0 ms max, physics step p95 +1.5 ms max, physics FPS avg -3 max, memory growth +40 MB max, seated max <= budget, drain to zero NPCs/reservations in 120 s, no new errors.
- PASS -> Prime sets `ENABLED = true`; P2/P3 become release_gate before. Perf-only FAIL -> run B2 (budget 4); pass -> `SEATED_BUDGET = 4`, `ENABLED = true`. Otherwise `ENABLED` stays false and B4 ships in the first update.

## 9. Function map (details in phases)
- Seats.luau (P2): `Resolve`, `PickNearest`, `SitSeconds`, `ShouldSit`, `StandCFrame`, `ClearWeld`, `new`, Pool `TryClaim`, `Release`, `Forget`, `BudgetUsed`, `ReservedCount`, `EntryCount`, `Close`.
- init.luau: P1 `_seatingOn`, `_seatBudget`, `_stressMode`, `_stressTick`; P2 `_ensureSeats`, context `TryClaimSeat`/`ReleaseSeat`, pacing subtraction, OnDestroyed Forget, BindToClose.
- Npc.luau: P2 types + `Npc.HasAnimation`; P3 `_moveTo`, `_seatPhase`, `_enterSeatPhase`, `_sitAt`, `_drink`, `_standUp`, Leave fields, `_run` tail; P4 `_pathTo`, `_holdProp`, `_dropProp`, seated line.
- CustomerDialogue.luau: P4 adds `Default.Seated`, `Karen.Seated` (lease: NPC-REACTIONS -> BIG-B4-P4).

## 10. Lease map for B4
| File | Writers |
|---|---|
| CustomerService/init.luau | ... PATIENCE-RAMP -> B4-P1 -> B4-P2 -> B4-P3 -> BIG-B5 |
| CustomerService/Npc.luau | NPC-REACTIONS -> B4-P2 -> B4-P3 -> B4-P4 -> BIG-B5 |
| CustomerService/Seats.luau (new) | B4-P2 -> B4-P3 (StandCFrame use only, no edit) |
| shared/Configuration/SeatingConfig.luau (new) | B4-P1 -> (Prime flag flip) -> B4-P4 (no edit planned) |
| server/Tests/Seats.spec.luau (new) | B4-P2 |
| shared/Configuration/CustomerDialogue.luau | NPC-REACTIONS -> B4-P4 (new edge, not in INVENTORY) |
| place: workspace.Assets.NPC.Seats | Rigger (B4-P2 part R) |
P4 must also land before BIG-B5 starts on Npc.luau.

## 11. Studio checks (union; each phase lists its own)
- P1: S1-S3 (stress hook, perf runs A).
- P2: S1-S4 (seat folder resolves, warning text, Rigger counts).
- P3: S1-S9 (sit, drink, leave, players, Karen, perf run B).
- P4: S1-S5 (line, pathing, prop, perf rerun).

## 12. Asset prerequisites
- `workspace.Assets.NPC.Seats` (contract section 6): missing -> one warning, seating off.
- `ReplicatedStorage.SharedStorage.NPCStorage.Animations.BoothSit|CafeSit|ComfySit|CouchSit` (class Animation): missing -> entries using it skipped.
- `ReplicatedStorage.SharedStorage.NPCStorage.Props.Drink` (Tool + Handle): missing -> no prop, one warning.

Open items:
- HARD-STOP 1a: Do NPCs use the existing Seat instances under `workspace.Assets.Seating` (legacy 34 table groups), with the Rigger building `workspace.Assets.NPC.Seats` from them per section 6 (yes/no)?
- HARD-STOP 1b: ComfySit and CouchSit share AnimationId 99196153493320 in RIG-1; keep as is (yes/no)?
- HARD-STOP 1c: Will Jack author a drink prop at `ReplicatedStorage.SharedStorage.NPCStorage.Props.Drink` (Tool with Handle) for seated NPCs (yes/no)?
- Studio: verify the four sit AnimationIds play (P3 S1).

## Summary
- Served, thanked NPCs (80%) claim the nearest free seat within 80 studs, sit 20-40 s with their sit animation, then walk out.
- Separate seat budget 8 (pacing counts `_npcCount - BudgetUsed()`); ceilings 24 normal, 28 Rush.
- Claim runs in the NPC's `_run` thread after the payout; `_onServeTriggered` is not edited; counter spots free first.
- New SeatingConfig.luau with `ENABLED = false`; Studio-only attributes drive perf runs A/B.
- Seats contract: `workspace.Assets.NPC.Seats` ObjectValues -> existing Seats, `SitAnim`, runtime `NpcReservedBy`.
- BLOCKED-ON-ASSET: seat folder (1a), sit anim ids (1b), drink prop (1c). P1 is buildable now.
- Cleanup: Forget on Destroy, Close on BindToClose, players never ejected.

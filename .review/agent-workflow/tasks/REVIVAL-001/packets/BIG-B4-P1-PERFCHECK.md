---
id: BIG-B4-P1-PERFCHECK
title: B4 phase 1 - SeatingConfig flag, Studio-only stress hook, perf-check protocol
priority: P1
role: Mason
worker_tier: sonnet
release_gate: before
depends_on: [PATIENCE-RAMP, NPC-REACTIONS]
status: READY
source_commit: 098175c
read_scope:
  - packets/BIG-B4.md (sections 3, 5, 7, 8)
  - src/server/Modules/CustomerService/init.luau (services/dependencies header, service table fields, _spawnIfNeeded, _pacingTarget, _pacingLoop, GetWaitingCustomers)
  - src/server/Tests/RunTests.server.luau (IsStudio + attribute precedent)
write_scope:
  - NEW src/shared/Configuration/SeatingConfig.luau
  - src/server/Modules/CustomerService/init.luau (requires, two fields, four new methods, one line in _pacingLoop, one condition in _pacingTarget)
invariants:
  - serve-path no-yield: _onServeTriggered is not edited. The stress hook runs in _pacingLoop only.
  - Outside Studio every new method returns nil/false/config value: RunService:IsStudio() guards every attribute read.
  - Stress serves never touch an assigned NPC (real tickets), never pay, never write stats.
  - With ENABLED false and no B4 attributes set, behaviour equals HEAD.
acceptance:
  - SeatingConfig.luau exists with every constant in "Exact numbers", ENABLED = false.
  - In Studio, workspace B4Stress = "Run" keeps ~16 NPCs flowing with nobody clocked in; NPCs at the counter leave as Served after 4 s; no BB, XP or stat changes.
  - B4Stress = "Drain" stops spawns and serves every counter NPC each tick until workspace.Customers is empty.
  - Live servers ignore all B4* attributes.
  - Prime records Run A (S1, S2) in perf.md with the format below.
checks:
  - "wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/shared/Configuration/SeatingConfig.luau src/server/Modules/CustomerService/init.luau'"
  - rojo build default.project.json -o <scratchpad>/out.rbxlx
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/BIG-B4-P1-PERFCHECK
forbidden: [WORKER-PRIMER 8, editing _onServeTriggered, Npc.luau, CustomerConfig.luau, RatingConfig.luau, any B4 seat behaviour (P2/P3)]
---

Primer: `_meta/WORKER-PRIMER.md`. Design: `BIG-B4.md`.

## Source excerpt
B4 (see BIG-B4.md section 1, verbatim). Recommendation: "phase 1 before release only if a Studio perf check is clean; otherwise in the first update." DEC-054 Q-G13: "B4 before release only if a Studio perf check is clean, otherwise first update; the B4 packet carries the perf-check protocol and fallback."

## Decisions made
- D1. New config module `SeatingConfig` (text below). `ENABLED = false` is the fallback: P2-P4 code checks it first, so a false value disables seating with zero code removal.
- D2. `CustomerService:_seatingOn(): boolean` = `SeatingConfig.ENABLED or (RunService:IsStudio() and workspace:GetAttribute("B4SeatingForce") == true)`. P2 calls it; P1 only adds it.
- D3. `CustomerService:_seatBudget(): number` = Studio-only numeric `B4SeatBudgetOverride` when it is a number >= 0, else `SeatingConfig.SEATED_BUDGET`.
- D4. `CustomerService:_stressMode(): string?` returns "Run" or "Drain" only in Studio when `workspace:GetAttribute("B4Stress")` equals that string; else nil.
- D5. `CustomerService:_stressTick(mode: string)` (non-yielding): in "Run" sets `self._baristas = math.max(self._baristas, SeatingConfig.STRESS_BARISTAS)`; then for each NPC from `GetWaitingCustomers()` with `AssignedUserId == nil`: records first-seen `os.clock()` in `self._stressSeen[npc]`; when `now - seen >= wait` (wait = STRESS_SERVE_AFTER_SECONDS in Run, 0 in Drain) clears the entry and calls `npc:Leave("Served", "Perfect")`. Drops `_stressSeen` entries whose NPC is Left. Then publishes `workspace` attributes `B4NpcCount = self._npcCount`, `B4SeatBudgetUsed = 0`, `B4SeatsReserved = 0`, `B4SeatEntries = 0` (P2 replaces the three zeros with pool values) and `B4SeatBudgetMax = math.max(existing or 0, B4SeatBudgetUsed)`.
- D6. `_pacingLoop` pcall body becomes: `self._baristas = self:_countBaristas()`, then `local stress = self:_stressMode()`, `if stress ~= nil then self:_stressTick(stress) end`, then `_spawnIfNeeded()`, `_assignAll()`. Drain leaves `_baristas` at the real count (0), so the pacing target is 0 and nothing spawns.
- D7. `_pacingTarget`: the rush branch condition becomes `self:IsRushHour() or (self:_stressMode() == "Run" and workspace:GetAttribute("B4StressRush") == true)`. Rationale: CafeRatingService republishes `RushHour`, so the test uses its own switch.
- D8. Stress serves skip pay on purpose: `Leave("Served", "Perfect")` fires `CustomerLeft` (not PatienceOut), `_onCustomerLeft` only clears a ticket that does not exist; no `CustomerResolved`, no currency, stats, quests or analytics.
- D9. Perf gate = protocol below. Prime runs it; workers never run Play (DEC-019).

## Exact numbers (SeatingConfig.luau, whole file)
```lua
--!strict
--[[
	SeatingConfig (REVIVAL-001 BIG-B4). Served NPCs sit and drink. Every value is
	TUNING -- PROPOSED (tuning); none is an economy value. ENABLED is the release
	fallback (DEC-054 Q-G13): false = seating off, behaviour as before B4.
--]]
local SeatingConfig = {
	ENABLED = false, -- set by the BIG-B4-P1 perf result
	SEATED_BUDGET = 8, -- NPCs in the seat phase at once (claim to despawn)
	SIT_CHANCE = 0.8,
	SEAT_MAX_DISTANCE_STUDS = 80,
	SIT_SECONDS_MIN = 20,
	SIT_SECONDS_MAX = 40,
	SEAT_WALK_TIMEOUT_SECONDS = 8,
	SEAT_ARRIVE_RADIUS_STUDS = 4,
	SIT_CONFIRM_SECONDS = 0.5,
	SEAT_RETRY_COUNT = 1,
	SEATED_POLL_SECONDS = 1,
	STAND_STEP_STUDS = 2.5,
	SIT_ANIMS = { "BoothSit", "CafeSit", "ComfySit", "CouchSit" },
	SEATED_LINE_CHANCE = 0.5,
	SEATED_LINE_DELAY_SECONDS = 6,
	PATHFINDING = true,
	PATH_WAYPOINT_TIMEOUT_SECONDS = 3,
	PATH_MAX_WAYPOINTS = 60,
	STRESS_BARISTAS = 12, -- Studio perf check only: PacingTarget(12) = 16
	STRESS_SERVE_AFTER_SECONDS = 4, -- Studio perf check only
}
return SeatingConfig
```
Each line keeps `-- PROPOSED (tuning)` in the worker's version where no comment is shown.

## Signatures and event names
- `function CustomerService:_seatingOn(): boolean`
- `function CustomerService:_seatBudget(): number`
- `function CustomerService:_stressMode(): string?`
- `function CustomerService:_stressTick(mode: string)`
- Field: `_stressSeen = {} :: { [Npc.Npc]: number }`.
- Requires: `local RunService = game:GetService("RunService")` (services block), `local SeatingConfig = require(Shared.Configuration.SeatingConfig)` (dependencies block).
- Workspace attributes (Studio only): inputs `B4Stress`, `B4StressRush`, `B4SeatingForce`, `B4SeatBudgetOverride`; outputs `B4NpcCount`, `B4SeatBudgetUsed`, `B4SeatsReserved`, `B4SeatEntries`, `B4SeatBudgetMax`.
- Npc.Leave(reason, grade) signature comes from NPC-REACTIONS (dependency).

## Perf-check protocol (Prime runs; Jack's machine; one Studio session)
Setup: place saved with P1 (Run A) or P1-P3 + seat folder (Run B). Nobody clocks in. Close other Studio windows. Stop and restart Play between runs.
Order: A-S1, A-S2, B-S1, B-S2 back to back in one session (Run A after P1 alone is a smoke test; the gate uses A runs repeated right before B). Each run ~6 min.
Scenario S1: `SCENARIO = "S1"` (ceiling 16 waiting + 8 seat phase = 24). S2: `"S2"` (rush ceiling 20 + 8 = 28).
Steps per run: `start_stop_play` (Play), wait 10 s, run the script below with `execute_luau` in the server DataModel (if the tool targets Edit, paste it in the Command Bar with the Server view), wait ~6.5 min, `get_console_output`, copy the `B4PERF_SUMMARY` and `B4PERF_DRAIN` lines and every distinct `[CustomerService]` line into perf.md, stop Play.

```lua
-- B4PERF v1 (BIG-B4-P1-PERFCHECK). Server DataModel, Studio Play.
local RUN = "A" -- "A" seating off | "B" seating on | "B2" seating on, budget 4
local SCENARIO = "S1" -- "S1" no rush | "S2" rush
local WARMUP, SAMPLE, DRAIN_LIMIT = 60, 180, 120
local Stats = game:GetService("Stats")
local Http = game:GetService("HttpService")
workspace:SetAttribute("B4SeatingForce", RUN ~= "A")
workspace:SetAttribute("B4SeatBudgetOverride", if RUN == "B2" then 4 else nil)
workspace:SetAttribute("B4StressRush", SCENARIO == "S2")
workspace:SetAttribute("B4SeatBudgetMax", 0)
workspace:SetAttribute("B4Stress", "Run")
local function avg(t) local s = 0 for _, v in t do s += v end return if #t > 0 then s / #t else 0 end
local function p95(t) local c = table.clone(t) table.sort(c) return c[math.max(1, math.ceil(#c * 0.95))] or 0 end
local function mx(t) local m = -math.huge for _, v in t do m = math.max(m, v) end return if #t > 0 then m else 0 end
local function mn(t) local m = math.huge for _, v in t do m = math.min(m, v) end return if #t > 0 then m else 0 end
local function census()
	local f, n, s = workspace:FindFirstChild("Customers"), 0, 0
	if f then for _, m in f:GetChildren() do n += 1 local st = m:GetAttribute("State") if st == "ToSeat" or st == "Seated" then s += 1 end end end
	return n, s
end
task.spawn(function()
	task.wait(WARMUP)
	local hb, ph, fps, npcs, seated = {}, {}, {}, {}, {}
	local mem0 = Stats:GetTotalMemoryUsageMb()
	local anim0 = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Animation)
	local t0 = os.clock()
	while os.clock() - t0 < SAMPLE do
		task.wait(1)
		table.insert(hb, Stats.HeartbeatTimeMs) table.insert(ph, Stats.PhysicsStepTimeMs)
		table.insert(fps, workspace:GetRealPhysicsFPS())
		local n, s = census() table.insert(npcs, n) table.insert(seated, s)
	end
	local mem1 = Stats:GetTotalMemoryUsageMb()
	print("B4PERF_SUMMARY " .. Http:JSONEncode({ v = 1, run = RUN, scenario = SCENARIO, samples = #hb,
		hbAvg = avg(hb), hbP95 = p95(hb), hbMax = mx(hb), physAvg = avg(ph), physP95 = p95(ph),
		physFpsAvg = avg(fps), physFpsMin = mn(fps), memStartMb = mem0, memEndMb = mem1, memDeltaMb = mem1 - mem0,
		animMemDeltaMb = Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.Animation) - anim0,
		npcsMax = mx(npcs), npcsAvg = avg(npcs), seatedMax = mx(seated),
		budgetMax = workspace:GetAttribute("B4SeatBudgetMax") or 0, entries = workspace:GetAttribute("B4SeatEntries") or 0 }))
	workspace:SetAttribute("B4Stress", "Drain")
	local d0 = os.clock()
	while os.clock() - d0 < DRAIN_LIMIT and (census()) > 0 do task.wait(1) end
	print("B4PERF_DRAIN " .. Http:JSONEncode({ v = 1, run = RUN, scenario = SCENARIO, seconds = os.clock() - d0,
		leftover = (census()), reserved = workspace:GetAttribute("B4SeatsReserved") or 0,
		budgetUsed = workspace:GetAttribute("B4SeatBudgetUsed") or 0, memEndMb = Stats:GetTotalMemoryUsageMb() }))
	for _, k in { "B4Stress", "B4StressRush", "B4SeatingForce", "B4SeatBudgetOverride" } do workspace:SetAttribute(k, nil) end
end)
print("B4PERF started", RUN, SCENARIO)
```

Thresholds (PROPOSED; B compared with the A run of the same scenario):
- T1 hbP95(B) - hbP95(A) <= 2.0 ms. T2 hbAvg(B) - hbAvg(A) <= 1.0 ms.
- T3 physP95(B) - physP95(A) <= 1.5 ms. T4 physFpsAvg(B) >= physFpsAvg(A) - 3.
- T5 memDeltaMb(B) - memDeltaMb(A) <= 40.
- T6 npcsMax(B) <= 24 (S1) / 28 (S2); seatedMax and budgetMax <= active budget (8, or 4 for B2).
- T7 validity: B needs seatedMax >= 4 and entries > 0, else the run is INVALID (report BLOCKED: seats or animations missing), not FAIL.
- T8 drain: leftover 0, reserved 0, budgetUsed 0, seconds <= 120.
- T9 console: no errors or stack traces; `[CustomerService]` warnings only the known once-warnings (list them).
Result rule: all T pass for S1 and S2 -> PASS: Prime sets `ENABLED = true` (one line) and marks P2/P3 release_gate before. Only T1-T5 fail -> run B2-S2 once; pass -> PASS-REDUCED: `SEATED_BUDGET = 4`, `ENABLED = true`. Anything else -> FAIL: `ENABLED` stays false, B4 ships in the first update; T6/T8/T9 failures go back to the worker as bugs.

Evidence format: `.review/agent-workflow/tasks/REVIVAL-001/BIG-B4-P1-PERFCHECK/perf.md`; line 1 `RESULT: PASS|PASS-REDUCED|FAIL|BLOCKED`; then machine + Studio version + date; then this table with one row per run:
`| run | scenario | hbAvg | hbP95 | physP95 | physFpsAvg | memDelta | npcsMax | seatedMax | budgetMax | drain s | leftover | T1-T9 |`
then the raw `B4PERF_SUMMARY`/`B4PERF_DRAIN` lines, the distinct warnings, and the resulting `ENABLED`/`SEATED_BUDGET` values.

## Studio checks (Jack/Prime, batched)
- S1: Play, set `workspace.B4Stress = "Run"`: NPCs keep spawning to ~16 with nobody clocked in; each NPC at a counter leaves after ~4 s with a served line; BobaBucks unchanged.
- S2: Set `B4Stress = "Drain"`: no new spawns; workspace.Customers empties within 60 s (seating off).
- S3: Perf Run A S1 and S2 recorded in perf.md (smoke).

## Asset prerequisites
None for P1. Run B needs P2 + P3 + `workspace.Assets.NPC.Seats` (BIG-B4 section 6).

Open items: none (perf Run B waits on P3; see BIG-B4 open items)

## Summary
- New SeatingConfig.luau (ENABLED = false) is the Q-G13 fallback flag; P2-P4 read it.
- init.luau gains Studio-only `_seatingOn`, `_seatBudget`, `_stressMode`, `_stressTick` and two one-line hooks.
- Stress: 12 forced baristas, auto-serve unassigned counter NPCs after 4 s, no pay; Drain empties the cafe.
- Exact execute_luau script samples heartbeat, physics, memory, NPC and seated counts; prints JSON lines.
- PROPOSED thresholds T1-T9; PASS sets ENABLED true, PASS-REDUCED sets budget 4, else first update.
- Serve path untouched; live servers ignore every B4* attribute.

---
id: ONBOARD-FIRSTRUN
title: First-run: Daily reward waits for the first serve; one-time welcome toast at clock-in for a new profile
priority: P1
role: Mason
worker_tier: haiku-ok
release_gate: before
depends_on: [GAMEPLAY-PROGRESS-CALLOUTS, GAMEPLAY-TOASTS]
status: READY
source_commit: 098175c
read_scope: [src/client/Modules/DailyRewardController.luau, src/client/Modules/AreaController.luau, src/client/Modules/AppDialogs.luau (DialogController:Toast and DialogController.new only), src/server/Modules/DailyRewardService.luau (GetRewardStatus return shape only), src/shared/Configuration/ProfileTemplate.luau (Statistics table only), src/shared/UI/Components/Core/Hud/SmallNotification.luau (the IdleFor export from GAMEPLAY-TOASTS step 8, read only)]
write_scope: [src/client/Modules/DailyRewardController.luau, src/client/Modules/AreaController.luau]
invariants: [client-only; no serve path touched (the client only listens to Statistics and ClockedIn replication); no server file touched; no profile field added or renamed; DEC-013 (toast only, existing DialogController:Toast); existing profiles with CustomersServed > 0 keep today's Daily behaviour]
acceptance: [a claimable Daily dialog for a profile with CustomersServed == 0 does not open at join, it opens the first time CustomersServed becomes greater than 0 in the session and only after the toast panel has been idle for 1 s (so it never covers the first-order toast), a profile with CustomersServed > 0 at join opens it as before, the welcome toast text is exact, the welcome toast shows at most once per session and only while Statistics.ShiftsCompleted == 0, gate passes with no new Selene or StyLua findings in the two files]
checks: [scripts/gate.sh src/client/Modules/DailyRewardController.luau src/client/Modules/AreaController.luau, rojo build default.project.json -o <scratchpad>/rojo-firstrun.rbxl]
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/ONBOARD-FIRSTRUN
forbidden: [see WORKER-PRIMER section 8, editing DailyRewardService.luau, changing the Daily reward content or the claim path, changing the gate logic in AreaController (OPEN_LEVEL, BreakGates), adding a sound, adding chat text]
---

Rules: [WORKER-PRIMER](_meta/WORKER-PRIMER.md). Gate and evidence rules are there and are not repeated here.

## Source excerpt
O2 (review, HEAD c77e20c)
- What: Daily after the first serve for profiles with CustomersServed == 0
- Why: The gift lands better after the first success; the first screen becomes play
- Files: DailyRewardController.luau
- Effort: XS
- Risk: Low
- Tag: JACK

O3 (review, HEAD c77e20c)
- What: Welcome line: a one-time toast at clock-in for a new profile, "Welcome to Boba Cafe! Follow the gold glow to make your first drink."
- Why: One sentence of framing; chat-free
- Files: client
- Effort: XS
- Risk: Low
- Tag: OBVIOUS

## Decisions made
- D1 (O2): When `GetRewardStatus` says `CanClaim == true`, the Daily dialog opens only once `playerData.Statistics.CustomersServed` is greater than 0. Rationale: Q-G3 family (Jack): Daily after the first serve for CustomersServed == 0.
- D2 (O2): The check reads the replicated profile through the existing `DataController:GetDataAsync()` promise and `playerData:ListenToChange({ "Statistics", "CustomersServed" }, fn)`. Rationale: the Statistics table is already client-readable (Pages/Menu/Statistics.luau:145 reads `playerData.Statistics[...]`).
- D3 (O2): Once the dialog has opened it cannot open twice in the session (the existing `isDialogOpen` guard plus a local `opened` flag). Rationale: a second open would repeat the gift.
- D10 (FEEDBACK-VOICE 7, FIRST-5-MIN): every Daily open, first-serve or not, waits for the toast drain plus 1 s: after the trigger wait `DAILY_DRAIN_SECONDS` (1), then poll every 0.5 s until `SmallNotification.IdleFor() >= DAILY_DRAIN_SECONDS`, giving up after `DAILY_WAIT_MAX_SECONDS` (60) and opening anyway. `IdleFor()` (added by GAMEPLAY-TOASTS step 8) counts all toasts, which is stricter than tiers 1-2 and acceptable until the queue has a priority field. Rationale: the modal used to cover the first-order toast.
- D11 (FIRST-5-MIN): the welcome is the only beat in the first 3 s after clock-in; it is evaluated on the ClockedIn change and nothing else is added there. The welcome text is a SOUNDS contract and must not change.
- D4 (O2): The claim path, the reward data and `DailyRewardService` are unchanged. Rationale: the change is when the dialog shows, not what it grants.
- D5 (O3): The welcome toast is `DialogController:Toast(WELCOME_TEXT)` (plain text toast, existing API). Rationale: the excerpt says "toast", chat-free.
- D6 (O3): Trigger: the toast is evaluated at KnitStart and on every change of the `ClockedIn` attribute to `true`. It fires only if `Statistics.ShiftsCompleted == 0` and it has not fired this session. Rationale: "one-time ... for a new profile"; the first shift is the onboarding window (ShiftsCompleted becomes 1 when the first shift ends).
- D7 (O3): The welcome logic lives in AreaController because the excerpt names that file, and it runs before the gate wait so the gate wait cannot delay it. Rationale: the excerpt's file list; the gate code is unchanged.
- D8 (O3): "once per session" is a module-level local, not a profile field and not browser storage. Rationale: no profile change; a new session may show the toast again only while ShiftsCompleted is still 0.

## Exact strings
- Welcome toast: `Welcome to Boba Cafe! Follow the gold glow to make your first drink.`

## Exact numbers and names
- `local WELCOME_TEXT = "Welcome to Boba Cafe! Follow the gold glow to make your first drink."`
- `local CLOCKED_IN_ATTRIBUTE = "ClockedIn"` (same name ShiftService.luau uses)
- Statistics keys: `CustomersServed`, `ShiftsCompleted` (both in ProfileTemplate Statistics)

## Signatures and insertion points (anchor by symbol)
### DailyRewardController.luau
1. Add `local DAILY_DRAIN_SECONDS, DAILY_WAIT_MAX_SECONDS = 1, 60` and `local SmallNotification = require(<UI>.Components.Core.Hud.SmallNotification)` (match the file's existing require style) and a local function above `DailyRewardController:KnitStart`:
```
local function openWhenFirstServed(self, status)
	Knit.GetController("DataController"):GetDataAsync():andThen(function(playerData)
		local opened = false
		local function tryOpen(served)
			if opened or typeof(served) ~= "number" or served <= 0 then
				return
			end
			opened = true
			task.spawn(function()
				task.wait(DAILY_DRAIN_SECONDS)
				local waited = 0
				while SmallNotification.IdleFor() < DAILY_DRAIN_SECONDS and waited < DAILY_WAIT_MAX_SECONDS do
					task.wait(0.5)
					waited += 0.5
				end
				self:OpenDailyRewards(status)
			end)
		end
		local stats = playerData.Statistics
		tryOpen(if stats then stats.CustomersServed else nil)
		playerData:ListenToChange({ "Statistics", "CustomersServed" }, tryOpen)
	end)
end
```
2. In `DailyRewardController:KnitStart`, replace the line `self:OpenDailyRewards(status)` (inside `if status.CanClaim == true then`) with `openWhenFirstServed(self, status)`. Everything else in the polling loop is unchanged.

### AreaController.luau
1. Constants block (after `TEMPLATE_NAME`): add
```
local CLOCKED_IN_ATTRIBUTE = "ClockedIn" -- owned by ShiftService
local WELCOME_TEXT = "Welcome to Boba Cafe! Follow the gold glow to make your first drink."
```
2. Above `function AreaController:KnitStart()`, add a module-level `local welcomeShown = false` and:
```
local function tryWelcome()
	if welcomeShown or LocalPlayer:GetAttribute(CLOCKED_IN_ATTRIBUTE) ~= true then
		return
	end
	Knit.GetController("DataController"):GetDataAsync():andThen(function(playerData)
		if welcomeShown or LocalPlayer:GetAttribute(CLOCKED_IN_ATTRIBUTE) ~= true then
			return
		end
		local stats = playerData.Statistics
		if not stats or stats.ShiftsCompleted ~= 0 then
			return
		end
		welcomeShown = true
		Knit.GetController("DialogController"):Toast(WELCOME_TEXT)
	end)
end
```
3. Inside `function AreaController:KnitStart()`, as the FIRST statements (before `WorldPath.waitFor`), add:
```
LocalPlayer:GetAttributeChangedSignal(CLOCKED_IN_ATTRIBUTE):Connect(tryWelcome)
tryWelcome()
```
   The existing gate code after them is unchanged.

## UI spec
- None beyond the existing toast (SmallNotification via DialogController:Toast). No new visual.

## Studio checks (batched by Prime for Jack)
- S1: New profile joins. Expected: after the join settles, the welcome toast reads "Welcome to Boba Cafe! Follow the gold glow to make your first drink." once.
- S2: Clock Out, then Clock In in the same session (before the first shift ends). Expected: no second welcome toast.
- S3: New profile, claimable Daily reward. Expected: no Daily dialog at join.
- S4: Serve the first customer. Expected: the serve and first-order toasts finish, then about 1 s later the Daily dialog opens (only if claimable); it never covers a toast.
- S5: Existing profile with CustomersServed > 0 and a claimable Daily reward. Expected: the Daily dialog opens at join as today.
- S6: Existing profile whose first shift is complete (ShiftsCompleted > 0). Expected: no welcome toast at clock-in.

## Asset prerequisites
- None. Toast text only.

Open items: none

## Summary
- Daily reward dialog waits until CustomersServed > 0 in the session (client listens to Statistics; no server change).
- Welcome toast: one per session, only while ShiftsCompleted == 0, on clock-in; exact copy in WELCOME_TEXT.
- Files: DailyRewardController.luau and AreaController.luau only.
- No profile field, no server file, no sound.
- Depends on GAMEPLAY-PROGRESS-CALLOUTS (same AreaController.luau).
- Gate: scripts/gate.sh on both files; rojo build.
- Runtime behaviour is unverified until Studio checks S1-S6 run.

---
id: SOUNDS
title: Client sound cues (serve chime with combo pitch, step tick, Rush start, level-up, toast sounds)
priority: P1
role: Mason
worker_tier: sonnet
release_gate: before
depends_on: [GAMEPLAY-TOASTS, NOTIF-HINTS, GAMEPLAY-MOBILE-TICKET, TICKET-RECIPE-LINK, RUSH-BANNER, HUD-LEVELBAR, SERVE-FEEDBACK, GAMEPLAY-QUEST-NUDGES]
status: READY
source_commit: 098175c
read_scope:
  - src/client/Modules/AppDialogs.luau (playUiSound)
  - src/client/Modules/OrderController.luau (KnitStart)
  - src/shared/UI/Components/Core/Hud/OrderTicket.luau (OrderTicket component, React.useEffect block)
  - src/shared/UI/Components/Core/Hud/CafeRating.luau (refresh)
  - src/shared/UI/Components/Core/Hud/SmallNotification.luau (animation thread, "optional sound" comment)
  - src/shared/UI/Components/Core/Hud/LevelBar.luau (as left by HUD-LEVELBAR)
  - src/shared/Ordering/OrderSpec.luau (OrderSpec.Steps, OrderSpec.StepState)
write_scope:
  - NEW src/shared/UI/Utility/UiSfx.luau
  - NEW src/server/Tests/UiSfx.spec.luau (written, not run)
  - src/client/Modules/AppDialogs.luau (playUiSound body only)
  - src/client/Modules/OrderController.luau (KnitStart, add one connection)
  - src/shared/UI/Components/Core/Hud/OrderTicket.luau (requires + one effect)
  - src/shared/UI/Components/Core/Hud/CafeRating.luau (requires + refresh)
  - src/shared/UI/Components/Core/Hud/LevelBar.luau (Level listener only)
  - src/shared/UI/Components/Core/Hud/SmallNotification.luau (sound at show time)
invariants:
  - Client only. No server file, no serve-path code (serve-path no-yield rule not touched; the chime reacts to the toast signal after payout).
  - A missing sound never errors, blocks play or hides a result (WORKER-PRIMER 5, DEC-008). No substitute sound is built.
  - DEC-013: no visual change except the LevelBar gold flash that HUD-LEVELBAR already defines.
  - No new SoundService content is created by this packet; Jack authors it.
acceptance:
  - UiSfx.Play looks up SoundService.SFX.UI.<Name> (fallback SoundService.UISounds.<Name>), returns false silently when missing, warns once per name.
  - Serve toast plays Serve at PlaybackSpeed 1.0 + 0.05 per combo step above 1, capped at 1.25.
  - StepDone, Rush, LevelUp (then Success), Pop1 and Success cues fire exactly where D5..D9 say, and nowhere else.
  - Gate shows no new findings; rojo build succeeds.
checks: ["gate on every changed file (WORKER-PRIMER 2)", "rojo build default.project.json -o <outside repo>"]
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/SOUNDS
forbidden: [WORKER-PRIMER 8, editing ActionPrompt.luau or DailyRewardsBody.luau (their private playUiSound stays), any server file, creating Sound instances]
---

## Source excerpt (verbatim)
- S2: What: Serve sound: a coin/cash chime on the client when your ticket clears after a serve; combo raises PlaybackSpeed per step (x1.0 to x1.25). Why: Sound is the cheapest satisfaction multiplier; rising pitch makes a streak felt. Files: client (OrderController TicketChanged clear or a toast hook); needs SoundService.SFX.UI.Serve authored by Jack/Rigger. Effort: S + Studio. Risk: Low.
- T3: What: Step-done tick: a soft sound when a step completes (glyph turns check). Why: Micro-reward per action; makes the 20-30 s build feel like progress. Files: client, OrderTicket attribute listener; needs SFX.UI.StepDone. Effort: XS + Studio. Risk: Low.
- X2: What: Rush start fanfare (sound + toast "Rush Hour! 2x pay for 2 minutes!"; the toast already exists, the sound needs authoring). Why: Peak excitement beat. Files: client; SFX.UI.Rush. Effort: XS + Studio. Risk: Low.
- P6: What: Level-up moment: the level-up toast gets the SFX.UI.Success sound, plus a gold flash on the HUD level pill (with P4). Why: The level-up should be the best feeling in the game. Files: client. Effort: XS. Risk: Low.
- N5: What: Toast sound (SoundEnabled = true plays SFX.UI.Pop1) only for level-up, combo milestones and quest complete. Why: Audio priority for the big beats. Files: SmallNotification.luau. Effort: XS. Risk: Low.

## Decisions made
- D1 One helper, `UiSfx` in `src/shared/UI/Utility/UiSfx.luau` (shared so both HUD components and client controllers can require it). Rationale: Hud components live in shared and cannot require client modules.
- D2 `UiSfx.Play` plays a CLONE of the authored Sound (so rapid cues overlap instead of restarting), parented to SoundService, destroyed on `Ended` and by Debris after 5 s. If the clone has no SoundGroup and `SoundService.UISounds` is a SoundGroup, assign it, so the Settings SFX toggle (SettingsConfig, FIX-SOUNDGROUPS) mutes every new cue.
- D3 `AppDialogs.playUiSound(name)` body becomes `UiSfx.Play(name)`. Rationale: reuse, one lookup path. ActionPrompt and DailyRewardsBody keep their private copies (outside this lease).
- D4 Volumes are multipliers on the authored Sound.Volume: Serve 1.0, StepDone 0.6, Rush 1.0, LevelUp 1.0, Success 1.0, Pop1 0.8. Rationale: ticks stay below the chime; Jack tunes the base volume in Studio.
- D5 Serve chime (S2): `OrderController:KnitStart` adds a second listener on `Knit.GetService("DialogService").NotificationSignal`. Text of a payload = `n.Text` if a non-empty string, else `(n.Title or "") .. " " .. (n.Description or "")`. When the text starts with `Order served!`, take N = `tonumber(string.match(text, "Combo ×(%d+)"))` (nil counts as 1) and play `Serve` at speed `1 + 0.05 * math.clamp(N - 1, 0, 5)`. Walkout, wrong-drink, rescue and real-customer toasts play nothing. Rationale: the toast is the only client signal that distinguishes a serve from a walkout; it fires after the payout; the 6 combo steps map to 1.00, 1.05 .. 1.25.
- D6 Step tick (T3): in `OrderTicket`, one new effect keyed on `{ spec, toolAttrs, toolInst }` (first ticket only, never `isSecond`). `current = OrderSpec.StepState(spec, toolAttrs)`, `done = math.clamp(current - 1, 0, #OrderSpec.Steps(spec))`. Play `StepDone` only when `done` is greater than the previous `done`, the previous `spec` is the same table, and `toolInst` equals the previous `toolInst` and is not nil. Rationale: re-equipping a half-built drink or a new order must not tick; only progress on the held tool does.
- D7 Rush start (X2): in `CafeRating` `refresh`, play `Rush` when RushHour goes false to true after mount and the local player's `ClockedIn` attribute is not false. Never on join into an ongoing Rush. Rationale: matches the toast moment, no surprise sound off shift.
- D8 Level-up (P6): `LevelBar` listens to the local player's `Level` attribute; on an increase over the last seen value (not on first read) it calls `LevelBar.Flash()` (defined by HUD-LEVELBAR) and plays `UiSfx.Play({ "LevelUp", "Success" })`. The level-up toast itself is silent: SmallNotification returns no sound for text starting `Level up!` (D9). Rationale: one owner for the sound, aligned with the flash and not delayed by the toast queue.
- D9 Toast sounds (N5): at the start of the show thread (the `-- optional sound` comment), SmallNotification picks a cue from the normalised `Data.Text`, in this order: starts `Level up!` gives none; starts `Quest claimed!` gives `Success`; starts `Quest complete:` gives `Pop1`; contains `completed the Team Combo!` (the named text from SERVE-FEEDBACK) or starts `Team Combo!` gives `Pop1`; starts `Your first order!` gives `Success`; starts `Combo ×N` with N in {3, 5, 10} gives `Pop1`; `Data.SoundEnabled` is ignored; anything else gives none. Hints, welcome, capsule nudge, halfway ping, banners and every other toast stay silent (FEEDBACK-VOICE 4). Delete the commented SoundProvider block.
- D10 Missing sound: `UiSfx` warns once per name `[UiSfx] SoundService.SFX.UI.<Name> not found; cue skipped.` and returns false. Rate limit: ignore a repeat of the same name within 0.05 s, and ignore any cue other than `Serve` that starts within 0.15 s of the previous cue (no two sounds within 150 ms; Serve always plays).
- D11 Real-customer pick-up toasts and the serve toast text owned by SERVE-FEEDBACK keep the `Order served!` prefix and `Combo ×N` fragment; this packet depends on that contract and does not edit the text.

## Exact strings
- Warn: `[UiSfx] SoundService.SFX.UI.%s not found; cue skipped.`
- Text matched (plain, case-sensitive): prefixes `Order served!`, `Level up!`, `Quest claimed!`, `Quest complete:`, `Your first order!`, `Team Combo!`; fragment `completed the Team Combo!`; combo pattern `Combo ×(%d+)` (the character is U+00D7, copy from CustomerService `_onServeTriggered`).

## Exact numbers
- SPEED_BASE 1.0, SPEED_STEP 0.05, SPEED_MAX 1.25, COMBO_STEPS_MAX 5 (N=6 reaches 1.25).
- Volume multipliers: Serve 1.0, StepDone 0.6, Rush 1.0, LevelUp 1.0, Success 1.0, Pop1 0.8.
- MIN_REPEAT_SECONDS 0.05; MIN_GAP_SECONDS 0.15 (all cues except Serve); DEBRIS_SECONDS 5; milestone set exactly {3, 5, 10}.

## Signatures and insertion points
- `UiSfx.Play(names: string | { string }, options: { Speed: number, Volume: number } | nil): boolean` and `UiSfx.Find(name: string): Sound | nil`. Lookup: `WorldPath.find(SoundService, { "SFX", "UI", name }) or WorldPath.find(SoundService, { "UISounds", name })`, accept only `IsA("Sound")`. `Play` with a list tries each name in order and plays the first found.
- `UiSfx.ServeSpeed(comboN: number | nil): number` returns `SPEED_BASE + SPEED_STEP * math.clamp((comboN or 1) - 1, 0, 5)`. Pure, so a spec can test it.
- `UiSfx.IsComboMilestone(n: number): boolean`. Pure.
- OrderController: inside `KnitStart`, after the `OrderService.QueueUpdated:Connect` block, add the NotificationSignal connection (D5).
- OrderTicket: add `local UiSfx = require(UI.Utility.UiSfx)` beside the other requires; add `local lastStep = React.useRef({ spec = nil, tool = nil, done = 0 })` and the D6 effect directly after the `React.useEffect(... { character })` effect, still inside `if RunService:IsRunning() then`, before `if not order then return nil end`.
- CafeRating: add the `UiSfx` require; declare `local lastRush = workspace:GetAttribute("RushHour") == true` immediately before `local function refresh()`; in `refresh` compute `local rushNow = workspace:GetAttribute("RushHour") == true`, play on `rushNow and not lastRush and player:GetAttribute("ClockedIn") ~= false`, then `lastRush = rushNow`. Keep the existing `setRush` line. If RUSH-BANNER renamed these, anchor by the `RushHour` attribute listener.
- LevelBar: add one `React.useEffect(..., {})` that connects `Players.LocalPlayer:GetAttributeChangedSignal("Level")`, keeps `lastLevel` in a local, and runs D8 on an increase. If HUD-LEVELBAR already compares levels to call Flash, add only the `UiSfx.Play` line there. If `LevelBar.Flash` does not exist, stop and report BLOCKED with the file read.
- SmallNotification: add a local `soundFor(data): { string } | nil` and call it where the commented block sits; the code uses `activeEntry.Data` (TOASTS may have renamed the entry variable; use whatever the thread already reads).
- Spec (written, not run): `src/server/Tests/UiSfx.spec.luau` requiring the shared module, covering ServeSpeed (nil to 1.0, 2 to 1.05, 6 to 1.25, 20 to 1.25) and IsComboMilestone (2 false, 3 true, 4 false, 5 true, 10 true, 11 false, 15 false).

## Studio checks (batched by Prime)
- S1 With no sound authored: serve a customer, tick a step, level up. Expect no error and exactly one output warn per missing name.
- S2 With SFX.UI.Serve present: serve 1 Perfect (speed 1.0), then 3 Perfects in a row; pitch rises each serve; a Close serve resets the pitch.
- S3 Hold the order cup and add a step: StepDone ticks once per completed step; drop and re-pick the half-built cup: no tick.
- S4 Trigger Rush Hour while clocked in: Rush plays once; join a server already in Rush: silent; clocked out: silent.
- S5 Level up: LevelUp (else Success) plays once with the gold flash, and the toast makes no extra sound.
- S6 Complete a quest: Pop1 on the toast; claim it: Success. Reach Combo x3: Pop1 on the combo toast. First serve of a new profile: Serve chime, then Success on the first-order toast. Team Combo toast: Pop1. Hints, welcome and capsule nudge stay silent.
- S7 Settings SFX off: every new cue is silent.

## Asset prerequisites (go to ASSET-REQUESTS)
Jack authors under `SoundService.SFX.UI` with `SoundGroup = SoundService.UISounds`: `Serve` (coin/cash chime, short, tolerates speed up to 1.25), `StepDone` (soft tick), `Rush` (fanfare), `LevelUp` (best cue; until it exists Success plays). Existing and reused: `Pop1`, `Success` (verify both exist in `SFX.UI`). Missing ones skip silently.

Open items: none

## Summary
- New shared helper UiSfx (SFX.UI lookup, UISounds fallback, clone-play, warn-once, silent skip); AppDialogs.playUiSound delegates to it.
- Serve chime from the serve toast, pitch 1.00 to 1.25 in 0.05 steps over combo; step tick on held-tool progress; Rush on RushHour rising edge.
- Level-up sound and flash live in LevelBar (Level attribute rise); level-up toast stays silent; quest claim uses Success; combo milestone, Team Combo and quest complete use Pop1; first order uses Success; no two cues within 150 ms except Serve.
- Sound names to request in ASSET-REQUESTS: Serve, StepDone, Rush, LevelUp (new, SFX.UI); Pop1, Success (verify exist).
- Leases: writes OrderController, OrderTicket, CafeRating, LevelBar, SmallNotification, AppDialogs last in their chains; new file UiSfx.luau and a server-side spec.
- Extra dependency edges vs INVENTORY: SERVE-FEEDBACK and GAMEPLAY-QUEST-NUDGES (toast text contracts).

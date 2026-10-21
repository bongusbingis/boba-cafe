---
id: SHIFT-END
title: Shift end - personal bests (H3) and capsule-affordable nudge (H4)
priority: P2
role: Mason
worker_tier: sonnet
release_gate: before
depends_on: [GAMEPLAY-PROGRESS-CALLOUTS]
status: READY
source_commit: 098175c
read_scope:
  - src/server/Modules/ShiftService.luau (ShiftState, newState, _beginShift, _readCompleted, _endShift)
  - src/shared/Configuration/ProfileTemplate.luau
  - src/shared/Configuration/InventoryItemDefinitions/Capsules.luau (read only; Price is a string such as " 75")
  - src/shared/UI/Components/Core/Hud/ShiftCard.luau (buildLines)
  - src/server/Tests/ShiftService.spec.luau
  - src/server/Modules/DialogService.luau (Notify), src/server/Modules/CapsuleService.luau (:318 price parse pattern)
write_scope:
  - src/server/Modules/ShiftService.luau
  - src/shared/Configuration/ProfileTemplate.luau (add two top-level fields, nothing else)
  - src/shared/UI/Components/Core/Hud/ShiftCard.luau (buildLines only)
  - src/server/Tests/ShiftService.spec.luau (new cases only)
invariants:
  - DEC-013: ShiftCard keeps its geometry, row style and the 6-row cap; no new component.
  - The ShiftEnding listener chain and _endShift summary build stay synchronous. No GetDataAsync, WaitForChild or task.wait before `self.Client.ShiftEnded:Fire`.
  - Serve-path no-yield rule (WORKER-PRIMER 1): ShiftService:RecordCustomer runs after the CustomerService payout. This packet adds only arithmetic to it (none required); all profile reads and writes run in task.spawn wrapped in pcall after the summary is sent.
  - Profile change is add-only (HARD STOP 2 respected). ProfileStore name is not bumped; Reconcile fills the new fields.
  - Prices unchanged (HARD STOP 3/4); the capsule price is read from definitions, never typed.
acceptance:
  - ProfileTemplate has top-level `BestCombo = 0` and `BestShiftPay = 0` plus type entries.
  - Summary carries `NewBestCombo: boolean` and `NewBestShiftPay: boolean`; ShiftCard shows the two lines inside the 6-row cap.
  - Stored bests rise only when exceeded; a first-ever shift (previous best 0) shows no "new best" line.
  - One capsule toast per session when BobaBucks >= cheapest capsule price from definitions, shown after the nickname prompt closes when one is pending (NicknamePending).
checks:
  - wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/server/Modules/ShiftService.luau src/shared/Configuration/ProfileTemplate.luau src/shared/UI/Components/Core/Hud/ShiftCard.luau src/server/Tests/ShiftService.spec.luau' (stylua only on files with no DEC-001 drift)
  - rojo build default.project.json -o <path outside the repo>
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/SHIFT-END
forbidden: [WORKER-PRIMER 8, editing Statistics or any existing profile field, editing Capsules.luau or any price, hardcoding 75, adding a button or new row to ShiftCard, running Play or TestEZ]
---

Rules: see `_meta/WORKER-PRIMER.md`. Idea review text below is verbatim.

## 1. Source excerpt
- H3 (review, HEAD c77e20c): What: Personal bests: "New best combo!" / "Best shift ever!" lines with a stored best. Why: Self-competition, cheap. Files: profile fields (ProfileTemplate add = safe), ShiftService. Effort: S. Risk: Low. Tag: JACK (new profile fields).
- H4 (review, HEAD c77e20c): What: Shift-end CTA ("Open a capsule" when affordable) as one PromptButton on the card, or a toast. Why: The plan's "Next shift / Open a capsule" CTA; converts BB into the meta loop. Files: ShiftCard.luau or toast. Effort: S. Risk: Low. Tag: JACK (monetization nudge, Q-G8).
- DEC-054 Q-G8: capsule-affordable toast once per session, price read from capsule definitions.
- GAMEPLAY-PROGRESS-CALLOUTS H1 fixes ShiftCard `buildLines` at max 6 rows: (1) stars, (2) Served/Walkouts, (3) Pay/Bonus/Tips, (4) `Best combo x N` only when BestCombo >= 2, (5) XP/Level, (6) Next unlock or "Next shift starts now".

## 2. Decisions made
- D1: Both bests live as new TOP-LEVEL profile fields `BestCombo` and `BestShiftPay` (not in `Statistics`), so StatisticsService, leaderboards and the Statistics type are untouched. Rationale: add-only, zero coupling.
- D2: "Shift pay" for BestShiftPay is `state.Pay` (all serve pay including tips, excluding the star bonus). Rationale: it is the number the player saw grow; the bonus is fixed by stars.
- D3: The ShiftEnding path cannot yield, so the previous bests are read earlier: `_beginShift`'s existing async load also reads `BestCombo` and `BestShiftPay` into `state.PrevBestCombo` / `state.PrevBestShiftPay`. `_endShift` carries the updated values into the next `newState`. Rationale: keeps the summary synchronous.
- D4: A "new best" flag is true only when the previous best is a number > 0 and the new value is strictly greater, and for combo only when the new combo >= 2. A first-ever shift (`summary.First`, previous bests 0) therefore never shows "Best shift ever!" or "New best combo!" (FIRST-5-MIN). Rationale: nothing to beat on a first shift; the 6-row rule already hides combo below 2.
- D5: The profile write runs in `task.spawn` after `ShiftEnded` is fired: read the profile with `GetDataAsync(player):timeout(READ_TIMEOUT_SECONDS):await()` and `SetValue` only when the new value exceeds the stored one. Rationale: monotonic, safe on retry, never blocks the card.
- D6: Card placement without a 7th row: the "Best shift ever!" text is appended to row 1 (stars row): `★★★ · Best shift ever!`; row 4 becomes `New best combo! x {BestCombo}` when `NewBestCombo`, else the unchanged `Best combo x {BestCombo}` (still only when BestCombo >= 2). Row count never exceeds 6. Rationale: reuses existing rows, no overflow.
- D7: H4 is a toast, not a button (ShiftCard takes no input by design). Sent through `DialogService:Notify(player, { Text = TEXT })`, the same path CafeRatingService uses. Rationale: DEC-013, no new component.
- D8: The nudge fires from `_endShift` after `ShiftEnded` in `task.spawn`+`pcall`: wait `NUDGE_DELAY_SECONDS` (so the star bonus from `CurrencyService:Modify` has landed), then while `player:GetAttribute("NicknamePending") == true` poll every `NUDGE_POLL_SECONDS` up to `NUDGE_NICK_WAIT_SECONDS` (ONBOARD-NICK D11 sets and clears the attribute around the nickname prompt, so the nudge never stacks on it), then wait `NUDGE_DRAIN_SECONDS` (toast drain), re-check the player is still in the game, read `Currency.BobaBucks`, compare with `ShiftService.CheapestCapsulePrice()`, send once, mark `self._capsuleNudged[player] = true`. Rationale: once per session, balance includes the shift bonus.
- D9: `CheapestCapsulePrice()` iterates `InventoryItemDefinitions.Capsules` with `pairs` (skips non-table values such as the metatable's `ActionOverride`, which is not in the raw table anyway), parses each `Price` with `tonumber((price:gsub("%s", "")))` (same pattern as CapsuleService), ignores entries where the result is nil or <= 0, returns the minimum, or nil when none. If nil, no toast. Rationale: no hardcoded 75; today it resolves to the Regular Pet Capsule price.
- D11: Card-open flag for ONBOARD-NICK: just before `ShiftEnded:Fire`, `_endShift` sets `player:SetAttribute("ShiftCardOpen", true)` and a `task.delay(summary.Seconds, ...)` clears it (only if the player is still in the game). The nickname prompt opens only while it is not true. Rationale: the card is client-timed with `summary.Seconds`; the server needs a readable flag, no new remote.
- D12: Priority (FEEDBACK-VOICE 3): shift card events are tier 1, "Best shift ever!" and "New best combo!" are card rows (no toast), the capsule nudge is tier 4 and is the last beat of a first shift (after the nickname prompt closes).
- D10: The nudge is skipped when the player is no longer clocked in at fire time. Rationale: a clocked-out player is a customer and would not be watching the card.

## 3. Exact strings
- Row 1: `string.rep("★", stars)` then, when `summary.NewBestShiftPay == true`, ` · Best shift ever!`
- Row 4: `New best combo! x {summary.BestCombo}` (when `NewBestCombo == true`) else `Best combo x {summary.BestCombo}`
- Toast: `You can afford a capsule! Check the Shop.`

## 4. Exact numbers
- `NUDGE_DELAY_SECONDS = 1.5`, `NUDGE_POLL_SECONDS = 1`, `NUDGE_NICK_WAIT_SECONDS = 45`, `NUDGE_DRAIN_SECONDS = 1` (timing, not economy). `NEW_BEST_MIN_COMBO = 2`. No economy values added; no ECONOMY-LEDGER rows.

## 5. Signatures and names
- ProfileTemplate: add `BestCombo: number, BestShiftPay: number` to the `ProfileTemplate` type; add `BestCombo = 0, BestShiftPay = 0` after `Quests` in the returned table.
- `ShiftState` gets optional `PrevBestCombo: number?` and `PrevBestShiftPay: number?`; `newState(target, completed, loaded)` gains no params (set the two fields after creation in `_beginShift` and `_endShift`). Existing spec states without them must still work (nil means no flags, no crash).
- Summary additions in `_endShift`: `NewBestCombo = false :: boolean`, `NewBestShiftPay = false :: boolean`, set from D4 before `ShiftEnding:Fire`.
- `_readCompleted` stays unchanged; add `ShiftService:_readBests(player): (number?, number?)` with the same pcall/timeout/warn pattern returning `profile.BestCombo`, `profile.BestShiftPay` when numbers. Call it in the `_beginShift` spawn next to `_readCompleted`; set `state.PrevBestCombo`, `state.PrevBestShiftPay` only if `self._states[player] == state` still holds.
- `function ShiftService.CheapestCapsulePrice(): number?` (static, pure, no yield). `ShiftService._capsuleNudged = {} :: { [Player]: boolean }`; clear in `PlayerRemoving`.
- Add `local InventoryItemDefinitions = require(ReplicatedStorage.Shared.Configuration.InventoryItemDefinitions)` and `NUDGE_TEXT`, `NUDGE_DELAY_SECONDS`, `NEW_BEST_MIN_COMBO` under `---> constants`.
- Insertion points: bests read in `_beginShift` spawn (after `state.Completed = completed` block, before `state.Loaded = true`); flags computed in `_endShift` right after the `summary` table; writes and nudge after `self.Client.ShiftEnded:Fire(player, summary)` as the last statements; the next-shift state in `_endShift` (`self._states[player] = newState(...)`) receives `PrevBestCombo = math.max(prev or 0, state.BestCombo)` and `PrevBestShiftPay = math.max(prev or 0, state.Pay)` (only when the previous value is a number; keep nil when unknown).

## 6. UI spec
- ShiftCard geometry, Pane rows (`Size 0.95 x 0.12`, `MaxTextSize 22`, `Styles.FONT_FREDOKA`, `Styles.OFFWHITE`) unchanged. Only the two row strings in `buildLines` change per section 3. Phone 844x390: the card is `0.2 x 0.3` with min 190x160; TextScaled shrinks the longest row, `★★★ · Best shift ever!` is 22 characters, comparable to the existing `Pay: X  Bonus: Y` rows. Nil-safe for older summary shapes: `summary.NewBestCombo == true` checks only.
- Toast uses the existing SmallNotification path; no style change.

## 7. Studio checks (batched)
- S1: Finish a shift with a profile whose BestCombo is 0: no "New best" text; rejoin and check the profile `BestCombo` equals the shift's best combo.
- S2: Finish a later shift with a higher combo than stored: row 4 reads `New best combo! x N`.
- S3: Finish a shift with more pay than stored: row 1 reads stars plus ` · Best shift ever!`; the card still shows at most 6 rows with walkouts, tips and a level-up present.
- S4: Finish a shift with BobaBucks >= the cheapest capsule price: toast `You can afford a capsule! Check the Shop.` once; finish another shift the same session: no second toast.
- S5: Finish a shift with BobaBucks below that price: no toast.
- S6: Clock out immediately after the card appears: no toast.
- S7: New profile, first shift: no "Best shift ever!" or "New best combo!" row; the nickname prompt opens about 8 s after the card; the capsule toast (if affordable) shows only after Submit or Skip.

## 8. Asset prerequisites
- None. No sounds, no instances.

## 9. Open items: none

## Summary
- Adds `BestCombo` and `BestShiftPay` to ProfileTemplate (add-only, top level).
- ShiftService reads previous bests in the existing async load, flags new bests synchronously in the summary, writes monotonic maxima after the card is sent.
- ShiftCard shows `Best shift ever!` on the stars row and `New best combo!` on the combo row; 6-row cap kept.
- Capsule nudge toast once per session when BobaBucks >= cheapest capsule price parsed from `InventoryItemDefinitions.Capsules`.
- No prices, no catalog data, no assets, no ledger rows. Depends on GAMEPLAY-PROGRESS-CALLOUTS (ShiftCard row layout).

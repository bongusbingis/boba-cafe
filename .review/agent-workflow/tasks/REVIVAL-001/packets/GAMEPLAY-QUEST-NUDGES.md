# GAMEPLAY-QUEST-NUDGES: tell the player when a quest completes and what a claim paid
Model: sonnet (Mason, Studio: no)   Depends on: GAMEPLAY-REVIEW Q1/Q2 (OBVIOUS); best after GAMEPLAY-TOASTS (queue) and GAMEPLAY-SERVE-QUEST-YIELD (so the server toast is never inside a serve thread)   Size: XS

## Goal
- The QuestCard is closed by default (DEC-047) and has no claimable badge, so today a quest that completes mid-shift is invisible. When a quest flips to `Completed` in `AdvanceQuest`, the server posts ONE toast: `Quest complete: {title}! Open Quests to claim.` (`title` from `QuestConfig.GetQuestTitle(entry)`).
- A successful claim in the card toasts the reward from the entry's own fields: `Quest claimed! +{RewardBobaBucks} Boba Bucks · +{RewardXP} XP` (omit a part that is 0).
- Existing toast path only. No badge, dot or sound.

## Verified facts
- `QuestService:AdvanceQuest(player, questType, amount)` (`QuestService.luau:116-148`) loops quests and sets `quest.Completed = true` when progress reaches the target (`:133-135`), then saves and fires `QuestsUpdated`. Callers: `CustomerService._onServeTriggered` (serve path; see GAMEPLAY-SERVE-QUEST-YIELD), `RealOrderService` (spawned), `ShiftService._endShift`, spills.
- `QuestService._getService(name)` is the service lookup that the spec fakes; the spec returns nil for unknown names (`QuestService.spec.luau:93-102`), so a `DialogService` lookup through `_getService` must be nil-safe.
- `QuestConfig.GetQuestTitle(entry)` exists (`QuestConfig.luau:67-73`).
- `QuestCard.handleClaim(index)` (`QuestCard.luau:411-431`) calls `ClaimQuest(index)` and only warns on failure. The quest entries are in component state (the `quests` list used to render rows).
- Toast from the client: `Knit.GetController("DialogController"):Toast(text)` (`AppDialogs.luau:247-249`); the card already uses it for the reroll error (`:449-455`).

## Write scope
- `src/server/Modules/QuestService.luau` (`AdvanceQuest` only)
- `src/shared/UI/Components/Core/Hud/QuestCard.luau` (`handleClaim` only)
Not touched: `QuestConfig.luau` (amounts, templates), `ClaimQuest`/`RerollQuest` logic, `CustomerService`, `RealOrderService`, `ShiftService`, `Styles.luau`, `BottomRight.luau`.

## Steps
1. In `AdvanceQuest`, collect the entries whose `Completed` changed from false to true in this call (`newlyCompleted`).
2. After the existing `SetValue` and `QuestsUpdated` fire, if `newlyCompleted` is not empty: `task.defer(function() pcall(function() local dialog = self:_getService("DialogService"); if dialog then for each entry: dialog:Notify(player, { Text = "Quest complete: " .. QuestConfig.GetQuestTitle(entry) .. "! Open Quests to claim." }) end end) end)`. `task.defer` so no caller ever waits; the pcall and nil check keep the spec green.
3. In `QuestCard.handleClaim`, when the call succeeds (`ok and success ~= false`), read the entry for `index` from the current `quests` state BEFORE the call (capture it at the top of the spawned function), and toast `Quest claimed!` plus ` +{RewardBobaBucks} Boba Bucks` when > 0 and ` · +{RewardXP} XP` when > 0, inside a pcall. Format numbers with the existing number style (STYLE 7: no hand-typed amounts; the values come from the entry).
4. Gate and `rojo build`.

## Hard constraints
- Agents never run Play or TestEZ (DEC-019; Jack does). No Studio, no commits.
- Serve-path invariant: nothing may yield between the serve guards and the payout in `CustomerService:_onServeTriggered` or the `RealOrderService` payout. `AdvanceQuest` is reached from the serve path; the new toast is `task.defer`'d and adds no yield to `AdvanceQuest`. Do not add any wait, DataStore, MarketplaceService or `:await()` call.
- Studio-authored content (`workspace.Assets`, `Ordering System`, `ReplicatedStorage.SelectorModels`, `ReplicatedStorage.Networking`, `SoundService.SFX`) is not in the Rojo tree and is not edited. No sound.
- DEC-013: existing toast only; no badge, dot or new visual on the Quests button.
- Economy untouched; amounts read from the quest entry, never typed.
- Gate on every changed Luau file (stylua only if no DEC-001 drift; otherwise gate alone with no new findings): `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`, plus `rojo build default.project.json -o <path outside the repo>`.

## Done when
- One toast per newly completed quest (never repeated on further progress or on a capped quest); claim toast shows the entry's rewards; reroll and claim behaviour unchanged.
- Existing `QuestService.spec.luau` cases still hold by reading (no DialogService in the fake: the toast path is skipped).
- Gate shows no new findings; `rojo build` succeeds; evidence in `tasks/REVIVAL-001/GAMEPLAY-QUEST-NUDGES/evidence.md`.

## STOP-AND-ASK
- If `QuestEntry` lacks `RewardBobaBucks`/`RewardXP` on some path (older saved entries): show only what exists; report.
- If adding the toast requires touching the claim or reroll money logic: stop.

## Test for Jack (Play, his Studio)
- Finish a quest during a shift: one toast "Quest complete: Serve 5 customers! Open Quests to claim." (once).
- Open Quests, Claim: toast "Quest claimed! +N Boba Bucks · +N XP"; the Bucks counter goes up by N.
- Serving more after completion: no repeated toast. Reroll still costs 20 BB or the free reroll.

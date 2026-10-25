# M3-BOBA-PARTY: Server-wide Boba Party Rush Hour & Cooldown
Model: mason / spark   Studio: no   Depends on: DEC-029 E18 approved scope   Size: S

## Goal
Implement the approved E18 Boba Party event in `CafeRatingService` and `RatingConfig`:
- A 10-minute server-wide Rush Hour (`PARTY_SECONDS = 600`).
- A 10-minute cooldown after it ends (`PARTY_COOLDOWN = 600`) (20 minutes start-to-start).
- No overlap/stacking with earned Rush or another Party: earned Rush cannot trigger during an active Party or during the 10-minute Party cooldown.
- Extending an active Party: If a purchase arrives while Boba Party is already active, extend the active party by 10 minutes (`PARTY_EXTENSION_SECONDS = 600`) rather than refusing or restarting.
- Workspace attributes: Set `workspace:SetAttribute("RushHour", true)` and `workspace:SetAttribute("BobaParty", true)` during active party, and clear them upon party end.
- Server notification: Notify all players via `DialogService:Notify` when Boba Party starts, when extended (naming the buyer), and when it ends.
- Provide a developer product action slot in `ProcessReceipt.server.luau` that triggers `StartOrExtendBobaParty(player)`.

## Read
- `docs/AI_AGENT_WORKFLOW.md`
- `docs/CONVENTIONS.md`
- `docs/SYSTEMS.md` (Startup & Lifecycle, Cafe Rating & Rush Hour)
- `.review/agent-workflow/decisions.md` (DEC-029)
- `src/shared/Configuration/RatingConfig.luau`
- `src/server/Modules/CafeRatingService.luau`
- `src/server/Scripts/ProcessReceipt.server.luau`
- `src/server/Tests/CafeRating.spec.luau`

## Write scope
- `src/shared/Configuration/RatingConfig.luau`
- `src/server/Modules/CafeRatingService.luau`
- `src/server/Scripts/ProcessReceipt.server.luau`
- `src/server/Tests/CafeRating.spec.luau`
- `.review/agent-workflow/tasks/REVIVAL-001/M3-BOBA-PARTY/evidence.md`

## Invariants
- Do not invent new UI styling. All notifications use `DialogService:Notify(player, { Title = "Boba Party", Description = text, Text = text })`.
- Preserve existing earned Rush Hour logic (2-minute rush at 100% rating). Earned rush must be suppressed if Boba Party is currently active or in its 10-minute cooldown.
- A purchase during an active Boba Party extends `_partyEndTime` by `PARTY_EXTENSION_SECONDS`.
- Handle timer extension cleanly: single active countdown thread/task that checks against `os.clock() >= _partyEndTime`.
- Creator Hub Product IDs are not yet hardcoded; configure `BOBA_PARTY_PRODUCT_ID = nil` (or numeric placeholder if defined) in `ProcessReceipt.server.luau` with guard `if BOBA_PARTY_PRODUCT_ID then ...`.

## Acceptance
- `CafeRatingService:StartOrExtendBobaParty(buyer: Player?): (boolean, string?)` is exposed and handles start and extension.
- `_checkRush` checks `if self._partyActive or (self._partyCooldownEnd ~= nil and os.clock() < self._partyCooldownEnd) then return end`.
- Workspace attributes `RushHour` and `BobaParty` are true during party and false otherwise.
- `CafeRating.spec.luau` covers Boba Party start, extension, and suppression.
- Gate passes on WSL: `stylua` and `gate` report 0 new Selene findings, clean StyLua, clean Rojo build.

## Evidence
Write `.review/agent-workflow/tasks/REVIVAL-001/M3-BOBA-PARTY/evidence.md` following the standard 5-line format:
1. `RESULT: PASS`
2. Changed files
3. Gate check command and results
4. Notes on behavior and limitations

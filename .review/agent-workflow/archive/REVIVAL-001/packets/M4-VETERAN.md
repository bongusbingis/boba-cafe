# M4-VETERAN: Legacy Badge Veteran Overhead Title
Model: haiku / spark   Studio: no   Depends on: none   Size: S

## Goal
Implement the Veteran Overhead Title for legacy badge holders (revival-plan §4.7, DEC-032):
- Check on join if a player owns any legacy badge from before the revival fresh start.
- Sets player attribute `IsVeteran = true`.
- Renders the "Veteran" tag in `PlayerOverheads.client.luau` under the player's name.
- Unit test in `BadgeService.spec.luau`.

## Read (only these)
- `docs/AI_AGENT_WORKFLOW.md`
- `docs/CONVENTIONS.md`
- `.review/agent-workflow/decisions.md` (DEC-032)
- `src/server/Modules/BadgeService.luau` (lines 20-45: legacy badge list)
- `src/client/Scripts/PlayerOverheads.client.luau` (lines 130-155: title rendering)

## Write scope
- `src/server/Modules/BadgeService.luau` (add CheckVeteranStatus on PlayerAdded)
- `src/client/Scripts/PlayerOverheads.client.luau` (render Veteran tag)
- `src/server/Tests/BadgeService.spec.luau` (new or updated)
- `.review/agent-workflow/tasks/REVIVAL-001/M4-VETERAN/evidence.md` (new)

## Steps
1. In `src/server/Modules/BadgeService.luau`:
   - Define `LEGACY_BADGES`: list of pre-revival badge IDs (Welcome, MetTheOwner, MetTheCoOwner, MetADeveloper, FirstQuest, FirstStaff, Celebrity, SakuraIsland, TreasureChest, ShinyPet, HalloweenEvent, Slipped, FirstPaycheck, LevelUp).
   - Add method `CheckVeteranStatusAsync(player: Player): boolean`:
     Iterates through `LEGACY_BADGES`. Checks `BadgeService:UserHasBadgeAsync(player.UserId, id)`. If any returns true, sets `player:SetAttribute("IsVeteran", true)` and returns true.
   - On `Players.PlayerAdded`, spawn a task calling `CheckVeteranStatusAsync(player)`.
2. In `src/client/Scripts/PlayerOverheads.client.luau`:
   - In `refreshTitle()`:
     - Check `local isVeteran = player:GetAttribute("IsVeteran") == true`
     - Check `local levelTitle = player:GetAttribute("LevelTitle")`
     - Format combined text:
       - If `isVeteran and levelTitle`: `"Veteran • " .. levelTitle`
       - If `isVeteran and not levelTitle`: `"Veteran"`
       - Else: `levelTitle or ""`
     - Listen to `player:GetAttributeChangedSignal("IsVeteran")` in addition to `LevelTitle`.
3. Create/update `src/server/Tests/BadgeService.spec.luau`:
   - Unit test verifying veteran detection logic.
4. Run WSL gate and verify clean output.

## Done when
- Legacy badge owners receive `IsVeteran = true` attribute on join.
- `PlayerOverheads` displays "Veteran" tag.
- Tests pass.
- WSL gate check passes cleanly.

## Checks to run
- `. .review/agent-workflow/tools/wsl/env.sh && gate src/server/Modules/BadgeService.luau src/client/Scripts/PlayerOverheads.client.luau src/server/Tests/BadgeService.spec.luau`

## STOP-AND-ASK
- none

## Evidence
`tasks/REVIVAL-001/M4-VETERAN/evidence.md`

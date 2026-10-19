> **Prime override (2026-10-17):** do NOT wait for RIG-1. Find cans by CollectionService tag `TrashCan` instead of `CAN_PATHS`: handle `GetTagged("TrashCan")` plus `GetInstanceAddedSignal`, so cans tagged later in Studio by RIG-1 are wired automatically. Ignore the RIG-1 read item and its STOP-AND-ASK; replace the step-2 `WorldPath.waitFor` loop with the tag loop. Everything else as written.

# TRASH: Trash cans throw away the held drink
Model: sonnet   Studio: no   Depends on: RIG-1 (for the can paths; code may be written once its evidence lists them)   Size: M

## Goal
A player at a trash can sees a "Use" prompt, confirms "Throw Away?" Yes/No, and the held tool is discarded; tools with `NotDisposable` are refused. Settled by DEC-015 Q9, DEC-013.

## Read (only these)
- `tasks/REVIVAL-001/RIG-1/evidence.md`: the section `## Trash can paths`
- `docs/STYLE.md` §3.5 (dialogs, lines 374-392) and §7 (copy)
- `src/server/Modules/DialogService.luau` lines 1-90 and 120-150 (`CreateDialog`, `Notify`)
- `src/server/Modules/CapsuleService.luau` lines 115-130 (a server call to `CreateDialog`, as a usage example)
- `src/client/Modules/AppDialogs.luau` lines 150-200 (how `ButtonPrompt` is shown and resolved)
- `src/shared/UI/Components/Dialogs/ButtonPrompt.luau` lines 1-60 (props)
- `src/server/Modules/KitchenService/init.luau`: grep `Players.PlayerAdded\|Knit.CreateService` for the service skeleton

## Write scope
- `src/server/Modules/TrashService.luau` (new)
- `src/server/Tests/TrashService.spec.luau` (new, optional: skip per DEC-017)

## Steps
1. Create the Knit service `TrashService` (skeleton as in a small existing service, for example `BadgeService.luau` lines 1-40). Constants at the top: `CAN_PATHS` = the 6 exact paths from the RIG-1 evidence, as `{ "Assets", "TrashCans", ... }` arrays under `workspace` (copy them verbatim).
2. `KnitStart`: for each path, `WorldPath.waitFor(workspace, path, 10)` (see `SpillService/init.luau` line ~59 for the require). If a can is missing, `warn` once and skip it. For each can find the primary part (its `PrimaryPart`, else the first `BasePart` descendant) and create a `ProximityPrompt` there: `ActionText = "Use"`, `ObjectText = "Trash"`, `HoldDuration = 0`, `MaxActivationDistance = 8`, `RequiresLineOfSight = false`, attribute `BuiltBy = "REVIVAL-001-TRASH"`.
3. On `Triggered(player)`: guard with a per-player debounce table (`self._busy[player]`, cleared in `PlayerRemoving`). Find the equipped tool (`player.Character:FindFirstChildOfClass("Tool")`). If none: `DialogService:Notify(player, {Title = "Trash", Description = "Hold a drink to throw it away.", Image = "", SoundEnabled = false})` and return. If `tool:GetAttribute("NotDisposable") == true`: Notify "You can't throw that away." and return.
4. Show the existing dialog (STYLE.md §3.5 `ButtonPrompt`, no new look): `DialogService:CreateDialog(player, "ButtonPrompt", { Title = "Throw Away?", Text = "This will discard what you are holding.", Buttons = { { Text = "Yes" }, { Text = "No", Color = ... } } })`, using the exact button colour field and values from a call that already exists in the repo (`grep -rn "ButtonPrompt" src`). Resolve through the returned Promise (`:andThen(function(text) ... end)`, same style as `CapsuleService`).
5. On `"Yes"`: re-check at that moment that the same tool is still equipped, still not `NotDisposable`, and the player is within 12 studs of the can; then `tool:Destroy()` and nothing else (no currency, no stats). On anything else, do nothing. Wrap in `pcall`; failures `warn` and never kick (RUNBOOK).
6. `stylua` then `gate` on `TrashService.luau`.

## Done when
- The gate passes (RUNBOOK step 3).
- All 6 can paths from the RIG-1 evidence appear in `CAN_PATHS`.
- Behaviour (dialog, destroy, refusal) is UNVERIFIED for M1.6.

## Checks to run
- RUNBOOK step 3. Studio: NOT RUN.

## STOP-AND-ASK
- The RIG-1 evidence has no `## Trash can paths` section or lists fewer than 6.
- `ButtonPrompt` has no way to set Yes and No button colours without a new look: ask which existing colours.

## Evidence
`tasks/REVIVAL-001/TRASH/evidence.md` (add Gauge steps for M1.6: hold a drink, press Use, Yes -> tool gone; No -> kept; a tool with `NotDisposable` -> refused).

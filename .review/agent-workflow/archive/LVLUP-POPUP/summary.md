# LVLUP-POPUP — level-up celebration card + SuperSuccess sting

## Result
PASS (implemented, gate PASS, Studio verification owed to Jack).

## What existed
No celebration architecture. A level-up produced three things only:
- `ProgressionService._onLevelUp` → tier-1 toast (`LevelUpText`, max 2 unlocks).
- `LevelBar` flash + `UiSfx.Play({"LevelUp", "Success"})`.
- `ShiftCard` shift-summary line.
No popup, no unlock list UI, no `SuperSuccess` reference anywhere in `src/`.

## What changed (this lane only)
- `src/server/Modules/ProgressionService.luau` — new `Client.LeveledUp`
  `Knit.CreateSignal`, fired in `_onLevelUp` with
  `{ Level, Title, Unlocks }` (`Unlocks` = existing `unlocksAt(level)`:
  drinks, title, ticket slots, item count, VIP/Karen, nametag). Toast kept
  as the tier-1 fallback.
- `src/shared/UI/Components/Core/Hud/LevelUpCelebration.luau` (new) —
  always-mounted HUD card, renders only while a payload is active.
  Non-modal (never blocks input/play): centered `Page` pop, GREEN header
  with GOLD `Banner` "LEVEL UP!", level + title lines, one row per unlock,
  GREEN `PromptButton` dismiss, 8 s auto-dismiss, FIFO queue across
  multi-level grants. Styles tokens/components only, no new visuals.
- `src/shared/UI/Components/Core/Hud/init.luau` — mounts it (ZIndex 20).
- `src/shared/UI/Components/Core/Hud/LevelBar.luau` — cue is now
  `{"SuperSuccess", "LevelUp", "Success"}`; LevelBar still owns the
  level-up sound so card + toast stay silent (no double sting).
- `src/shared/UI/Utility/UiSfx.luau` — added `SuperSuccess = 1.0`
  volume. `UiSfx.Find` resolves `SoundService.SFX.UI.SuperSuccess`
  then `SoundService.UISounds.SuperSuccess`; missing = one warn, skipped.
- `src/shared/UI/Stories/LevelUpCelebration.story.luau` (new) — level 5
  preview (Barista bundle).
- `src/server/Tests/ProgressionService.spec.luau` — new `UnlocksAt`
  block (level 5 bundle, drinks by level, variants by level).
- `docs/SYSTEMS.md` — M2-PROGRESS row documents the signal, card,
  and authored sound path.

## Checks observed
- `gate` (selene new-findings vs HEAD + stylua + rojo build) on all 7
  Luau files: `GATE: PASS` (2026-10-21; one self-fix: dropped an unused
  `Players` import + stylua format in the new file, re-gated clean).
- `rojo build default.project.json` → PASS (artifact outside repo).
- Untouched lanes' dirty files (Npc, OrderTicket, SmallNotification,
  rokit.toml, UI-REVISION captures, etc.) verified present and unmodified
  by this lane via `git diff` file list.

## Fix 2026-10-21: hooks-after-early-return crash
Jack's Play repro (`AddXp` 87 then 463) played the sting but React threw
"Rendered more hooks than during the previous render" at the `useMemo`
sitting after `if active == nil then return nil end`: empty-queue renders
ran 8 hooks, payload renders reached a 9th. Fixed by making every hook
unconditional — `useMemo` moved above the early return (nil-safe inside),
subscription `useEffect` guard moved inside the effect. File now contains
zero conditional hooks, so the class cannot recur in this component.
Re-gated clean (selene new=0, stylua ok, rojo build PASS).
No maintained regression test: TestEZ covers pure server logic and the
repo has no React render harness (components verify via stories + Play),
so the durable check is this Play repro. `UnlocksAt` specs still cover
the payload content.

## NOT RUN (Jack)
- Studio Play in **jacks project**: toast + card + SuperSuccess on a
  real level-up; multi-level queue; story render; TestEZ suite with
  `TESTS_ENABLED = true` (revert after). Commands in task handoff.

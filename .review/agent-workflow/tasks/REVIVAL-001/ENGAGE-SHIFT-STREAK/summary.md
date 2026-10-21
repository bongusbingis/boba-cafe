# ENGAGE-SHIFT-STREAK — summary (H6-STREAK)

APPROVED by Jack 2026-10-21. All numbers PROPOSED.

## What
Session-only consecutive-shift counter in `ShiftService` (`_streaks`, cleared on
`PlayerRemoving`, same pattern as `_capsuleNudged`; no profile fields). Every
3rd consecutive shift end (`STREAK_LENGTH`) grants `STREAK_BONUS_BB` (30 BB).

## Chest-path inventory (substitution reported)
`TreasureHuntService` has no clean server-side grant: the only reward path is
`ClaimChest(player, chest)`, which requires a physical chest instance, distance
validation, per-player cooldown, and fires badge/stat side effects. Reusing it
would need a fake world chest per streak. Fallback granted instead: the chest's
average BB value, (20 + 40) / 2 = 30 (`TreasureHuntConfig` MIN/MAX_BOBABUCKS),
paid via `CurrencyService:Modify(player, "BobaBucks", 30, "ShiftStreak")`.

## Changes
- `src/shared/Configuration/ShiftConfig.luau`: `STREAK_LENGTH = 3`,
  `STREAK_BONUS_BB = 30` (both PROPOSED).
- `src/server/Modules/ShiftService.luau`: `_streaks` table; `_endShift` sets
  `summary.ShiftStreak` / `summary.StreakBonus` and pays the bonus;
  `PlayerRemoving` clears the streak. Clock-out does not reset (shifts
  completed stay consecutive); no failure event exists.
- `src/shared/UI/Components/Core/Hud/ShiftCard.luau`: one `buildLines` row —
  `Streak N · streak bonus in M` normally,
  `Streak N · +30 BB streak bonus!` on grant. DEC-013 tokens only, no sound.
- `src/server/Tests/ShiftService.spec.luau`: streak describe block
  (1/2/3/4 sequence, PlayerRemoving clear).

## Verification
GATE: PASS (see `gate-output.txt`). TestEZ not run (DEC-019). Not committed.

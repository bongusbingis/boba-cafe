# SHIFT-STARS-SOUND — evidence (H2)

## What
When `ShiftEnded` fires with `Stars` = 1..3, `ShiftCard.luau` spawns a rising arpeggio of 1..3 star notes:
- PlaybackSpeed: `1.0`, `1.2599`, `1.4983` (root, major third, fifth).
- Spacing: 0.2 s between notes.
- Target: `SoundService.SFX.UI.StarNote` (with fallback to `SoundService.UISounds.StarNote`).
- Debris lifetime: 3 s per clone.
- Silent skip if missing.
- Stub sound authored in Studio under `SoundService.SFX.UI.StarNote` and `SoundService.UISounds.StarNote` per Jack's approval.

## Files changed
- `src/shared/UI/Components/Core/Hud/ShiftCard.luau`: added `playStarJingle`, wired in `ShiftEnded` effect.

## Gates
- `stylua --check`: PASS
- `selene`: 0 errors, 0 warnings
- `rojo build default.project.json -o %TEMP%/gate-build.rbxl`: SUCCESS

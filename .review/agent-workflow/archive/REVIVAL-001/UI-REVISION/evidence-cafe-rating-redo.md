RESULT: PASS

# UI-REVISION — TopBar Cafe Rating restyle to Jack's Studio design (2026-10-23)

Jack rejected the previous Cafe Rating pod look and provided his manual Studio design (plugin-converted React tree). Prime restyled `CafeRating.luau` to that exact tree while porting the Rush Hour / Boba Party effect behavior into it.

## Changes
- `src/shared/UI/Components/Core/Hud/CafeRating.luau` (rewritten)
  - Pod: slice-scaled image (13407992271, GREEN, `SliceCenter 68,73,332,90`, `SliceScale 0.35`), Position (0.5, 0.327), Size (0.509847, 1.04717) — matches Jack's design.
  - Border: slice-scaled OFFWHITE frame (13408001982) at (0.5, 0.281037), Size (1,5, 1.43793,5).
  - Label "Cafe Rating" absolutely positioned upper-left (0.043, 0.285), OFFWHITE Fredoka, MaxTextSize 13.
  - Track: light gray (225,225,225, per Jack's design), pill corner, white UIStroke (ScaledSize, 0.15), green fill + percent text (GREEN_DEEP), full-size tap target.
  - Buy button: GOLD_MID (255,185,30), "+ Rush", pill corner, 4px side padding, positioned right of the track; keeps the pulse UIScale during events.
  - TopBar base/buttons unchanged (HudTabButton kept so the Menu claim dot + selected stroke from DEC-057 are preserved).

## Effect displays (Rush Hour / Boba Party) ported into the new pod
- Idle: label "Cafe Rating", fill GREEN at rating%, percent "N%", button "+ Rush".
- Rush Hour: label "{buyer}'s Rush!" / "Rush Hour!" + m:ss countdown, fill GOLD_MID with remaining-time fraction, percent "×2 pay", button "+ Time".
- Boba Party: label "{buyer}'s Party!" / "Boba Party!" + m:ss countdown, fill ROSE_MID, percent "×2 pay", button "+ Time" (ROSE_MID).
- Tap on the track or the button opens the Cafe Event dialog (live prices; buying during an event adds time).

## Gate
`stylua` clean; `scripts/gate.sh` PASS on CafeRating.luau (selene new=0, stylua=ok, rojo build ok).

## Owed
- Jack Studio look check of the top bar pod (idle, rush, party states; the CafeRating story controls drive 20/50/75/100%, Rush Hour, Boba Party).

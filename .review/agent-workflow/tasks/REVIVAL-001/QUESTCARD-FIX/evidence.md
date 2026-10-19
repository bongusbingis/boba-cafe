# QUESTCARD-FIX evidence
File changed: src/shared/UI/Components/Core/Hud/QuestCard.luau (+3 lines)

## Defect 1: header fill missing
Cause: Pane computes `BackgroundTransparency = props.Native and props.Native.BackgroundTransparency or 1` before merging Native. The header Native set BackgroundColor3 but no BackgroundTransparency, so the fill was fully transparent and the OFFWHITE title sat on the white card.
Fix: added `BackgroundTransparency = 0` to the header's Native. Header is GREEN with OFFWHITE title/toggle. (The BottomSquare child is a plain Frame, already opaque.)

## Defect 2: Claim/Reroll button on top of progress bar
Cause: QuestActionButton had no AnchorPoint/Position, so it rendered at x=0 over the bar. Only the "Claimed" label was right-anchored.
Fix: added `AnchorPoint = Vector2.new(1, 0.5)` and `Position = UDim2.fromScale(1, 0.5)` to its Native (same as the Claimed label).
Layout math: card 230 - 16 padding = 214 row width. Bar = 214 - 78 = 136 px (x 0..136). Button/Claimed label 72 px at x 142..214. 6 px gap; "n / target" label is inside the bar, so never covered. Hover scale 1.05 grows 3.6 px each side of the centre (UIScale), staying within the gap.
States: in progress (Reroll), completed (Claim), claimed ("Claimed" text) all share the right-anchored 72 px slot.

## Gate
PASS src/shared/UI/Components/Core/Hud/QuestCard.luau selene new=0 (baseline 0) stylua=ok
PASS rojo build
GATE: PASS

## Test for Jack
Join, open the HUD: the Daily Quests header is green with a readable title; click it to collapse/expand. Each quest row shows "n / target" in the bar with the Reroll/Claim button to its right and "Claimed" in the same slot. Nothing overlaps.

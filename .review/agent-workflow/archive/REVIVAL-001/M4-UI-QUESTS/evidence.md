# M4-UI-QUESTS Evidence

RESULT: PASS

## Files changed
- `src/shared/UI/Components/Core/Hud/QuestCard.luau` (new)
- `src/shared/UI/Components/Core/Hud/init.luau` (modified)

## Gate check output
```
PASS  src/shared/UI/Components/Core/Hud/QuestCard.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/shared/UI/Components/Core/Hud/init.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
```

## Notes on behavior
1. **`QuestCard.luau`**:
   - React HUD component mounted at the top-left (`UDim2.fromOffset(10, 48)`), cleanly below the Roblox topbar and avoiding overlap with existing HUD elements (OrderTicket/ShiftCard on right, BottomLeft on bottom-left, CafeRating at top-center).
   - Card container with `Styles.GREEN` header ("Daily Quests") and collapse/expand toggle ("▲" / "▼"). Clicking anywhere on the header toggles the list display while keeping a compact 28px header pill when collapsed.
   - Strictly conforms to `docs/STYLE.md` (DEC-013, DEC-032):
     - Tokens: `Styles.GREEN` (header and Claim fill), `Styles.GREEN_LIGHT` (progress fill and free reroll fill), `Styles.GREEN_DEEP` (quest title text), `Styles.GOLD_MID` / `Styles.GOLD_DEEP` (reward pill and 50 BB reroll button), `Styles.OFFWHITE` (card background and label text), `Styles.GRAY` (progress track, dividers, and Claimed label).
     - Font: `Styles.FONT_FREDOKA` across all text elements.
     - Corner radii: 6px card radius matching `OrderTicket`, `Styles.CORNER_BUTTON` for interactive action buttons, and pill radii (`UDim.new(0.5, 0)`) for progress bar and reward badges.
   - Fetches active quests on mount using `QuestService.Client:GetQuests()` and subscribes to `QuestService.Client.QuestsUpdated` to reactively re-render quest progress, completions, claims, and rerolls in real time.
   - For each active daily quest:
     - Formatted quest title generated via `QuestConfig.GetQuestTitle(entry)` (e.g. "Prepare 5 Boba Drinks", "Serve 10 Customers").
     - Centered numerical progress bar readout (`Progress / Target`) with smooth fill track.
     - Reward badge pill indicating `+X BB · +Y XP`.
     - Action element based on state:
       - Completed and unclaimed: `Claim` button (`Styles.GREEN` fill, white text) that calls `QuestService.Client:ClaimQuest(index)`.
       - Claimed: `"Claimed"` muted label in `Styles.GRAY`.
       - Uncompleted: `Reroll` button displaying `"Free"` if Star Employee free reroll is remaining, or `"50 BB"` otherwise. Clicking calls `QuestService.Client:RerollQuest(index)` and notifies with a toast if funds are insufficient.
   - Returns `nil` when `RunService:IsRunning()` is true and no quests are loaded yet, preventing UI pop-in artifacts.

2. **`init.luau`**:
   - Imports and mounts `QuestCard` into the root HUD tree.

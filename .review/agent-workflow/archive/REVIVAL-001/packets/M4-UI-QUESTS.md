# M4-UI-QUESTS: Daily Quests HUD & Menu Card
Model: sonnet / spark   Studio: no   Depends on: M4-QUESTS   Size: M

## Goal
Implement the Daily Quests UI presentation (revival-plan §4.7, DEC-013, DEC-032):
- Follows `docs/STYLE.md` exactly: tokens (`Styles.GREEN`, `Styles.GREEN_LIGHT`, `Styles.GOLD`, `Styles.OFFWHITE`), font (`Styles.FONT_FREDOKA`), and Pane cards.
- Displays the 3–4 active daily quests retrieved from `QuestService.Client:GetQuests()`.
- Updates reactively when `QuestService.Client.QuestsUpdated` fires.
- Shows task title, progress bar with numerical readout (`Progress / Target`), and reward badges (BobaBucks + XP).
- "Claim" button invokes `QuestService.Client:ClaimQuest(index)`.
- "Reroll" button (labeled "Free" if Star Employee reroll is available, otherwise "50 BB") invokes `QuestService.Client:RerollQuest(index)`.
- Mounted onto HUD (slide-out / toggle) or accessible via HUD buttons.

## Read (only these)
- `docs/AI_AGENT_WORKFLOW.md`
- `docs/STYLE.md` (tokens, fonts, pane cards, buttons, text colors)
- `src/shared/Configuration/QuestConfig.luau`
- `src/server/Modules/QuestService.luau` (client methods: GetQuests, ClaimQuest, RerollQuest, QuestsUpdated signal)
- `src/shared/UI/Components/Core/Hud/init.luau`
- `src/shared/UI/Components/Core/Hud/ShiftCard.luau` (reference for HUD card layout)

## Write scope
- `src/shared/UI/Components/Core/Hud/QuestCard.luau` (new)
- `src/shared/UI/Components/Core/Hud/init.luau` (mount QuestCard)
- `.review/agent-workflow/tasks/REVIVAL-001/M4-UI-QUESTS/evidence.md` (new)

## Steps
1. Create `src/shared/UI/Components/Core/Hud/QuestCard.luau`:
   - React component mounted on the HUD (e.g. top-left or collapsable side card next to ShiftCard / OrderTicket).
   - Card container with `Styles.GREEN` header ("Daily Quests") and collapse/expand toggle.
   - List of 3 to 4 quest items:
     - Title: formatted quest description (e.g. "Prepare 5 Boba Drinks").
     - Progress Bar: background frame (`Styles.GRAY` or muted green), fill frame (`Styles.GREEN_LIGHT` or `Styles.GREEN`), centered text label: `Progress / Target`.
     - Reward Pill: displays `+X BB` and `+Y XP`.
     - Action Buttons:
       - If `Completed and not Claimed`: "Claim" button (`Styles.GREEN` fill, white text), invokes `QuestService.Client:ClaimQuest(index)`.
       - If `Claimed`: "Claimed" muted label.
       - If uncompleted: "Reroll" button (shows "Free" or "50 BB"), invokes `QuestService.Client:RerollQuest(index)`.
   - Listens to `QuestService.Client.QuestsUpdated` to refresh quest list immediately.
2. Update `src/shared/UI/Components/Core/Hud/init.luau`:
   - Import and render `QuestCard`.
3. Run WSL gate check on all modified/new files.

## Done when
- `QuestCard.luau` renders all daily quests according to `docs/STYLE.md`.
- Claim and reroll actions call `QuestService.Client` and update UI.
- Updates cleanly on `QuestsUpdated` signal.
- WSL gate check passes cleanly.

## Checks to run
- `. .review/agent-workflow/tools/wsl/env.sh && gate src/shared/UI/Components/Core/Hud/QuestCard.luau src/shared/UI/Components/Core/Hud/init.luau`

## STOP-AND-ASK
- none

## Evidence
`tasks/REVIVAL-001/M4-UI-QUESTS/evidence.md`

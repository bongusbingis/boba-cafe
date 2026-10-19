# QUESTCARD-FIX: Quest card header and action-button layout
Model: sonnet   Studio: no   Depends on: M4-FIXES   Size: S

## Goal
- The quest card renders as M4-UI-QUESTS intended, before Jack's DEC-013 approval. The header shows a GREEN fill with the readable "Daily Quests" title, and the Claim/Reroll buttons sit beside the progress bar instead of on top of it.

## Read (only these)
- `.review/agent-workflow/tasks/REVIVAL-001/M4-UI-APPROVAL/evidence.md` and `d-questcard-expanded.jpg` (the defects as captured).
- `src/shared/UI/Components/Core/Hud/QuestCard.luau` (whole file).
- `docs/STYLE.md`: the token table, plus the Order Ticket header pattern (~lines 552-560), the nearest existing HUD header.
- One sibling HUD component that uses `Pane` with a filled header, if one exists (grep `c(Pane` under `src/shared/UI/Components/Core/Hud/`).

## Write scope
- `src/shared/UI/Components/Core/Hud/QuestCard.luau` only.

## Steps
1. **Header (~line 427).** Find out why the header's fill doesn't render. The evidence suspects `Pane`'s default `BackgroundTransparency = 1`, while a GREEN child frame exists at ~437. Make the header show its GREEN fill with the OFFWHITE title visible. Use only existing tokens and the existing Pane/frame pattern.
2. **Action button (`QuestActionButton` ~90, used ~246-260, row layout ~265-310).** Give the button an explicit position/anchor (or fix the row layout) so it sits to the right of the progress bar. Make the progress bar narrow enough that its "n / target" label is never covered. Check all three row states: in progress (Reroll), completed (Claim) and claimed (the "Claimed" text).
3. Change no colors, fonts, sizes or text beyond what's needed for 1-2. No new tokens or components (DEC-013).

## Done when
- In each state, the header fill and title are visible and the button doesn't overlap the bar or its label (by reading the layout math; you can't render).
- The gate passes on QuestCard.luau.

## Checks to run
`wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`
Never Play, never run TestEZ, never touch Studio (DEC-019). Prime has the Lens re-capture afterwards.

## STOP-AND-ASK
- If the fix needs a new token, a new component, or a change to `Pane` itself, stop and report.

## Evidence
`.review/agent-workflow/tasks/REVIVAL-001/QUESTCARD-FIX/evidence.md`: a cause and fix per defect, the gate output, and a "Test for Jack" item.

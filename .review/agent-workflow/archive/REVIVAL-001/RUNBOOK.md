# REVIVAL-001 runbook (for any agent: Claude, Muse, Gemini)

Follow these steps exactly. Make no design decisions. If a step needs a decision this file or your packet does not give you, stop and ask Jack (see "Stop and ask").

## What this project is
A Roblox café game (boba-cafe). The goal is to rebuild it and release it to players. Everything Jack has decided is in `.review/agent-workflow/decisions.md`; newest entries come first. Do not re-decide anything written there.

## Step 1: Pick your work
1. Open `.review/agent-workflow/board.json` (if it is missing, use `packets/INDEX.md`).
2. Pick a task with `"status": "ready"` that has a packet file at `.review/agent-workflow/tasks/REVIVAL-001/packets/<ID>.md`, and is not listed in `"leases"`.
3. Prefer the order given in `packets/INDEX.md`.
4. If you are the coordinator (Prime): add a lease for the task in `board.json` before you start. If you are not the coordinator, only do the packet you were given.

## Step 2: Do the packet
- Read the packet in full. Read only the files it names, using the line ranges it gives.
- Edit only the files listed under "Write scope". If you need another file, stop and ask.
- Quality bar (DEC-017):
  - Code that players never see can be quick and simple.
  - Be careful with anything players see (follow `docs/STYLE.md` exactly; never invent a new UI style), and with money, data, saves and remotes (never trust the client).
- Never make a player wait or get kicked because something failed. Warn and carry on.

## Step 3: Check your work (the gate)
From the repo root, in WSL bash:
```
. .review/agent-workflow/tools/wsl/env.sh
stylua <each changed .luau file>
gate <each changed .luau file>
```
- A gate FAIL caused by `rojo build`, or a line marked `NEW error[...]`, must be fixed.
- New `warning[...]` lines are fine. Copy them into your evidence.
- On Windows without WSL: install the tools with `rokit install`, then run `scripts/gate.sh <files>` from Git Bash. If it fails on `\r` characters, use WSL instead.
- Ignore the roughly 243 files that `git status` shows as modified. They differ only in line endings. Never run `git checkout`, `git reset`, `git stash`, or `git clean`.
- Do not commit or push unless the packet says so.

## Step 4: Studio work (only if your packet says "Studio: yes")
- Never Play-test or run TestEZ. Jack does all in-game testing (DEC-019). Studio is for authoring and saving only. Write a "Test for Jack" list in your note instead.
- Studio is expensive. Do only the steps listed, once.
- Run tests in Studio:
  1. In Edit mode, run `workspace:SetAttribute("RunTests", true)`.
  2. Press Play and read the Output.
  3. Stop, then run `workspace:SetAttribute("RunTests", nil)`.
- Never edit `TESTS_ENABLED`.
- Things you build in the place get the attribute `BuiltBy = "<task ID>"`. Never delete existing place content; clone or move it, and note it.
- Save the place after Studio edits (File > Save to Roblox). Never publish to the live game (place 718328620).

## Step 5: Short note and report (DEC-018: implement first, verify later)
- Write `.review/agent-workflow/tasks/REVIVAL-001/<ID>/evidence.md` with about 5 lines. Never name it `report.md`.
  1. `RESULT: PASS`, `RESULT: FAIL`, or `RESULT: BLOCKED`
  2. the files changed
  3. the gate result, as one line
  4. the Studio steps someone should run later
  5. any question for Jack
- Don't run extra verification. Studio and runtime checks are batched late.
- Reply in at most 150 words: RESULT / CHANGED / NOT VERIFIED / QUESTIONS.

## Stop and ask (never guess)
Stop, write `RESULT: BLOCKED` with what you searched for and the exact question, and ask Jack when:
- an asset, model, sound or place path is not where the packet says it is (DEC-008: never build a substitute);
- the packet has a `STOP-AND-ASK` line you reached;
- you would need to change a price, reward, chance, product, gamepass or promo code;
- you would need to publish, upload, delete player data, or rename the ProfileStore;
- you would need to add a new UI look (colour, font, component) that `docs/STYLE.md` does not have.

## Useful files
- `docs/STYLE.md`: the UI rules. Copy existing UI exactly.
- `docs/SYSTEMS.md`, `docs/ARCHITECTURE.md`: how the code is laid out.
- `tasks/REVIVAL-001/M1.2/design.md`: the approved game design. Jack approved every recommendation: DEC-011, DEC-015.
- `tasks/REVIVAL-001/revival-plan.md` §8: milestones M1–M7. The full plan ships (DEC-014).

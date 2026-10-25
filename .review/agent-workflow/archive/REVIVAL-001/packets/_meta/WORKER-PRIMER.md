# WORKER-PRIMER (REVIVAL-001, HEAD 098175c)

Every packet links this file instead of repeating rules. Read it once, then your packet. Sources: `AGENTS.md`, `docs/AI_AGENT_WORKFLOW.md`, `docs/CONVENTIONS.md`, `docs/STYLE.md`, decisions DEC-001/008/013/019/053 in `.review/agent-workflow/decisions.md`.

## 1. Serve-path no-yield rule (M3-REM-B)
- Nothing may yield between the serve guards and the payout in `CustomerService:_onServeTriggered` (`src/server/Modules/CustomerService/init.luau`) or in the `RealOrderService` payout (`src/server/Modules/RealOrderService.luau`). Yielding = `task.wait`, `WaitForChild`, DataStore/Marketplace calls, RemoteFunction invokes, or any service call that may yield.
- `QuestService:AdvanceQuest` can yield. Call it as `task.spawn(function() pcall(function() ... end) end)`, never inline.
- Toasts, hearts prompts, sounds and shift bookkeeping added "after payout" go in `task.defer`/`task.spawn` wrapped in `pcall`.
- Anchor edits by symbol name, not line number (lines drift as earlier packets land).

## 2. Gate (workers run this; nothing else)
- `scripts/gate.sh <files>` = Selene + StyLua `--check` against the HEAD baseline (no NEW findings in changed files) + `rojo build`.
- Exact WSL command (run from Bash or PowerShell):
  `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`
- Files with pre-existing StyLua drift (DEC-001 baseline: 99 files flagged) are gated but NOT run through `stylua` (it would reformat unrelated lines). Check with `stylua --check <file>` on the HEAD copy first; if it already fails, run `gate <files>` alone.
- Also: `rojo build default.project.json -o <path outside the repo>` (the scratchpad dir is fine).
- Workers do NOT run Play, TestEZ or Studio (DEC-019). Jack runs all in-game tests. Put runtime checks in the packet's "Studio checks" list; they are batched into one milestone run.
- Never edit `TESTS_ENABLED` or `RunTests.server.luau`. New logic worth testing goes in a ModuleScript plus a spec under `src/server/Tests/`, written but not run.

## 3. File leases
- You may edit only the paths in your packet's `write_scope`. Two packets never write the same file concurrently; `depends_on` encodes the order. If you need a file that is not in `write_scope`, stop and report BLOCKED with the path and why.
- Do not commit, push or save the place unless the packet says so. Prime commits.

## 4. Evidence format
- Dir: `.review/agent-workflow/tasks/REVIVAL-001/<PACKET-NAME>/` (`evidence_dir` in the packet). Files: `evidence.md` (required), plus `gate.txt` (raw gate output) and anything else big.
- `evidence.md` line 1 is exactly `RESULT: PASS|FAIL|WAITING|BLOCKED`. Then: task ID, source commit, files changed, gate summary, one line per acceptance item with proof (file:symbol or quoted output), UNVERIFIED list.
- Never put task docs in `docs/` or at `.review/` root.

## 5. No-guess and assets (DEC-008)
- If an asset or instance the code expects is missing (sound, seat folder, model, particle, icon, animation), STOP that part, report BLOCKED with the exact paths and searches tried. Never build a substitute, never record "not found" as "does not exist".
- Studio-authored content is not in Rojo: `workspace.Assets`, `Ordering System`, `ReplicatedStorage.SelectorModels`, `ReplicatedStorage.Networking`, `SoundService.SFX`. Code that depends on it names the exact instance path.
- Code that needs an authored sound or instance must skip silently when it is missing, using the existing patterns: `WorldPath.find(SoundService, { "SFX", "UI", name })` (`src/shared/Utility/WorldPath.luau`, used in `src/client/Modules/AppDialogs.luau` `playUiSound`) and warn-once as in `KitchenService/InteractionRunner.luau`. A missing asset must never error, block play or hide a gameplay result.
- Anything an agent builds after Jack confirms carries `BuiltBy` (e.g. `BuiltBy = "REVIVAL-001-<PACKET-NAME>"`) and is listed in evidence.

## 6. UI rule (STYLE rule 0, DEC-013)
- Replicate, never invent. Use only tokens in `src/shared/UI/Styles.luau`, the `Pane` component and patterns catalogued in `docs/STYLE.md`. No new color, font, radius, spring, asset or layout convention. If nothing fits, the packet's Decisions section already says which existing token to use; if it does not, stop and report.
- Design for phone first: 844x390 aspect, thumbstick bottom-left, jump zone bottom-right. Respect existing anchors (ticket column upper right left of ShiftCard per DEC-052).
- Luau/Knit/React conventions: `docs/CONVENTIONS.md`. Match surrounding file style.

## 7. DEC-053 delegation and HARD STOPS
Jack delegated open-ended design (mechanics, numbers, copy, names, UI spec) to Opus for the approved gameplay set. Packets therefore contain final decisions; workers implement, they do not re-decide. Still Jack's: B5 roster, B6 track rewards, B2 upgrade list (status READY-PENDING-CONFIRM). Economy values (BobaBucks, Points, XP, rewards, prices, probabilities) carry the tag `PROPOSED` in code comments and go to `_meta/ECONOMY-LEDGER.md`.

HARD STOPS (stop, report BLOCKED, ask Prime):
1. Assets that do not exist or are unconfirmed (seat folders, sounds, models, NPC looks).
2. Profile field renames or removals (adding a field is fine).
3. Changes to existing catalog data (IDs, rarities, odds, capsule contents; new entries are fine).
4. Robux products, prices, gamepass or developer-product IDs.
5. Failure screens or join/play blocks.

## 8. Forbidden (all packets)
`git push`, `git reset`, `git clean`, `git checkout -- .`, force anything; edits outside `write_scope`; any edit to `.claude/`; running Play/TestEZ/Studio; changing `TESTS_ENABLED`; bumping the ProfileStore name; any edit under `src/` during the packet-writing phase (packets and docs only); secrets; scope widening.

## 9. Return format (standard-result-v1, <=15 lines)
```
RESULT: PASS | FAIL | WAITING | BLOCKED
SUMMARY: what changed
CHANGED: exact files or "none"
CHECKS: gate/rojo commands and outcomes
EVIDENCE: path to evidence.md
UNVERIFIED: anything not exercised (all runtime behavior)
RISKS: material risks
NEXT: follow-ups
```

## 10. PACKET TEMPLATE
Size limits: packet <=150 lines; big-bet design doc <=400 lines with phase packets <=200 each.
```
---
id: <PACKET-NAME>
title: <short>
priority: P0|P1|P2
role: Mason|Lens|Rigger|Quill|Sentry
worker_tier: haiku-ok | sonnet | opus
release_gate: before | after
depends_on: [<packet names>]
status: READY | READY-PENDING-CONFIRM | BLOCKED-ON-ASSET
source_commit: <hash the excerpts were verified at>
read_scope: [exact paths, symbols]            # haiku: <=6 files
write_scope: [exact paths, symbols]
invariants: [serve-path no-yield, DEC-013, ...]
acceptance: [observable pass conditions]
checks: [gate command, rojo build]
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/<PACKET-NAME>
forbidden: [see WORKER-PRIMER 8, plus packet-specific]
---
```
Body sections, in order:
1. Source excerpt (idea IDs and their review text, verbatim).
2. Decisions made: D1..Dn, each final with a one-line rationale. No questions, TBD, maybe, consider.
3. Exact strings (copy, toast text, labels; `PROPOSED` marks on economy copy).
4. Exact numbers (constants with names; economy values tagged PROPOSED).
5. Signatures and event names (function signatures, remote/attribute/event names, profile field names).
6. UI spec, if any: anchor, size, tokens, springs, copy, states, phone 844x390 behavior.
7. Studio checks (for Jack; batchable into one milestone run).
8. Asset prerequisites (exact instance paths; skip-silently behavior).
9. Open items: none (or an explicit list).
10. Summary block (<=8 lines).

Lint (reject the packet if any is true): contains `TBD`, `maybe`, `consider`, `or alternatively`, `decide later`; a `?` inside Decisions; missing `Open items:` line; over the size limit; write_scope names a file also written by a packet not in its depends_on chain.

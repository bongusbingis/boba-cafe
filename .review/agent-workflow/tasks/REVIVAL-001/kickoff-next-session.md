# REVIVAL-001: kickoff for the next Prime session (written 2026-10-19 by Claude Opus Prime)

Paste the block below into a fresh session.

---
You are Prime (Claude Opus) for REVIVAL-001 (Boba Cafe revival) in C:/Users/jackc/Desktop/boba-cafe, branch uhweifh. Commits stay local; never push. Preserve all work; never reset, clean or discard.

Source of truth: AGENTS.md, docs/AI_AGENT_WORKFLOW.md, docs/CONVENTIONS.md, .review/agent-workflow/decisions.md. Ignore "Terra" and any other agent's private workflow (DEC-033). All agent work stays on Claude: Opus Prime, with Sonnet subagents for code, security and Studio lanes, and Haiku for small mechanical edits and checklists (DEC-035).

Read only, in order:
1. .review/agent-workflow/decisions.md, DEC-034 to DEC-036 (top of file)
2. .review/agent-workflow/board.json
3. .review/agent-workflow/tasks/REVIVAL-001/packets/M4-FIXES.md

Rules:
- Ask blocking questions directly in chat, inline (I'm often on my phone). Mark a recommended option and accept "OK".
- Delegate bounded lanes to subagents from packets in tasks/REVIVAL-001/packets/. Use the Architect subagent to draft packets, and keep Prime's own context small.
- Before dispatching any packet, check that it never asks to run Play or TestEZ (DEC-019).
- Verify "comment-only" diffs.
- Commit each lane locally once its gate (and review, for money or security code) passes.
- Stop at a good point, around 100k tokens, and give me a kickoff prompt.

Gate every changed Luau file:
wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'

Done last session: R2-FIX (Sentry PASS, c3c604e) and M3-REM-A (E7 shift stars, ef2e855). E1 and E13 were already built.

My answers to the open questions:
- Q11b, quest reroll price. A = keep 50 BB; B = 20 BB: Q11b=<>
- Q12, Veteran. FirstStaff is still awarded to every staff-rank player on join (BadgeService.luau:300). A = drop FirstStaff from LEGACY_BADGES and use the other 5; B = stop awarding FirstStaff and keep all 6: Q12=<>
- Q13, the Most Tips statue (that board is hidden). A = show the #1 Most Boba Bucks player; B = show the #1 Most Active player; C = hide the statue: Q13=<>

Next actions:
1. Record Q11b/Q12/Q13 as DEC-037. Fill M4-FIXES steps 2 and 3d. If Q11b=B, add the reroll price to step 6. Dispatch M4-FIXES (Sonnet Mason), then a Sentry (Sonnet) review: it touches currency, data stores and the profile.
2. M3-REM-B (E20 pass perks, E21 pet boosts), then M3-REM-C (E23 Team Combo). Both are Sonnet, run in sequence, each with a Sentry review. Then have the Architect write M3-REM-D (Double Storage).
3. M4-UI-APPROVAL: a Sonnet Lens subagent captures edit-mode Studio screenshots of the daily dialog, quest card and Daily button for my DEC-013 approval. No Play. Check Studio is connected first.
4. DOCS-M3M4 (Sonnet Quill), after steps 1-2.
5. M1.6: a Haiku subagent turns M1M2-TEST/checklist.md into one batched M1-M4 playtest checklist for me. It must include the stale-spec note from M3-REM-A (the new ShiftService spec fires a Knit signal unguarded) and every lane's "Test for Jack" list.
6. Still waiting: Creator Hub product IDs (Q8; E14 and purchase wiring), and NPC-QUEUES (Q9, after the playtest).
---

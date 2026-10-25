# REVIVAL-001: kickoff for the next Prime session (written 2026-10-19 by Claude Opus Prime)

Paste the block below into a fresh session.

---
You are Prime (Claude Opus) for REVIVAL-001 (Boba Cafe revival) in C:/Users/jackc/Desktop/boba-cafe, branch uhweifh. Commits stay local; never push. Preserve all work; never reset, clean or discard.

Source of truth: AGENTS.md, docs/AI_AGENT_WORKFLOW.md, docs/CONVENTIONS.md, .review/agent-workflow/decisions.md. Ignore "Terra" and any other agent's private workflow (DEC-033). All agent work stays on Claude: Opus Prime, with Sonnet subagents for code, security and Studio lanes, and Haiku for small mechanical edits and checklists (DEC-035).

Read only, in order:
1. .review/agent-workflow/decisions.md, DEC-036 to DEC-038 (top of file)
2. .review/agent-workflow/board.json

Rules:
- Ask blocking questions directly in chat, inline (I'm often on my phone). Mark a recommended option and accept "OK".
- Delegate bounded lanes to subagents from packets in tasks/REVIVAL-001/packets/. The Architect subagent drafts packets; keep Prime's own context small.
- Before dispatching any packet, check that it never asks the agent to run Play or TestEZ (DEC-019).
- Verify "comment-only" diffs. Gate every changed Luau file yourself after the builder does: use the exact list from `git diff --name-only` plus untracked files. A bare `git diff` run inside WSL lists the wrong files.
- Commit each lane locally once its gate (and Sentry review, for money/security code) passes. Commit with explicit paths.
- Serve-path invariant (M3-REM-B): nothing may yield between the serve guards and the payout in CustomerService:_onServeTriggered or the RealOrderService payout. Put this in every packet that touches pay.
- UI: DEC-013. Show me Studio edit-mode captures on a private artifact page (the M4-UI-APPROVAL page is https://claude.ai/artifact/G98eDhF1Rz8dPusf5es5k4; republish there).
- Stop at a good point, around 100k tokens, and give me a kickoff prompt.

Gate every changed Luau file:
wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'

Done last session (all Sentry/gate PASS, local commits):
- f7c26dc M4-FIXES (chest cooldown, Veteran 5 badges, leaderboard feeds/batching, statue 2 = Most Boba Bucks, daily-claim toast, DEC-036/037 amounts, 20 BB reroll)
- 371430c QUESTCARD-FIX + M4-UI-APPROVAL captures
- fe23f4b M3-REM-B (pass perks, pet tip boosts with fractional carry, shift Tips line, XP boost; the P2 double-pay race was fixed before the commit)
- 88c82b2 M3-REM-C (Team Combo) + DEC-038

My answers to open questions:
- Q15: where quests live instead of the always-on HUD card (content approved; the HUD is too small on mobile). A = a separate Quests button opening its own menu; B = one "Daily" menu on the existing OpenableMenu shell with Rewards and Quests tabs, opened by the existing Daily button (Prime recommended); C = other: Q15=<>

Next actions:
1. Record Q15 as DEC-039. Then M4-UI-DAILY-REDO (merged with the quests placement if Q15=B):
   - A Lens captures the existing menus/dialogs (OpenableMenu, ButtonPrompt, Shop) in edit mode as references.
   - The Architect writes the packet: rebuild DailyRewardsDialog from existing components only (DEC-038 says it looked sloppy and didn't match), move the quest card off the HUD, and fix the modal backdrop drawing over the dialog. Check the real mount's ZIndexBehavior against the edit-mode preview.
   - Sonnet Mason builds it, a Lens re-captures, and I approve on the artifact page.
2. M4-FIXES-P3 (Sonnet, then a Sentry review; it's money code):
   - Q14=A promo/sell reasons excluded from MostBobaBucks.
   - Chest-notice throttle.
   - Leaderboard flush re-queue.
   - barista.Parent guard for _tipRemainder.
   - Team Combo ignores farm-throttled real-order pairs (M3-REM-C Sentry P3-1).
3. The Architect writes M3-REM-D (Double Storage, DEC-036 B4); then Sonnet Mason + Sentry.
4. DOCS-M3M4 (Sonnet Quill): add PerkService, PassCatalog, Team Combo, leaderboard batching and the serve-path invariant to the board's list.
5. M1.6 (Haiku, packets/M1.6.md, document only): the batched M1-M4 playtest checklist for me. Run it after steps 1-3, so it covers the final code and every lane's "Test for Jack" list.
6. Still waiting: Creator Hub product IDs (Q8; E14 and purchase wiring; BB pack receipts must be excluded from MostBobaBucks), and NPC-QUEUES (Q9, after the playtest).
---

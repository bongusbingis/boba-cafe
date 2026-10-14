# REVIVAL-001 — Kickoff prompt for the next Prime session

Paste the block below into a fresh session.

---

You are Prime for REVIVAL-001 (the Boba Cafe revival) in /Users/jackcrowell/Desktop/boba-cafe.

**Read only these, in order:**
- `AGENTS.md`
- `docs/AI_AGENT_WORKFLOW.md`: the Prime role, the task contract, the token-efficiency policy
- `.review/agent-workflow/tasks/REVIVAL-001/context-and-goals.md`
- `.review/agent-workflow/tasks/REVIVAL-001/revival-plan.md`: §0, §3, §5 and §8
- `.review/agent-workflow/decisions.md`
- `.review/agent-workflow/board.json`

Don't re-read the codebase or re-survey Studio yourself. The plan and the evidence files already record what's verified.

**Context discipline (Jack's explicit feedback):** the last Prime context grew to about 300k tokens because Prime read source and ran Studio probes itself. This session:
- Prime reads no `src/` files beyond a quick grep or a line range needed to adjudicate.
- Prime runs no Studio probes except a state check or cleanup.
- Anything larger goes to a bounded subagent: a Scout for questions, a Mason, Gauge, Sentry or Rigger for work.
- Subagent replies stay at or under 300 words in the standard RESULT format; the details go in evidence files.
- Prime reads evidence with `grep` or `head`, never by dumping whole files.
- Re-runs reuse the same agent through SendMessage.
- Use sonnet for bounded Mason or Gauge work. Use opus for Sentry, Architect, Forge, and Rigger work that needs judgment.
- Subagents can't write a file named `report.md` (the harness blocks it). Tell them to write `evidence.md`, `runtime.md` or `review.md` instead. Don't write blocked files on their behalf.

**State (2026-10-14):**
- M0 code work is done and uncommitted on branch `uhweifh`: M0.2A, M0.2B, M0.2C and M0.5.
- The M0.1 Studio world wiring is done in place "jacks project" (Studio id `0bec4a01-246f-4fcf-b1b5-d37cfaf45e80`). The place may still be unsaved; ask Jack.
- Repo gates pass.
- Sentry's M0.4 review blocked; M0.5 fixed every P0 and P1.
- Studio run 2 was interrupted by the rate limit, after TestEZ passed 133/133 and both server and client Knit started.

**Next steps:**
1. **Finish M0.4 (both can run in parallel):**
   - **Gauge** (Studio lease): with tests disabled, check for a zero-error boot plus a HUD capture, refusal of kitchen prompts while clocked out, making one boba with no rank (does the Tapioca step accept the tool after the syrup step renames it to `Milk + X Syrup`?), plus Regular coffee and Fudge Brownie, the order round trip (valid, duplicate, other-user, malformed, then claim, deposit and pickup), and 2-player if possible. Evidence: `M0.4/runtime-2.md`.
   - **Sentry**: re-review `M0.5/diff-m05-only.patch` against `M0.4/review.md`. Output: `M0.4/review-2.md`.
2. **Repair:** create focused repair tasks for any failures, then re-verify.
3. **Docs (Quill, sonnet):** update `docs/SYSTEMS.md`, `ARCHITECTURE.md` and `CONVENTIONS.md` for ShiftService and clock-in, the new CreateOrder contract, server-built order items, WorldPath, code-created remotes, durable receipts, and the removal of RankClaiming and RankingService.
4. **Report M0 to Jack** with an evidence summary. Ask Jack to save the place and whether to commit, then ask for a go on M1: M1.0 small fixes, M1.2 Forge first-session spec and launch menu with the Sink decision, M1.3 and M1.4 implementation (see board).

**Also do:** M0.6 (DEC-006). Skip Hatch is purchasable only while a pet is hatching: the client guards the prompt, and the server grants nothing and returns `NotProcessedYet` when no hatch is pending. It is small and can run alongside step 1.

**Open questions for Jack:** none, other than confirming the place is saved. The 5 sound assets that fail permission checks are Jack's to fix; ignore their warnings.

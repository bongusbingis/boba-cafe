# REVIVAL-001: kickoff for the next Prime session (written 2026-10-19 by Claude Opus Prime)

Paste the block below into a fresh session, with Jack's answers filled in.

---

You are Prime (Claude Opus) for REVIVAL-001, the Boba Cafe revival, in C:/Users/jackc/Desktop/boba-cafe on branch `uhweifh`.
Commits are local only; never push. Preserve all work and never reset, clean or discard.

**Source of truth:** `AGENTS.md`, `docs/AI_AGENT_WORKFLOW.md`, `docs/CONVENTIONS.md` and `.review/agent-workflow/decisions.md`.
Ignore "Terra" and any other agent's private workflow (DEC-033).

**Read only these, in order. Use `head` or `grep` for anything large:**
1. `.review/agent-workflow/decisions.md`: DEC-029 to DEC-034.
2. `.review/agent-workflow/tasks/REVIVAL-001/AUDIT-2026-10-19/evidence.md`: the full audit state and open findings.
3. `.review/agent-workflow/board.json`.
4. `.review/agent-workflow/tasks/REVIVAL-001/R2-SECURITY/review.md`: the security findings, lines 1-45.

**Working rules from Jack:**
- Ask blocking questions directly in chat, inline (Jack is often on his phone).
- Delegate bounded lanes to subagents from packets in `tasks/REVIVAL-001/packets/`. Keep Prime's own context small.
- Stop at a good point and give Jack a kickoff prompt before the context gets large.
- Agents never run Play or TestEZ (DEC-019).
- Gate every changed Luau file:
  `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`

**State:**
- The checkpoint commit `f06a9bf` preserves all prior Codex and Gemini work.
- The next commit holds the audit corrections:
  - reverted the transaction-lock clear in CapsuleService:PlayerRemoving;
  - removed the redundant distance check in OrderService:_handlePickUp;
  - added the Boba Party `BobaPartyCooldownEndsAt` workspace attribute;
  - saved the audit, R2-SECURITY, the board and the decisions.

**Next actions:**
1. **R2-FIX** (READY; no Jack input needed). Dispatch a Mason subagent with a packet. Fix three R2-SECURITY findings:
   - **P1-1:** a player can serve their own real order. Skip orders where customer == staff, and pay no real-order bonus to self.
   - **P2-1:** daily and chest capsules must be tagged `RandomSource = "FreeEarned"` through one shared helper, not the monkey-patched shims.
   - **P3-1:** use one per-player lock shared by ClaimQuest and RerollQuest.

   Then dispatch a fresh Sentry subagent to re-review R2-FIX, and gate it.
2. Apply Jack's answers below to the blocked board tasks, one bounded lane per task.
3. **DOCS-M3M4** (Quill, haiku).
4. Extend `M1M2-TEST/checklist.md` into a single batched M1-M4 checklist for Jack (M1.6).

**Jack's answers (Q1-Q10):**
- Q1 M4 reward amounts (daily 50-300 BB plus the 20h cooldown; chests 35-100 BB with a 15% capsule chance; quests 40-75 BB / 20-40 XP). Options: A = Prime writes a proposal sized against the 9 BB/min anchor; B = approve as coded; C = I give the numbers. **Q1 = <>**
- Q2 Per-player treasure-chest limit. Options: A = per-player cooldown (one chest every N minutes); B = daily cap of N chests; C = no limit. **Q2 = <> (N = <>)**
- Q3 Veteran title, definition of a legacy badge. Options: A = any listed badge awarded before a cutoff date (give the date, or "launch day"); B = only badges the revival no longer awards (FirstQuest, Celebrity, SakuraIsland, ShinyPet, HalloweenEvent, FirstStaff); C = disable Veteran for now. **Q3 = <>**
- Q4 Monthly leaderboard metrics. Options: A = Most Tips = BobaBucks earned this month, Most Boba Bucks = BobaBucks earned, Orders Served = serves, Most Active = minutes played, Top Donators = Robux spent on dev products; B = wire Orders Served, Most Active and BobaBucks earned, and hide Most Tips and Top Donators; C = custom (describe). **Q4 = <>**
- Q5 A daily or chest capsule when the Capsules inventory is full. Options: A = refuse the daily claim with "Inventory full" until there's space; the chest gives BobaBucks only (no capsule roll) when full; B = save a pending capsule and grant it later; C = give BobaBucks instead of the capsule (needs an amount). **Q5 = <>**
- Q6 New M4 UI (the daily-reward dialog that pops up on join, the quest HUD card, the Daily button in the bottom-left). Options: A = approve after Prime sends Studio screenshots; B = approve now as built; C = change it (describe). **Q6 = <>**
- Q7 Approved but unbuilt M3 items (E1 +1 per Iced/Sugar option, E7 shift star pay, E13 shift XP, E20 pass perks, E21 pet tip boosts, E23 Team Combo, E14 live Robux price display). Options: A = build now, after R2-FIX; B = after the M4 fixes; C = later (state when). **Q7 = <>**
- Q8 Creator Hub product IDs, for when you have them: Boba Party = <>, BobaBucks packs (50/150/500/1000/5000) = <>, capsule Robux products = <>. Otherwise write "not yet". **Q8 = <>**
- Q9 Your Oct-16 instruction to Gemini (NPCs queue per register, use PathfindingService, reuse the register and pick-up nodes). Options: A = still wanted, add it as a task; B = superseded by the current NPC flow (DEC-022); C = revisit after the playtest. **Q9 = <>**
- Q10 Studio saves. Did you save "jacks project" after FIX-SOUNDGROUPS (Music SoundGroup) and RIG-1? **Q10 = <yes/no/unsure>**

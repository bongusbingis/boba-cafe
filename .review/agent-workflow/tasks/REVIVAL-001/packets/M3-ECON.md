# M3-ECON: Economy proposal for Jack's M3 gate
Model: sonnet   Studio: no   Depends on: none (read-only; can start during M2)   Size: M

## Goal
A keeper-owned economy proposal doc with a sink/source model and concrete PROPOSED numbers for Jack's M3 approval gate. Nothing is implemented. Every number is marked `-- PROPOSED (Jack)` / `PENDING JACK`. Settled by revival-plan §4.5, §4.6, §6.3 and DEC-014 (full plan M1–M7; Jack approves every number).

## Read (only these)
- `revival-plan.md` §4.5 (lines 231-253), §4.6 (lines 255-275), §6.3 (lines 348-390)
- `src/server/Modules/CurrencyService.luau` (whole; note `Modify` and whether `TrySpend` exists)
- `src/server/Modules/CapsuleService.luau` (whole; capsule costs and odds as coded)
- `src/shared/Configuration/CapsuleConfig.luau`, `GamepassConfig.luau`, `Gamepasses.luau` (whole each)
- `src/shared/Configuration/CustomerConfig.luau` (`PAY_TABLE` as built by M1.4e) and `src/shared/UI/Pages/Shop/` (which tabs read real data vs mock)
- `M1.2/design.md` §5.8 (pay/payout intent) if it exists

## Write scope
- `.review/agent-workflow/tasks/REVIVAL-001/M3-ECON/proposal.md` (new)
- `.review/agent-workflow/tasks/REVIVAL-001/M3-ECON/evidence.md` (new; RUNBOOK step 5 note)

## Steps
1. **Sources table.** Every BobaBucks/XP source as coded or planned: per-serve pay (M1.4e `PAY_TABLE` + multipliers), tips, shift payout, spill XP/Cafe Rating, Premium Payouts. Cite the code or plan line behind each.
2. **Sinks table.** Capsules (existing prices/odds), direct cosmetics, capsule skip with BobaBucks, Cafe upgrades sink (plan-only). Cite config values.
3. **Balance model.** Using the §4.5 starting proposals (basic pay 5–8 BB, Perfect tip +50%, combo +5%/streak cap +50%, real-player +100%; Regular capsule ≈ 10–15 min play; Epic ≈ 2–3 h; XP curve L2 first shift, L10 end of day 1, L50 ~1 month): show minutes-of-play per sink and flag any sink that prices out of its intent. Do not change numbers; model them.
4. **Monetization list.** Developer product set (§4.6: BobaBucks packs, Skip hatch, direct capsule, 30-min 2× tips, server-wide Boba Party, tip-jar donation) with PENDING JACK price questions; pass catalog + legacy remap status (§6.3; `Gamepasses.luau` knows 11 of 14 on-sale + 34 off-sale — list the gap).
5. **Gate questions for Jack.** One PENDING JACK question per number/price/odds he must approve, each with the proposal and the consequence of saying no. Economy/prices need Jack (AGENTS.md boundaries) — this lane proposes, never decides.
6. No code edits, no gate run (no .luau changed). No Studio.

## Done when
- `proposal.md` covers sources, sinks, balance model, monetization list, and numbered PENDING JACK questions, each with a code/plan citation.
- No number is presented as decided; all are PROPOSED.

## Checks to run
- None (read-only lane). Studio: NOT RUN.

## STOP-AND-ASK
- A source or sink has no code or plan value to cite: mark it UNKNOWN in the proposal and keep going; do not invent a value.

## Evidence
`tasks/REVIVAL-001/M3-ECON/evidence.md` (RUNBOOK step 5; RESULT line + proposal path + count of PENDING JACK questions).

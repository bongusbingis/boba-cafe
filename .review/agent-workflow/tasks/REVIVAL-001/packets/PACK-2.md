# PACK-2: Write the M2 build packets
Model: sonnet   Studio: no   Depends on: PACK-1 (done)   Size: M

## Goal
Turn milestone M2 (core game) into explicit packets that a weaker agent can execute without making any design decision (DEC-016). You write packets only, no code.

Decisions in force:
- **DEC-011:** Q1-Q6 and Q10-Q18 approved as recommended.
- **DEC-015:** asset answers.
- **DEC-014:** full plan.
- **DEC-013:** UI copies `docs/STYLE.md`.
- **DEC-017/018:** quick code is fine; no specs except for money and data.
- **DEC-019:** Jack does all testing.
- **Placeholder numbers:** XP and other PROPOSED numbers from design §5 go in config, commented `-- PROPOSED (Jack)`, the same way as Q6 placeholders. The real values are set at the M3 economy gate.

## Read (only these, by line range)
- `packets/README.md` (the format), `RUNBOOK.md`, and `packets/M1.4e.md` (as an example of the level of detail)
- `.review/agent-workflow/decisions.md`: the top entries, DEC-011 to DEC-020
- `M1.2/design.md`:
  - §4.9 and §4.10 (lines 271-286)
  - §5.1 to §5.4 and §5.6 (lines 287-347)
  - §6 (lines 367-381)
  - §7 (lines 382-410)
  - §8 (lines 411-422)
  - the M2 outline (lines 482-492)
- `revival-plan.md` §8 M2 (grep "### M2"; about 12 lines) and §4.7 (lines 277-297)
- Code: grep only, for function names and signatures, in:
  - `src/server/Modules/ShiftService.luau`
  - `src/server/Modules/CustomerService/init.luau`
  - `src/server/Modules/OrderService.luau`
  - `src/server/Modules/SpillService/init.luau`
  - `src/server/Modules/StatisticsService.luau`
  - `src/shared/Configuration/ProfileTemplate.luau`
  - `src/shared/UI/Components/Core/Hud/`

  Open at most 6 files, by line range.

## Write scope
- `packets/<ID>.md` for each ID below
- `packets/INDEX-M2.md`
- `tasks/REVIVAL-001/PACK-2/evidence.md`

## Packets to write (sonnet unless noted)
1. **M2-SHIFT:** count-based shifts (Q11).
   - 10 customers per shift, 5 for the first shift.
   - A non-blocking end-of-shift card that auto-continues (design §5.1-§5.2). It is a UI card, so copy the STYLE.md dialog or HUD pattern and name the exact component to copy.
2. **M2-PROGRESS:** `ProgressionService` and `Configuration/Progression.luau`.
   - XP per serve (§5.4 PROPOSED).
   - Levels 1-50 with no locks (Q10).
   - The level pool widens NPC orders.
   - A 2nd ticket slot at L5.
   - Cosmetics every 5 levels (name the existing cosmetic grant path by grep).
   - Profile fields `Level` and `XP`.
   - A level-up toast through the existing Toast.
3. **M2-REALORDER:** real-player orders (§4.9, Q17).
   - Auto-dispatch to baristas.
   - A customer bubble.
   - The customer keeps the drink and gets a "Regular" stat and quest progress (stub hook only; quests are M4).
   - The barista gets ×2 pay for the first 3 orders from the same customer within 10 min (PROPOSED).
4. **M2-VARIANTS:** VIP and Karen NPC variants (§4.10), using the Karen description from DEC-015. Unlock levels follow Q10. Also NPC seating after a serve, if §4 describes it; otherwise leave it out.
5. **M2-RATING:** Cafe Rating plus Rush Hour (§5.6), built on SpillService cleanliness.
   - Spills, fast serves and failures move the rating.
   - At 100%, Rush Hour runs: more NPCs and 2× tips (PROPOSED duration).
   - Fix the known SpillService 100% crash (`docs/SYSTEMS.md` "Known gap"; grep `BoostMultiplier`).
6. **M2-AREAS** (Studio: yes; Rigger): area limiting per Q20 and §8. The cafe is open from the start. Break areas open at L3 (server check plus an invisible wall or teleport, whichever §8 says). The far desert gets boundary walls. Reuse existing parts; never delete.
7. **M2-RECIPEBOOK:** a recipe book page generated from `OrderSpec.Steps`. It replaces the rank-gated Staff Guide (grep `Staff Guide`). The page copies the STYLE.md §4.1 page recipe.
8. **M2-TRASH-FOLLOWUP:** none. Skip it; TRASH already exists.

For each packet, list the exact write files. Make sure no two packets write the same file at the same time; in INDEX-M2.md, name the conflicts and the order to run them in.

## Done when
- Every packet follows the template, with no "decide", "choose" or "as appropriate".
- Every open point is a STOP-AND-ASK.
- INDEX-M2.md exists.

## STOP-AND-ASK
- none. Record design gaps as STOP-AND-ASK lines inside the affected packet.

## Evidence
`tasks/REVIVAL-001/PACK-2/evidence.md` (5 lines)

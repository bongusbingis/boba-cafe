# PACK-1: Write the packets that finish M1
Model: sonnet   Studio: no   Depends on: none   Size: M

## Goal
Turn the rest of milestone M1 into explicit packets that any agent can follow, including a weaker non-Claude agent (DEC-016), with no open design decisions. All design is settled: DEC-011 (design Qs), DEC-015 (asset Qs), DEC-017 (quality bar). You write packets only. You change no code.

## Read (only these, by line range)
- `packets/README.md` (the format; follow it exactly) and `RUNBOOK.md`
- `.review/agent-workflow/decisions.md`: DEC-011 to DEC-017 only (the top of the file)
- `M1.2/design.md`:
  - §4 (lines 200-286, NPC customers)
  - §3.2-§3.6 (lines 108-148)
  - §5.8 (lines 353-366, placeholder pay values)
  - §9 (lines 423-492, task rows and acceptance)
- `R1/review.md` lines 31-47: findings that later packets must respect. R1-FIX is fixing P1-1, P1-2, P2 and P3-6 to P3-9; P3-5 goes to Q14-GATES.
- `S3/evidence.md` lines 83-133: v4 paths for the imports
- `M1.4core/evidence.md` lines 1-80: the current CustomerService API
- `M1.5cd/evidence.md`: the head, plus its Gauge steps and its guessed ticket shape (M1.4f must define the real one)
- Code: names only. Use `grep -n` for function names and signatures. Do not read whole source files. Open at most 6 source files, by line range.

## Write scope
- `.review/agent-workflow/tasks/REVIVAL-001/packets/<ID>.md` for each ID below
- `.review/agent-workflow/tasks/REVIVAL-001/packets/INDEX.md`
- `.review/agent-workflow/tasks/REVIVAL-001/PACK-1/evidence.md`

## Packets to write
Use these IDs. Where a design row exists, cite its line instead of copying it.

1. **M1.4e** (sonnet): server tickets and serve.
   - Q1 auto-assignment and Rescue at 30% patience.
   - Q2 Serve prompt on the NPC.
   - Order generation through `FromOrderItem`; patience attributes; the bubble colour chip.
   - `FindServeTools`, ignoring `Served` tools (R1-FIX).
   - Payout from the §5.8 placeholder values, which go in `CustomerConfig.PAY_TABLE` commented `-- PROPOSED (Jack)`, per Q6.
   - Q5 mistakes, combo, walkout.
   - Reassignment on leave or clock-out.
   - The Q4 first-session script (the first 3 orders fixed, with paused patience).
   - `Statistics.CustomersServed`.
   - `Client.TicketChanged`. Define the ticket table shape explicitly in the packet.
   - Specs only for the payout math (DEC-017).
2. **M1.4f** (sonnet): client ticket.
   - Map `TicketChanged` onto `OrderController.CurrentOrder` using the exact shape from M1.4e.
   - Update `KitchenGuidance.ResolveSpec` and its Serve-step field to that shape.
   - Serve and Rescue prompt visibility.
   - Bars on OrderTicket per STYLE.md.
3. **Q14-GATES** (sonnet):
   - Station gates check attributes instead of names, so ice and sugar can go in either order.
   - Coffee Machine hold 7 → 4 s; Ice Machine hold 5 → 3 s.
   - Fix the "sugar before ice" spec (R1 P3-5).
   - Name the exact Recipes and RecipeConstructors entries to change (grep them).
4. **IMPORT-V4** (sonnet; lune only, no Studio): extract from `git show main:boba-v4.rbxl` into `.rbxm` files under `C:\Users\jackc\AppData\Local\Temp\boba-gate\v4-import\` (WSL: `/mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/v4-import/`). Extract:
   - `ReplicatedStorage.SharedStorage.CleanlinessStorage`
   - from `NPCStorage`: Karen and Animations
   - `KitchenStorage.Assets.S_DefaultUniform` and `P_DefaultUniform`

   Every top-level instance gets `BuiltBy="REVIVAL-001-import-v4"`. Separately, write v4's CustomerConfig dialogue pools into a new Luau data module, `src/shared/Configuration/CustomerDialogue.luau`. The packet must give the exact lune script steps, using `tools/extract.luau` from main as the base.
5. **RIG-1** (sonnet; Studio: yes; one pass, DEC-012):
   - Insert the IMPORT-V4 `.rbxm` files with File > Insert from File. Computer use is allowed (DEC-012).
   - Move them to the paths SPILLS and NPC-LOOK expect.
   - Interior SpawnLocations per Q7 (at most 30 studs walk to the Clear Cup station). Disable the old outside spawns; don't delete them.
   - Author `workspace.Assets.NPC.{Entry, Exit, Path, Queue, Counter}` per the M1.4a row and the M1.4core contract (anchored, CanCollide off, Transparency 1), cloning `OldScriptables.NPCFolder` nodes where they fit.
   - Spill areas per SPILLS.
   - Confirm the 6 trash can paths for TRASH.
   - Take one capture for Jack, of the spawn and counter.
   - Save to Roblox.
6. **SPILLS** (sonnet): repoint SpillService at `SharedStorage.CleanlinessStorage` (Q24). Spills spawn and can be cleaned. Cafe Rating and Rush Hour are M2 and NOT in this packet.
7. **TRASH** (sonnet): Q9 v4 behaviour. A "Use" prompt shows "Throw Away?" Yes/No through the existing dialog (STYLE.md §3.5), discards the held tool, and refuses tools with `NotDisposable`.
8. **NPC-LOOK** (sonnet): Q25.
   - NPCs pick from the 10 `SharedStorage.NPCs` descriptions, plus Karen kept for M2 variants.
   - Wave on arrival, Confused on a Wrong serve, Idle while waiting.
   - Bubble lines from `CustomerDialogue`.
   - Baristas wear the Default uniform while clocked in and get their own clothes back on clock-out.
9. **M1.MEASURE** (sonnet): AnalyticsService funnel and custom events per plan §4.8 (`revival-plan.md` lines 298-304). Hook points named by grep.
10. **Q-DOCS-M1** (haiku): `docs/SYSTEMS.md` and `docs/ARCHITECTURE.md` entries for:
    - OrderSpec and tool attributes;
    - auto-match deposit and Served;
    - the launch allowlist;
    - the CustomerService world contract, `workspace.Customers`, and the NPC/CafePlayers collision groups;
    - KitchenGuidance;
    - the new world paths from RIG-1.
11. **M1.6** (sonnet; Studio: yes; ONE batched run). It covers:
    - TestEZ (RunTests attribute);
    - the M1.4core smoke test;
    - the Gauge steps from the M1.5cd, R1-FIX and later evidence files;
    - a solo first-session timing on a fresh profile with phone emulation, against the targets at design lines 470-480;
    - 0 errors.

    Everything goes in one pass, with captures only where a visual matters.

`INDEX.md`: a table of ID, depends-on, model, Studio yes/no, and status ("ready" or "waiting on X"), in a recommended order that parallelises safely. Two packets that write the same file must not run at the same time; name the conflicts.

## Done when
- Every packet follows the README template and lists exact read and write paths.
- No packet contains "decide", "choose", "as appropriate", or a design question that DEC-011 or DEC-015 already answer.
- Any truly open point is a STOP-AND-ASK line.
- INDEX.md exists.

## STOP-AND-ASK
- none. If you find a design gap that the decisions don't answer, write it as a STOP-AND-ASK inside that packet and list it in your evidence.

## Evidence
`tasks/REVIVAL-001/PACK-1/evidence.md`

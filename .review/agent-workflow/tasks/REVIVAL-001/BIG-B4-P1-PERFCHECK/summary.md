RESULT: PASS
Task: BIG-B4-P1-PERFCHECK (phase P1 ONLY: inert flag + Studio stress hook)
Source commit: 098175c

CHANGED:
- NEW src/shared/Configuration/SeatingConfig.luau (packet exact whole-file contents;
  lines without a shown comment carry `-- PROPOSED (tuning)`; ENABLED = false)
- src/server/Modules/CustomerService/init.luau: +RunService require,
  +SeatingConfig require, +_stressSeen field, +_seatingOn/_seatBudget/_stressMode/_stressTick,
  +_pacingLoop stress hook (3 lines), ~_pacingTarget rush-branch condition (1 line).
  _onServeTriggered untouched. Npc.luau, CustomerConfig.luau, RatingConfig.luau untouched.
  No seat behavior (P2/P3); no seat folder referenced.

ACCEPTANCE:
- SeatingConfig.luau exists, every "Exact numbers" constant present, ENABLED = false: YES
  (src/shared/Configuration/SeatingConfig.luau)
- Inert with flag off and no B4 attributes (behaviour = HEAD): YES by construction --
  _stressMode returns nil outside Studio / without B4Stress, _pacingLoop then runs the
  original three statements; _seatingOn/_seatBudget are read by nobody yet (P2).
- Studio S1/S2/S3 + perf.md: NOT RUN (DEC-019; workers never run Play/Studio).
  Perf protocol left for Prime/Jack; perf.md unwritten per instructions.

CHECKS:
- gate (selene new=0 + stylua ok on both files, gate rojo build PASS): PASS -- see gate.txt
- rojo build default.project.json -o /tmp/boba-b4p1-out.rbxlx (WSL /tmp, outside repo):
  PASS (Built project, 4076160 bytes). No artifact left in repo.

UNVERIFIED: all runtime behavior (Studio stress Run/Drain flow, 4 s auto-serve, no-pay
  invariant, perf numbers). Nothing was executed in Studio per DEC-019.
RISKS: none new; P1 is inert when the flag is off and attributes are unset.
NEXT: Prime/Jack run the perf protocol (Run A S1/S2) and record perf.md; P2/P3 build seating.

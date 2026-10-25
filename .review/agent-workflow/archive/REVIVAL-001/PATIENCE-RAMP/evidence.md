RESULT: PASS
task: PATIENCE-RAMP (REVIVAL-001)
source_commit: 098175c
files_changed:
  - src/shared/Configuration/CustomerConfig.luau (3 PROPOSED constants after PATIENCE_RED_FRACTION)
  - src/server/Modules/CustomerService/Rules.luau (Rules.PatienceRampMult + sessionShift third arg on PatienceSeconds, no rounding)
  - src/server/Modules/CustomerService/init.luau (_sessionShifts field, _sessionShiftOf, _assign call-site, ShiftEnding handler in pcall, PlayerRemoving clear)
  - src/server/Tests/CustomerService.spec.luau (17 new cases appended; existing untouched)
gate: PASS (selene new=0 all files, stylua ok all files, rojo build ok). Raw output in gate.txt.
acceptance:
  - Rules.PatienceSeconds returns old value for nil/1/2, 5% less at shift 3, 10% at shift 4+: Rules.luau:PatienceRampMult/PatienceSeconds; spec cases 8-14.
  - Non-scripted NPC in shift 3/4+ gets trimmed PatienceTotal; scripted passes nil: init.luau:_assign (scripted -> nil else _sessionShiftOf); spec cases 10-12.
  - VariantPatience composes after ramp: _assign nests VariantPatience(PatienceSeconds(...)); spec case 16.
  - Counter resets on leave, no profile use: PlayerRemoving clears _sessionShifts; only ShiftEnding/PlayerRemoving touch it.
  - 17 spec cases written (not run per DEC-019): spec.luau describes "PatienceRampMult (C6)" (7) + "PatienceSeconds with a session shift (C6)" (10).
ledger: ECONOMY-LEDGER.md already lists all three PATIENCE-RAMP rows; no edit needed.
UNVERIFIED: all runtime behavior (TestEZ spec, Studio checks S1-S5); Jack runs them batched.

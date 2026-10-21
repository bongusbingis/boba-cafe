RESULT: PASS (gate only; runtime unverified)
Files: ShiftService.luau, ProfileTemplate.luau (BestCombo, BestShiftPay add-only), ShiftCard.luau (buildLines), ShiftService.spec.luau (3 new cases, not run).
Summary gets NewBestCombo/NewBestShiftPay; bests read in _beginShift, written monotonic after ShiftEnded; ShiftCardOpen attribute set/cleared; capsule nudge waits on NicknamePending.
Gate PASS.

RESULT: PASS
Changed: ShiftService.luau, CustomerService/init.luau (CustomerResolved, HasTicket), ProfileTemplate.luau, ShiftConfig.luau (new), Hud/ShiftCard.luau (new), Hud/init.luau, Hud/BottomLeft.luau, Tests/ShiftService.spec.luau
Gate: all changed files PASS (selene new=0, stylua ok, rojo build ok).
Studio (Jack): serve 5 on fresh profile -> card 8 s with "Next shift starts now"; 10 more -> 6 s card; "Shift k/N" shows when clocked in only; run ShiftService spec.
summary = { Shift, Stars, Served, Walkouts, Pay, Tips=0, Bonus, BestCombo, First, Seconds, Xp?, LevelBefore?, LevelAfter? } (ShiftService.ShiftEnding server signal, Client.ShiftEnded)
Question: card sits top-right (anchor 1,0 pos .99,.14), the only free zone in STYLE 2.4 besides bottom-right; confirm. ShiftTimer state vars renamed _unused (admin timer effect left in place).

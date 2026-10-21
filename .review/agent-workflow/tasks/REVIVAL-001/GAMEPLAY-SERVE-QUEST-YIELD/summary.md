RESULT: PASS
GAMEPLAY-SERVE-QUEST-YIELD: AdvanceQuest(CustomersServed) in CustomerService:_onServeTriggered now inside task.spawn + pcall, with comment.
Files: src/server/Modules/CustomerService/init.luau
Gate: selene new=0 (baseline 0), stylua=ok, rojo build PASS, GATE: PASS
Step-2 grep (after tip line to end of _onServeTriggered): no GetDataAsync/:await/Async(/task.wait/WaitForChild. Remaining service calls (AnalyticsEvents, StatisticsService:IncrementStat, LeaderboardService:IncrementStat, PerkService:TakeTipExtra) are pcall-wrapped but not verified non-yielding; left unchanged.
UNVERIFIED: runtime.

RESULT: PASS
Task: REVIVAL-001 REALORDER-SHIFT, source 098175c (uncommitted).
Files: src/server/Modules/RealOrderService.luau, src/server/Tests/RealOrder.spec.luau
Gate: PASS (selene new=0, stylua ok, rojo build ok).
- ShiftResult helper added after CountsForTeamChain.
- _onOrderPickedUp: `local tipExtra = 0` before tip block; `tipExtra = extra` after `pay += extra`; task.defer+pcall RecordCustomer block after AddXp pcall, before final AdvanceQuest; nothing added before Modify.
- D10: RecordTeamServe(grade or "Close", barista).
Deviation: CustomerService:RecordTeamServe currently takes only (grade); extra arg is ignored at runtime until SERVE-FEEDBACK D5 adds the param.
UNVERIFIED: all runtime (Studio checks S1-S5).

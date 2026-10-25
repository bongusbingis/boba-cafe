# M3-REM-C evidence: E23 Team Combo

RESULT: DONE (gate PASS; no Play/TestEZ/Studio per DEC-019)

## Files
- src/shared/Configuration/TeamComboConfig.luau (new): CHAIN_TARGET 10, PAY_BONUS 0.10, DURATION_SECONDS 60 (DEC-028 E23)
- src/server/Modules/CustomerService/Rules.luau: `NextTeamChain(chain, grade?, target)` -> (newChain, triggered); `TeamComboPay(pay, active, bonus)`
- src/server/Modules/CustomerService/init.luau: `_teamChain`, `_teamComboUntil`; `IsTeamComboActive`, `ApplyTeamCombo`, `RecordTeamServe`, `_notifyTeamCombo`; hooked in `_onServeTriggered` and `_onCustomerLeft`
- src/server/Modules/RealOrderService.luau: `_onOrderPickedUp` applies and records Team Combo (DEC-036 C3)
- src/server/Tests/TeamCombo.spec.luau (new)

## Per step
1. Config created, cites DEC-028 E23.
2. Rules helpers are pure. grade nil = walkout (reset); any grade (Perfect/Close) counts (C1). Reaching target returns (0, true).
3. Serve path: `ApplyTeamCombo(pay)` after Rush Hour, `RecordTeamServe(grade)` after the payout/stat/quest calls. Trigger sets deadline = os.clock()+60 (a new chain during an active combo overwrites it, so it refreshes to a full 60 s: C4) and resets the chain to 0.
4. Announce start/end through DialogService:Notify to every player (same pattern as CafeRatingService:_notifyAll, Title "Team Combo"); plain text, no HUD, no remote (C5). Notify runs in task.defer so the serve never waits on it. The end timer is a task.delay; if the deadline was refreshed, the old timer returns early and the newer timer announces the end.
5. Walkout (`_onCustomerLeft`, reason PatienceOut) resets the chain for any walkout, even one with no ticket holder. Chain and deadline are server-wide memory, not per-player, so there is no per-player teardown; nothing persists.
6. Spec covers the pure helpers and config values only; the 60 s window (os.clock + task.delay in CustomerService, needs the authored world, no fake clock) is untested and listed below.

## Multiplier order (chosen)
NPC serve: Rules.Payout -> PayoutVariant -> Rush Hour x2 -> Team Combo x1.10 (rounded) -> tip boost extra (PerkService:TakeTipExtra on that result) added on top.
Real-player order: Rules.Payout x real-customer multiplier -> Team Combo x1.10 (rounded) -> tip boost extra.
The serve that completes the chain is paid before the chain updates, so the bonus starts on the next serve.

## No-yield invariant
Neither path adds a yield between guards/claim and payout. `ApplyTeamCombo` is an os.clock read plus pure math. In RealOrderService the lookup is `pcall(Knit.GetService, "CustomerService")`, a synchronous table lookup, done after the existing tip-bonus resolve; `RecordTeamServe` runs after Modify and defers its Notify and timer.

## Gate
```
PASS  src/shared/Configuration/TeamComboConfig.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  src/server/Modules/CustomerService/Rules.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/CustomerService/init.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Modules/RealOrderService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  src/server/Tests/TeamCombo.spec.luau  selene new=0 (baseline[empty]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
```

## Test for Jack
1. Serve 10 customers in a row (NPC and/or real, any mix of Perfect/Close): everyone sees "Team Combo! +10% pay for 60 seconds!".
2. During the window, pay per serve is the normal pay x1.10 rounded (then the tip boost extra if you own a pass/pet). Real-player order pay also rises.
3. At 60 s everyone sees "Team Combo is over." and pay returns to normal.
4. Let a customer walk out mid-chain (e.g. after 6 serves): the chain restarts, so it takes 10 more serves.
5. Finish a second 10-chain during an active window: the window refreshes to a full 60 s, no early "over" message at the old deadline.
6. During Rush Hour plus Team Combo, pay is x2 then x1.10.
7. Run TestEZ with TeamCombo.spec (Prime/Jack; I did not).

## Deviations / notes
- Rush Hour does not apply to real-player order pay in the current code (not added; out of scope), so on real orders Team Combo stacks only with the real-customer multiplier.
- Window timing has no automated test (no fake clock in CustomerService).
- The serve that completes the chain does not itself get the bonus.

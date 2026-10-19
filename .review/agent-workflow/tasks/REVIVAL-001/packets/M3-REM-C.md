# M3-REM-C: Team Combo (E23)
Model: sonnet   Studio: no   Depends on: M4-FIXES, M3-REM-A   Size: M

## Goal
When the server reaches a 10-serve chain, everyone earns +10% pay for 60 seconds.

## Already built (verified)
- Nothing for Team Combo: grep for TeamCombo finds no code. The per-player combo is `CustomerService/init.luau:726,743-744` (`self._combo[player]`, `Rules.NextCombo`), different from the server-wide chain.
- Server-wide timed boost precedent to copy: Rush Hour, `CafeRatingService.luau:93-157`, flag read at `CustomerService/init.luau:373-376` and pay applied at `:729-731` (`RatingConfig.RUSH_PAY_MULT`).
- HUD pay feedback exists: the serve text at `CustomerService/init.luau:746-756` and the status bar `shared/UI/Components/Core/Hud/CafeRating.luau`.

## Note on M4-FIXES
`packets/M4-FIXES.md` runs first and edits CurrencyService, RealOrderService, CustomerService/init.luau (lines ~725-745), LeaderboardService, TreasureHuntService, BadgeService, DailyRewardsDialog. This packet also edits CustomerService/init.luau and possibly RealOrderService: re-read the post-M4-FIXES text and locate edits by function name (`CustomerService:_serve` area, the line containing `Rules.PayoutVariant`), never by line number. Do not revert M4-FIXES changes.

## Read (only these)
- `M3-ECON/answers.md` Batch 4 E23; `decisions.md` DEC-028
- `src/server/Modules/CafeRatingService.luau:80-170` (timer/notify pattern)
- `src/server/Modules/CustomerService/init.luau`: the serve function (around `Rules.Payout`) and `IsRushHour`
- `src/shared/Configuration/RatingConfig.luau`
- `src/shared/Configuration/CustomerConfig.luau:99-108`
- `src/server/Tests/CustomerService.spec.luau` (fixture style only)

## Write scope
- `src/shared/Configuration/TeamComboConfig.luau` (new): `CHAIN_TARGET = 10`, `PAY_BONUS = 0.10`, `DURATION_SECONDS = 60` (DEC-028 E23)
- `src/server/Modules/CustomerService/Rules.luau` (pure helpers: `NextTeamChain`)
- `src/server/Modules/CustomerService/init.luau` (chain state, pay multiplier, notify)
- `src/server/Tests/TeamCombo.spec.luau` (new)
- `src/server/Modules/RealOrderService.luau` only if Q3 is answered yes

## Steps
1. New `TeamComboConfig.luau` with the three values above, citing DEC-028 E23.
2. `Rules.luau`: add pure `Rules.NextTeamChain(chain, grade, target)` returning `(newChain, triggered)`. The chain rule (what counts, what resets) comes from Q1; implement exactly that answer.
3. `CustomerService/init.luau`: keep `self._teamChain` (number) and `self._teamComboUntil` (os.clock deadline). After the pay is computed and before `Modify`, if `os.clock() < self._teamComboUntil` apply `pay = math.round(pay * (1 + TeamComboConfig.PAY_BONUS))`; order relative to Rush Hour per Q2. Update the chain after each serve with `NextTeamChain`; on trigger set the deadline to `os.clock() + DURATION_SECONDS` (re-trigger while active per Q4) and reset the chain to 0.
4. Announce start/end with the same server-wide notify path `CafeRatingService` uses for Rush Hour (`_notifyAll`), plain text only, e.g. "Team Combo! +10% pay for 60 seconds!" and "Team Combo is over." No new UI pattern; if a HUD indicator is wanted, that is Q5.
5. Clear `_teamChain` and the deadline in the same teardown places `_combo` is cleared; do not persist anything.
6. Spec `TeamCombo.spec.luau`: pure helper cases (reaches target, resets as per Q1), pay x1.10 inside the window and x1.0 after, window length 60 s using a fake clock if the module already supports one, otherwise test the helper only and note it.
7. Run the gate.

## Done when
- 10 qualifying serves trigger exactly one 60 s window; pay inside it is the pre-bonus pay x1.10 rounded.
- The window ends on time and the chain restarts at 0.
- No file outside Write scope changed; M4-FIXES behaviour intact.

## Checks to run
- `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`. Never Play or run TestEZ (DEC-019); add a "Test for Jack" list to evidence.

## STOP-AND-ASK
- Q1: "What forms the 10-serve Team Combo chain: (a) any 10 consecutive NPC serves server-wide, (b) 10 consecutive Perfect serves server-wide, or (c) something else? Does a Close serve, a wrong attempt, a walkout, or 30 seconds of idle reset it?"
- Q2: "During Rush Hour (x2), does Team Combo multiply on top (x2 then x1.10) or is only the larger boost used?"
- Q3: "Does the Team Combo bonus also apply to real-player order pay (RealOrderService), and do real-player serves count toward the chain?"
- Q4: "If a new 10-chain completes while a Team Combo window is active, does it refresh the 60 seconds, extend it, or is it ignored?"
- Q5: "Is a chat-style announcement enough, or do you want a HUD indicator? (A new HUD element needs a pattern approved in docs/STYLE.md.)"

## Evidence
`tasks/REVIVAL-001/M3-REM-C/evidence.md` (RUNBOOK step 5)

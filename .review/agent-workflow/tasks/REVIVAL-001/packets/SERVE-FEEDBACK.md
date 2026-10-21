---
id: SERVE-FEEDBACK
title: Serve toasts - combo milestones, Team N/10, Team Combo credit, first-ever serve
priority: P1
role: Mason
worker_tier: sonnet
release_gate: before
depends_on: [GAMEPLAY-SERVE-QUEST-YIELD, GAMEPLAY-TOASTS]
status: READY
source_commit: 098175c
read_scope:
  - src/server/Modules/CustomerService/init.luau (symbols: _onServeTriggered, RecordTeamServe, _notifyTeamCombo, _pickOrderFor, PlayerRemoving, class fields near _teamChain)
  - src/shared/Configuration/TeamComboConfig.luau
  - src/shared/Configuration/CustomerConfig.luau (COMBO_STEP, COMBO_CAP, FIRST_SESSION_COUNT)
  - src/server/Modules/RealOrderService.luau (read only: the RecordTeamServe call)
write_scope:
  - src/server/Modules/CustomerService/init.luau
invariants:
  - "Serve-path no-yield: nothing yields between the serve guards and the payout in CustomerService:_onServeTriggered (SYSTEMS 'Team Combo & the Serve Path'). All new code runs AFTER the payout (`self._currency:Modify`), is a plain table/string operation, or sits inside task.defer + pcall. No GetDataAsync, :await(), WaitForChild, task.wait or Async call is added anywhere on the serve path."
  - "AdvanceQuest stays inside the task.spawn that GAMEPLAY-SERVE-QUEST-YIELD put there; do not touch it."
  - "No economy change: no new BobaBucks, no pay formula change. All numbers shown are read from CustomerConfig / TeamComboConfig."
  - "Text only through the GAMEPLAY-TOASTS queue (DialogService:Notify). No SmallNotification edit, no sound, no new UI (DEC-013)."
acceptance:
  - "Combo 3, 5 and 10 each send one extra toast; other combo values send none."
  - "Serve toast ends with ' · Team N/10' for chain 5..9 and has no suffix for chain 0..4."
  - "Team Combo announcement names the serving player; a RealOrderService completion (no player passed) keeps the old text."
  - "A player whose CustomersServed was 0 gets exactly one 'Your first order!' toast, on their first serve only."
  - "First-serve detection reads no profile on the serve path."
  - "A serve sends at most 2 toasts; first order and Team Combo each replace the combo milestone toast on that serve."
checks:
  - "wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && gate src/server/Modules/CustomerService/init.luau' (run stylua --check on the HEAD copy first; run stylua only if it passes)"
  - "rojo build default.project.json -o <scratchpad path outside the repo>"
evidence_dir: .review/agent-workflow/tasks/REVIVAL-001/SERVE-FEEDBACK
forbidden: [WORKER-PRIMER section 8, editing RealOrderService.luau, editing SmallNotification.luau, adding sounds, adding a BB bonus for the first serve, any yielding call on the serve path]
---

Rules and gate: `_meta/WORKER-PRIMER.md` (not repeated). Lease: CustomerService/init.luau chain is GAMEPLAY-SERVE-QUEST-YIELD -> this -> SERVE-PAYPOPUP.

## Source excerpt
- S10: What: Combo callout at milestones: at combo 3, 5 and 10 a bigger toast "Combo ×5! +50% pay". Why: Makes the streak a goal. Files: SmallNotification queue + server text after payout. Effort: XS. Risk: Low.
- X3: What: Team chain progress appended to the serve toast from 5/10 ("Team 7/10"). Why: Makes the co-op goal visible. Files: CustomerService toast text (after payout). Effort: XS. Risk: Low. Tag: JACK (amends DEC-036 C5, Q-G7).
- X4: What: Combo MVP: when a Team Combo triggers, the toast names the barista who served the 10th ("Ana completed the Team Combo!"). Why: Social credit at zero cost. Files: CustomerService.RecordTeamServe. Effort: XS. Risk: Low.
- S8: What: First-ever serve celebration: a one-time toast "Your first order! +5 Boba Bucks" plus the Success sound when CustomersServed goes 0 to 1. Why: Marks the onboarding milestone; the analytics funnel step 4 already exists. Files: CustomerService after payout (deferred) or the client. Effort: XS. Risk: Low.

## Decisions made
- D1 (S10 text): the bonus the NEXT serve earns is `math.min(n * CustomerConfig.COMBO_STEP, CustomerConfig.COMBO_CAP)`, so the toast says "Next serve +P% pay" with P = `math.round(that * 100)`. The excerpt's "+50%" at combo 5 matches (5 x 0.1 = 0.5). Rationale: exact and read from config, never hardcoded.
- D2 (S10 milestones): local constant `COMBO_MILESTONES = { [3] = true, [5] = true, [10] = true }`; a toast fires when `COMBO_MILESTONES[newCombo]`. Past 10 nothing fires (the cap is reached at 5, so 10 is the last callout). Rationale: matches the review; set lookup avoids a loop.
- D3 (S10 delivery): one deferred, pcall-wrapped `Notify` to the serving player, sent after the serve toast so the queue shows serve first. "Bigger toast" is not built: the GAMEPLAY-TOASTS queue shows the same card (no new visual, DEC-013).
- D4 (X3): the serve toast gets ` · Team {chain}/{TeamComboConfig.CHAIN_TARGET}` appended when `chain >= TEAM_PROGRESS_FROM` (5). `chain` is `self._teamChain` read right after `self:RecordTeamServe(grade)`. When that serve completes the chain, `_teamChain` is already 0, so no suffix is shown and X4's announcement takes over. Rationale: no new state, plain field read.
- D5 (X4): `RecordTeamServe(grade, server)` gains an optional second parameter `server` (type Player or nil; the Signatures section gives the exact Luau). The announcement is `{server.DisplayName} completed the Team Combo! +10% pay for 60 seconds!` when `server ~= nil`, else the existing text. `_onServeTriggered` passes `player`. RealOrderService.luau is outside this lease and keeps calling with one argument (old text); see Open items.
- D6 (S8 detection): the first-serve flag is set where the profile is ALREADY read off the serve path: in `_pickOrderFor`, when `served == 0`, set `self._firstServe[player] = true`. At serve time `local isFirstServe = self._firstServe[player] == true and npc.Scripted` and `self._firstServe[player] = nil` are plain table operations. Rationale: no read on the serve path (StatisticsService:IncrementStat is a promise that writes later, so its value is not usable). A Rescue serve by a barista without the flag simply gets no first-serve toast.
- D7 (S8 reward): no extra BobaBucks. The toast quotes the real `pay` of that serve (`Your first order! +{pay} Boba Bucks`). The excerpt's "+5" was an example; adding a bonus would be an economy change. Rationale: DEC-054 and the economy rule.
- D8 (sounds): not added here. SOUNDS owns them by toast text: Serve chime on the serve toast, Success on `Your first order!`, Pop1 on the combo milestone and the Team Combo toast (FEEDBACK-VOICE 4). Rationale: this packet is text-only.
- D10 (budget): a serve sends at most 2 toasts (FEEDBACK-VOICE 2). The serve toast is always one; the second is exactly one of first order, Team Combo, combo milestone, with first order winning over the milestone and Team Combo winning over the milestone. `RecordTeamServe` returns `true` when it announced the Team Combo, else `false`; `_onServeTriggered` keeps `local teamDone = self:RecordTeamServe(grade, player)` and sends the S10 toast only when `not teamDone and not isFirstServe`.
- D11 (order): inside the one `task.defer` closure the S10 toast is sent immediately after the serve toast; the S8 toast is sent through `task.delay(0.2, ...)` inside the same pcall so it follows the serve toast and its chime by 0.2 s. The Team Combo toast is sent by `RecordTeamServe` as today.
- D12 (voice): no new toast uses an emoji; the combo toast keeps its exclamation mark (celebration), the serve-toast suffix has none.
- D9: new toasts carry `Title`, `Description` and `Text` (the `_notifyTeamCombo` precedent, cast `:: any`), so they render even if the GAMEPLAY-TOASTS normaliser changes.

## Exact strings
- Serve toast suffix: ` · Team 7/10` (format ` · Team {chain}/{TeamComboConfig.CHAIN_TARGET}`).
- Combo toast: Title `Combo`, Text `Combo ×{n}! Next serve +{P}% pay` (the sign is the existing U+00D7, as in the current serve toast).
- First serve: Title `First order`, Text `Your first order! +{pay} Boba Bucks`.
- Team Combo (named): `{DisplayName} completed the Team Combo! +10% pay for 60 seconds!` built from `TeamComboConfig.PAY_BONUS` and `DURATION_SECONDS` exactly as the current string is.

## Exact numbers
`COMBO_MILESTONES = {3, 5, 10}` and `TEAM_PROGRESS_FROM = 5`, both file-local constants in CustomerService/init.luau with a `-- TUNING` comment (not economy values).

## Signatures and insertion points (anchor by symbol)
- Class table, beside `_teamChain`: add `_firstServe = {} :: { [Player]: boolean }, -- barista -> served 0 customers when last assigned (session memory)`.
- `CustomerService:_pickOrderFor`, immediately after `local served = self:_readServedCount(player)`: `self._firstServe[player] = if served == 0 then true else nil`.
- `CustomerService:RecordTeamServe(grade: Rules.ServeGrade?, server: Player?): boolean`: the `_notifyTeamCombo(...)` text changes (D5) and it returns true only on the call that announced the Team Combo (D10). Other callers ignore the value.
- `CustomerService:_onServeTriggered`: (a) the existing `self:RecordTeamServe(grade)` becomes `local teamDone = self:RecordTeamServe(grade, player)`; (b) directly after it add `local teamChain = self._teamChain`, `local isFirstServe = self._firstServe[player] == true and npc.Scripted`, `self._firstServe[player] = nil`; (c) in the toast text build, after the `newCombo >= 2` block, add `if teamChain >= TEAM_PROGRESS_FROM then text ..= ...` (D4); (d) after the existing `self._dialog:Notify(player, { Title = "Order served!", ... })` line and before `self:_showServePay`, add one `task.defer(function() pcall(function() ... end) end)` that sends the S10 toast when `COMBO_MILESTONES[newCombo] and not teamDone and not isFirstServe`, and the S8 toast (0.2 s later, D11) when `isFirstServe`. The closure captures only `player`, `newCombo`, `pay`, `isFirstServe`, `teamDone`.
- `CustomerService:PlayerRemoving`: add `self._firstServe[player] = nil`.
- No new remote, attribute or profile field.

## Studio checks (for Jack, batched)
- S1: new account, clock in, serve the first scripted order. Expect "Order served! ..." then "Your first order! +N Boba Bucks" once; serve the second: no first-order toast.
- S2: serve 3 Perfect drinks in a row. Expect "Combo ×3! Next serve +30% pay" after the third serve toast; at 5 "+50%"; at 10 again "+50%"; at 4 and 6 nothing extra.
- S3: with another player or real orders, push the team chain to 5. Expect the serve toast to end with " · Team 5/10"; chain 4 has no suffix.
- S4: complete the 10th serve. Expect "<Name> completed the Team Combo! +10% pay for 60 seconds!", no Team suffix on that serve toast and no combo milestone toast on the same serve (2 toasts total).
- S5: complete the chain via a real-player order. Expect the old unnamed text (known gap).
- S6: all toasts queue in order; none blank; serve pay and customer leaving are unchanged.

## Asset prerequisites
None. Sounds (`SFX.UI.Combo`, `SFX.UI.Success`) are not used here.

Open items: FOLLOW-UP for Prime (not a Jack question): RealOrderService.luau:RecordTeamServe call passes no player, so a Team Combo completed by a real-player order stays unnamed. REALORDER-SHIFT D10 adds `, barista` to that call (lease holder). No HARD-STOP.

## Summary
- Four serve-feedback texts, all server-side in CustomerService/init.luau after the payout.
- First-serve flag is set in `_pickOrderFor` (already reads the profile); serve path only reads a table.
- Combo milestones 3/5/10 read bonus % from CustomerConfig; Team N/10 from 5; Team Combo names the server.
- No sounds, no BB bonus, no new UI; queue handled by GAMEPLAY-TOASTS.
- Leases: after GAMEPLAY-SERVE-QUEST-YIELD and GAMEPLAY-TOASTS; before SERVE-PAYPOPUP.

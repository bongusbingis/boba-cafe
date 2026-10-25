# Pre-release review — boba-cafe, branch `uhweifh` (working tree incl. uncommitted)

Date: 2026-10-22. Reviewer: Claude (Opus 5.5). Status: COMPLETE (Studio playtest stopped at shift 3/5; see the Studio section for what was not run).
Nothing has been fixed. Every fix waits for Jack's approval.

Legend: **VERIFIED** = run in Studio beta or proven by a failing test; **TRACED** = followed line by line in source;
**SUSPECTED** = plausible, not proven.

## Gates

| Gate | Result |
| --- | --- |
| `rojo build default.project.json -o <scratchpad>/review.rbxl` | PASS |
| selene on the changed and untracked files | 2 errors, 2 warnings. **New:** `src/server/Cmdr/Commands/Moderation/View.luau:18` and `Unview.luau:15` (`incorrect_standard_library_use`, writing `workspace.CurrentCamera.CameraSubject`), both untracked files. Old (already in HEAD): `DataService/init.luau:3` unused `TextService`, `Menu.luau:10` unused `TEMPERATURE_COLD_HOT`. |
| `stylua --check` on changed files | **New:** `DataController.luau`, `DataService/init.luau`, `Animator.luau`. The HEAD versions pass, so this is new. The diff is line endings only (CRLF in the working copy). |
| TestEZ in Studio beta (`RunTests` = true) | **988 passed, 20 failed** (see Tests). |

## Findings by severity

### HIGH

**H1. When a staff or auto Rush Hour event ends, it turns off a paid Boba Party or a paid Rush Hour that is still running (VERIFIED by trace; Studio repro pending)**
- `EventService.luau:110` `_endEvent` always sets `workspace.RushHour = false`.
- `CafeRatingService:_publish` (`CafeRatingService.luau:~63`) is the only code that puts it back to true. While a Rush or Party runs, `_change` returns before it publishes (frozen meter), and the party loop only publishes when the party ends.
- Products: `ProductIds.BobaParty` 3300909405 and `RushHour` 3318558073 are both wired in `ProcessReceipt.server.luau:109-131`.
- Scenario: the auto event (every 3600 s, `EventService.luau:~247`) starts `RushHour`. A player buys a Boba Party. 600 s later the event ends, `RushHour` becomes false, and `CustomerService:IsRushHour()` returns false. For the rest of the paid party there is no x2 pay and no rush pacing, while the HUD still shows `BobaParty` = true. The same thing happens to a natural or paid rush.
- Monetization: the buyer does not get what they paid for.

**H2. A shift where nobody was served pays the 30 BB streak bonus (VERIFIED: failing spec `ShiftService.spec:392`)**
- `ShiftService.luau:301-306`: `streak = served>0 and +1 or 0`, then `if streak % STREAK_LENGTH == 0` pays the bonus. `0 % 3 == 0`, so a shift with no serves pays 30 BB.
- The spec (TAKEOVER-REVIEW-FIX P3-9) asserts 0 and fails with 30. The fix was never applied to the source.
- Scenario: take orders and let every customer walk out (or end a shift with no serves). Each such shift pays +30 BB, plus the 1-star bonus of 5 BB and the shift XP.

### MEDIUM

**M1. A cheating client always gets a Perfect pour (TRACED)**
- `PourMeter.EffectiveElapsed` / `Resolve` and `KitchenConfig.POUR_METER`: the latency allowance of 0.3 s covers 0.375 of the track (marker speed 1.25/s), but the Perfect zone is only 0.18 wide. The client receives the zone centre and period in `PourWindowOpened`.
- A script waits until just after the marker passes the zone centre and reports that exact elapsed time. The claim is inside `[server-0.3, server]`, so it is accepted as Perfect every time.
- Effect: 5 BB per perfect, up to 2 per drink, so up to +10 BB per drink on top of a base pay of about 3. The uncommitted change only blocks claims outside the window, not claims chosen inside it.
- The values are tuning (Jack's call).

**M2. Real-order history is wiped on leave, so the x2 pay resets on rejoin; XP and pay have no cap (TRACED)**
- `RealOrderService.luau:364-372` deletes every history pair for a player who leaves. `PayMultiplier` therefore returns x2 again after the customer rejoins.
- Throttled orders (multiplier 1) still pay BB and `AddXp(XP_PER_ITEM * #specs)` (`:326`) with no cap. A barista with an alt (alt orders 4 brownies by phone, barista grabs and deposits) earns 40 XP per order indefinitely, x2 BB for 3 orders, then rejoin and repeat. The alt can also farm `HeartsReceived` (5 hearts per order).

**M3. The GiveTool tool cap broke 12 specs, and the new cap counts gamepass tools and received drinks (VERIFIED)**
- `GiveTool.luau:28` calls `player:FindFirstChildOfClass`. The specs' fake players do not have it, so `BobaBalls.spec` and `KitchenAttributes.spec` (12 tests) now error. GiveTool has no passing coverage at all now.
- `MAX_HELD_TOOLS = 10` counts every Tool: pass tools (`PassToolService`) and `Served` drinks a player received as a customer. A player who used to be a customer with several drinks, plus pass tools, gets "Hands full" at the first giver. The toast tells them what to do, so this is UX, not a block.

**M4. A scripted first-session NPC is never dismissed when orphaned (TRACED)**
- `Npc._waitOutPatience` (`Npc.luau:1129`) never returns for a scripted NPC.
- If its barista leaves or clocks out and nobody has a free slot, `_handOff` (`init.luau:1164`) gives up once and never retries. The NPC then waits at pick-up forever, holding a pacing slot (`_npcCount`) and a pick-up spot. Only an empty cafe for 60 s clears it.
- With 1 barista the pacing target is 2, so one orphan halves the spawn rate.

**M6. An accepted NPC orphaned by clock-out or leave is never re-dispatched (VERIFIED in beta)**
- `_releaseTicket` → `_handOff` (`init.luau:2226-2239, 1164`) runs once, at the moment of release. Nothing hands unassigned pick-up NPCs out later: not on clock-in (the `ClockedInChanged` handler only sets `_idleSince`, `:2347`) and not when a slot frees (`_clearTicket` only dispatches *real* orders).
- Beta: submitted Customer_9 (ticket slot 1) → `SetClockedIn(false)` → ticket cleared and `AssignedUserId` nil (correct) → `SetClockedIn(true)` → no `TicketChanged`, still unassigned, shift resumed at 2/5 (correct).
- Result: the barista who took the order cannot serve it until the Rescue window (<30% patience), then gets Rescue x1.5 instead of a normal serve. A scripted orphan never times out (M4). In multi-barista servers, a free barista who clocks in later never receives it.

**M5. Rescue and handoff of a scripted NPC pay scripted rates to a veteran (TRACED)**
- `Rules.Payout(..., npc.Scripted, ...)` always applies `FAST_MULT` when the NPC is scripted. Once the patience time passes, `FractionLeft()` drops below 0.3, so any barista can rescue it (x1.5) with the scripted Fast bonus. Minor economy issue.

### LOW

- **L1. Per-player memory leak (TRACED).** `CustomerService:PlayerRemoving` clears `_idleSince[player]` (`init.luau:2390`), then `_releaseTicket` → `_clearTicket` sets `_idleSince[holder] = os.clock()` again (`:2207`). A departed barista who held an NPC ticket leaves a Player-keyed entry behind. Same pattern: `ProgressionService:AddXp` recreates `_state[player]` if the profile promise resolves after leave.
- **L2. Order numbers wrap at 1000 (TRACED).** `orderNum = %04i of n % 1000` and the code sorts by string (`OrderService.luau:348, 465`). After the wrap, `0000` sorts before `0999`, so the newest real order is dispatched first. The spec "order nums should be comparable as strings" is tautological: it only compares string literals.
- **L3. A real order that is never picked up keeps its node and blocks the customer (TRACED).** An uncollected `Ready for Pick Up` order holds its pick-up node and the customer's single open-order slot for as long as the customer stays on the server. The display model is destroyed after 300 s, but `OrderOwner` and the folder are not. The barista is paid only at pick-up, so they get nothing if the customer leaves.
- **L4. Kitchen actions don't re-check the barista after a dialog (TRACED).** `InteractionRunner` does not re-check clock-in or distance after a dialog yields (`_runSelectFrom`). Clock out with a station dialog open, answer it, and you still receive the tool.
- **L5. The NPC tablet sends the order to every client (TRACED).** `OpenOrderingTablet` (`init.luau:1369`) sends `Orders` and `Specs` even when it shows "Ask the customer", so a client can auto-fill the "type the order" step.
- **L6. Two Take Order presses can roll different orders (SUSPECTED).** In `_onTakeOrderTriggered`, `_pickOrderFor` → `_readServedCount` can yield before `OrderRolled` is set. Two baristas pressing at the same moment could each roll an order; the second overwrites the first, and the first's prefilled tablet fails "doesn't match".
- **L7. Level-up nametags bypass the inventory API (TRACED).** `ProgressionService.luau:362` writes the reward with `SetValue` directly: no Storage limit check and no `onChange` packet to the client.
- **L8. Real-order pay has no analytics reason (TRACED).** `RealOrderService.luau:314` calls `Modify` with no reason, so the payout is logged as "Shop" in economy analytics.
- **L9. Malformed submit arguments throw (TRACED).** `Rules.ValidateSubmittedOrder` and `DialogService:Resolve` index untrusted values without a type check: a non-table entry or non-table `data` throws (log spam only, nothing breaks).
- **L10. Secret committed in source (pre-existing).** `ActivityScript.server.luau` has a hard-coded webhook URL and `SECRET` in source. It is server-only, but it is in git. Secrets are a Jack-approval area.

## Server authority (client-callable endpoints)

| Endpoint | Validation |
| --- | --- |
| `ShiftService.SetClockedIn(bool)` | type check, 2 s cooldown. OK |
| `OrderService.CreateOrder(id, items)` | id == caller, clocked out, 5 s debounce, one open order, 1-4 items, launch allowlist, server rebuilds from Menu. OK |
| `CustomerService.SubmitNpcOrder(npcId, items)` | clocked in, bound to an NPC whose Take Order this player pressed, AtCounter, not wrapping up, free slot, 20 studs, order matches. OK (L5, L9) |
| `CustomerService.SubmitCounterOrder` / `CancelCounterOrder` | types, 1 s debounce, exact lock (taker + Id + not expired), clocked in, range, customer still in the area with no NPC; rebuilt via `CreateOrder` rules. OK |
| `KitchenService.ReportPourTap(id, elapsed)` | only the open window is graded; claim limited to the latency window. M1 |
| `ProgressionService.EquipTitle`, `DailyReward.ClaimReward`, `Quest*`, `Capsule Purchase*`, `GroupBenefit*`, `SettingsService.SetSetting` | type and rate checks present; spends go through `TrySpendAsync`. Not deep-reviewed (outside the loop) |
| `DialogService.DialogSignal` "Resolve" | only the owning player can resolve; values are parsed by callers. L9 |
| Prompts (Serve, Take Order, Deposit, Pick Up, Handoff) | server checks clock-in, distance, state and assignment; Serve takes the tip bonus before the checks, then nothing yields. OK |

## Tests (TestEZ in beta: 988 pass / 20 fail)

The 20 failures:
- 12× GiveTool fake-player crash (M3): `BobaBalls`, `KitchenAttributes`.
- `ShiftService` streak with no serves → real bug H2.
- `ShiftService` paycheck expects `Pay == 17`. The code's `Pay = Pay - Tips = 12` is right (otherwise `Total` would count tips twice), so the **spec is stale**.
- `CustomerService` PickOrder "Espresso at level 8" and "Mango at level 8": hard-coded roll values went stale after the newer pool entries were added. Brittle tests.
- `LeaderboardService` "ignores hidden boards": `TopDonators` is no longer `Hidden` in `LeaderboardConfig`, but SYSTEMS.md and DEC-035/037 say it is hidden. This is config/doc drift.
- `CmdrUpgrades` planning error: `Cmdr/Commands/Upgrades/SetUpgrade` is missing (admin, out of scope).
- 3× `Spill` unseat/teleport: fake-rig problems (`RightHand` missing) plus 2 assertion failures.

Coverage and quality gaps:
- No spec covers `_onServeTriggered`, `_submitNpcOrder`, rescue, `_handOff` / `_releaseTicket`, walkouts, or the new `IsWrappingUp` / `Recheck` / resume `_checkEnd`. `_handleHandoff` is tested only on refusal paths, never on a successful direct serve.
- Tautological: `ShiftService.spec` "pays 5/10/15" (config arithmetic only), "order nums comparable as strings" (literals), "ASSIGNMENT_MODE is Dedicated".
- `ShiftService.spec` calls the real `_endShift` with fake players, which reaches the live Currency, Quest and Statistics services. The pcalls hide it, but it adds test side effects and log noise.

## Docs drift (SYSTEMS.md)

- It says `SHIFT_BONUS_PER_STAR` is 0; the code is 5 (DEC-024).
- It says the NPC Serve range is 10 studs and the prompt is `ServePrompt` (MaxActivationDistance 8); the code uses `CustomerPrompt` at 15 / 15.
- It says Take Order is 12 studs; the code uses 15.
- It says real tickets do not count toward the shift; `RealOrderService` does `RecordCustomer`.
- It says `TopDonators` is hidden; it is not.

## Studio playtest (beta 128511401637461 only)

- Run 1 (with tests): boot OK. Console: test failures as above. A `LogViewerController:271 GetService before Knit started` error came from an "AssistantCommand" client call (not from game code). The play session stopped on its own before the loop check.
- Run 2 (no tests), player bongusbingis, level 4, clocked in by default, shift target 5:
  - Boot: no script errors. Asset noise only: `rbxassetid://203785492` "Asset type does not match" (×6), `7704451300` "not approved", `[Spill] Template Boba has no SignStartPosition`. A Hoarcekat plugin error is a Studio plugin, not game code.
  - NPCs spawn, queue at registers, show Take Order. **Take Order works** (prompt → tablet opens). **C1 confirmed** (no order shown).
  - **L5 confirmed:** the client captured `OpenOrderingTablet` with full `Orders` (e.g. Custom Boba / Classic Milk Tea / Small / Normal) while the UI said "Ask the customer".
  - `SubmitNpcOrder` through the real Knit remote → `{Success=true}`; `TicketChanged` delivered "Small Custom Boba" in slot 1. The NPC walked to pick-up, and its prompt changed to Serve.
  - First NPC: walkout while I debugged prompt automation (server time passed `PatienceEnd`). The shift went to 1, so walkouts count toward the shift.
  - Second NPC (Customer_7, Medium Strawberry Boba): Take Order → submit → pick-up. Serve with E consumed the drink, the shift went to 2/5, and AnalyticsService logged the economy and funnel events (payout happened).
  - **Kitchen not exercised:** the drink was a server-created stand-in Tool with the spec attributes (Item / Size / Syrup / Tapioca), so station dialogs, the pour meter and GiveTool were not run in this playtest.
  - Observation (tuning): with one barista, Cafe Rating fell 49 → 7.5 in about 10 minutes. Unattended register NPCs keep walking out (-2 each, and unassigned register walkouts count, TAKEOVER-FIX 2). A new or AFK solo barista drives the rating to near 0.
  - Clock-out mid-order (Customer_9): ticket cleared, NPC unassigned, shift attributes hidden. Clock back in: shift resumed at 2/5 (pause works). The NPC was **not** re-assigned (M6).
  - Rescue: below 30% patience the client prompt read "Rescue". Serving the orphan worked, and the shift went to 3/5.
  - Stopped at 3/5. Prompt automation became unreliable (E presses did not register), so shift end was not reached.
  - Not run in Studio: shift end and paycheck, clock-out mid-order, rescue, 2 slots, real-player orders, Rush / Boba Party (H1 repro needs service access; the command context has its own module cache, so Knit services are unreachable from execute_luau).
- `RunTests` was set for run 1 and cleared afterwards (edit DataModel attribute is nil again). The beta place was not saved or published by me.
- Note: the playtest loads and saves the Studio profile (`data will be saved`). beta and live share DataStores, so the test serve and walkouts changed the real profile of user 176353970 (small BB / XP / stat changes).

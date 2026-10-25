# FTUE Trace — a brand-new player's first session

Generated 2026-10-24 by the Primary Reasoning Agent. Traces code only; no analytics diagnosis, no fixes.
All line references are to the working tree on `uhweifh` as read 2026-10-24.

## Funnel step index reference (AnalyticsEvents)

Every step fires twice: `OnboardingFunnel(player, N, name)` (Roblox native onboarding funnel) and `Funnel(player, N, name)` (legacy "FirstSession" funnel). Both are deduped **per player per step index in memory only** — cleared on `PlayerRemoving` — so the dedupe is per session, not lifetime.

| Step | Name | Where fired |
| --- | --- | --- |
| 1 | `Joined` | `AnalyticsEvents:KnitStart` on `PlayerAdded` |
| 2 | `ClockedIn` | `ShiftService:SetClockedIn` when clocking in (including the automatic default clock-in) |
| 3 | `FirstStationUse` (native) / `FirstItemTaken` (legacy) | `KitchenService/Actions/GiveTool.luau` after a tool is cloned and equipped |
| 4 | `FirstOrderServed` (native) / `FirstServe` (legacy) | `CustomerService:_onServeTriggered` after a successful serve |
| 5 | `OnboardingCompleted` | `CustomerService:_onServeTriggered` when `(servedBefore + 1) >= FIRST_SESSION_COUNT` |
| 6 | `FirstShiftCompleted` | `ShiftService:_endShift` when `state.Completed == 0` (first shift) |
| 7 | `FirstNicknameSet` | `DataService/PlayerSetup.luau` nickname prompt (set or skipped) |
| 8 | `FirstLevelUp` | `ProgressionService` on the first level-up |

## 1. Starting state on join

1. **Funnel step 1** fires (`AnalyticsEvents:KnitStart` connects `Players.PlayerAdded` and also handles already-present players).
2. **No join gating.** Group rank is never read at join; the old group-rank join kick was removed (DEC-004). `init.server.luau` fans `PlayerAdded` out to every service.
3. **DataService** begins loading the profile. On a truly new player the profile is the `ProfileTemplate` default (no legacy data carried over from the old place).
4. **ShiftService.PlayerAdded** — if the player's `ClockedIn` attribute is `nil`, the server calls `SetClockedIn(player, true)` (`DEFAULT_CLOCKED_IN = true`). New players therefore start **clocked in as baristas**. This:
   - fires `ClockedInChanged(player, true)` (GoodSignal),
   - fires funnel step 2 `ClockedIn` and `ProgressionStart("Shift", 1)`,
   - lets `Teams.server.luau` move them to the `Baristas` team,
   - is the hook `CustomerService` uses to start the first-order auto-grant (see below).
5. **PlayerSetup** (runs once per join in its own thread): writes `Playtime.FirstJoin`, sets up cosmetics/pet replication, runs the one-time group-pet grant (`FreeItemsRedeemed` guard), and arms the **nickname prompt**. The nickname prompt does **not** open on join — it listens for the first `ShiftService.ShiftEnding` and then waits for the shift card (`ShiftCardOpen`) to close (`PlayerSetup.luau` lines ~136–177). It sets the `NicknamePending` attribute while armed.
6. **World resolution.** `CustomerService` resolves the NPC world contract (`workspace.Assets.NPC.*`, one shared 10 s budget) and enables itself; `KitchenService` waits up to 10 s for `workspace.Assets.Kitchen` and attaches prompts to every matching model. Both degrade with a single `warn` if content is missing; nothing blocks joining.

## 2. How "Auto-Grant" delivers the first tutorial order

Constants (`CustomerConfig.luau`):
- `FIRST_SESSION_COUNT = 3`
- `AUTO_GRANT_FIRST_ORDER = true`
- `AUTO_GRANT_TUTORIAL_ORDERS = 3`
- `FIRST_SESSION_ORDERS = [1] Classic Milk Tea Boba (Medium), [2] Fudge Brownie, [3] Regular Coffee (Small, no ice/sugar)`

Trigger points for `CustomerService:_checkAutoGrantFirstOrder(player, servedCountOverride?)`:
- `CustomerService:KnitStart` — for every player already in the game,
- `CustomerService:PlayerAdded` — for later joiners (only if `self.Enabled`),
- the `ClockedInChanged` handler — whenever a player clocks in,
- chained after a successful serve — `_onServeTriggered` schedules it with a 1 s delay when `servedNow < AUTO_GRANT_TUTORIAL_ORDERS`.

`_checkAutoGrantFirstOrder` guards (all must pass):
1. `CustomerConfig.AUTO_GRANT_FIRST_ORDER` is true.
2. No grant already in flight for this player (`_firstOrderGranting` reentrancy guard).
3. Player still in `Players`.
4. Bounded wait (up to 5 s, 0.2 s polls) until `self._context` exists **and** `ShiftService:IsClockedIn(player)`.
5. `self:_hasFreeSlot(player)` — the barista has a free ticket slot (`Progression.SlotsFor(level)`; 1 at level 1).
6. `served = servedCountOverride or _readServedCount(player)` and `served < AUTO_GRANT_TUTORIAL_ORDERS` (3).
7. Free slot re-check, then calls `_autoGrantFirstOrder(player, served)`.

`_autoGrantFirstOrder(player, served)` mechanics:
- Requires `self.Enabled`, `_context`, clocked in, and a free slot (re-checked).
- `orderIndex = clamp(served + 1, 1, #FIRST_SESSION_ORDERS)` → picks the next scripted order (with a fresh `CustomInfo` clone).
- Builds the spec with `OrderSpec.FromOrderItem(order)` — validates against the server-side Menu. Rejection logs a `warn` and aborts (no order is issued).
- Picks a target NPC in preference order:
  1. an unassigned NPC already `AtCounter`,
  2. an unassigned NPC `Queued` in line,
  3. otherwise **spawns a brand-new NPC directly at the pick-up plane** (`Npc.new(context, order, spec, 0, nil, nil)` — patience argument 0).
- On the target NPC it: releases its counter spot (if any), claims a pick-up spot, renames the model (`Customer_<seq>` for unique ticket Ids), calls `SetOrders({order}, {spec})`, sets `OrderRolled = true` and `RolledScriptedFor = player.UserId`, records `_lastOrder[player]`, sets `_firstServe[player] = true` when `served == 0`, `ClearVariant()` (scripted NPCs are always normal), then `SetAssignment(player.UserId, 0, true)` → `Scripted = true`, `PatienceTotal = 0`.
- Sends the NPC to the pick-up spot (`GoToPickup`) and issues the ticket immediately with `_issueTicket(player, npc)` — this fires `Client.TicketChanged(player, ticket, slot)` so the HUD ticket appears on the client. `RegisterCustomerOrder(..., "Being Prepared", ...)` is called for the staff screen.
- **No Take Order / tablet step is involved for auto-granted orders.** The ticket exists and the NPC is already assigned to the player; the player goes straight to the kitchen and then to Serve.

Patience nuance: `Npc:StartPatience` runs when the NPC reaches pick-up; since `PatienceTotal <= 0` it falls back to `PATIENCE_BASE_SECONDS` (45). But because `Scripted == true`, `_waitOutPatience` pins the bar at full and never times the NPC out (only an unassigned scripted NPC left orphaned for 60 s is cleaned up). Scripted serves are also always `Fast` for pay.

Client side: `OrderController` listens to `CustomerService.TicketChanged` and sets `CurrentOrder`; `KitchenController` then reads the order and drives guidance (recipe-card steps, station highlight, beam, toasts) via `KitchenGuidance`.

## 3. Exact server-side validation before `FirstItemTaken` (cup dispenser)

The first tutorial order is a boba, so the first station is the **Clear Cup** dispenser (`Recipes.Items["Clear Cup"]`, built by `RecipeConstructors.makeCupGiver`). The `FirstItemTaken`/`FirstStationUse` event lives at the end of `GiveTool.luau`.

Validation chain, in order:

1. **Prompt trigger** — `PromptBuilder.Attach` put a `ProximityPrompt` on the `Clear Cup` model (`HoldDuration = 0.5`). Triggering fires the callback in `KitchenService:KnitStart`.
2. **KitchenService callback** (`KitchenService/init.luau` lines ~452–501):
   - Clocked in: `ShiftService:IsClockedIn(player) == true`, else `InteractionFailed("ClockedOut")` (the client then offers the clock-in dialog).
   - Restocking box path is skipped (only when `Restocking` attribute is true).
   - Stock check: if the prompt has `CurrentStock <= 0` and the player lacks the `UnlimitedStock` perk → `InteractionFailed("OutOfStock")`.
   - The station model must have a `PrimaryPart`.
   - The player character must have a `HumanoidRootPart`.
   - Distance: `(rootPart.Position - primaryPart.Position).Magnitude <= KitchenConfig.MAX_INTERACTION_DISTANCE` (10 studs). Too far = silent return.
   - Then `self._runner:Run(player, recipeData, model)`.
3. **InteractionRunner.Run** — per-player debounce (`_debounces`), runs the recipe's `Actions` inside `task.spawn` with `pcall`.
4. **SelectFrom (size choice)** — the cup recipe is `{ SelectFrom, { Title, Text, Buttons = Small/Medium/Large }, branches }`. The server opens a `DialogService` `ActionPrompt` and `await`s the player's choice. If the dialog is closed/cancelled → `{ Success = true }` (no tool, no event). After a choice it re-validates: the held tool did not change during the dialog, the player is still clocked in, and still within distance.
5. **Branch actions** — `grabActions(tool, { Item = name, Size = size })` = optional `AnimateRaw` (only if the authored animation exists) then `GiveTool(tool, { Item = "Clear Cup", Size = size })`.
6. **GiveTool itself** (`GiveTool.luau`):
   - Character must exist.
   - Attributes argument must be a table of string keys → literal values (checked before anything is touched).
   - **Tool cap**: `countTools(player, character) >= KitchenConfig.MAX_HELD_TOOLS` (10, backpack + equipped) → "Hands full" toast and `return false` (no event).
   - The currently held tool (if any) is moved to the backpack.
   - The cup tool is cloned; `clone:SetAttribute("Item", toolToClone.Name)` then the override applies `Item = "Clear Cup"` and `Size = <chosen>`; `BobaBalls`/`Tapioca` descendants are hidden (Transparency 1) while `Tapioca` attribute is nil; optional AutoWeld; every part is unanchored and `CanCollide = false`; `clone.Parent = character` equips it.
7. **Only after all of the above succeeds** does `GiveTool` fire:
   - `AnalyticsEvents:OnboardingFunnel(player, 3, "FirstStationUse")`
   - `AnalyticsEvents:Funnel(player, 3, "FirstItemTaken")`
   These run in a `pcall` and are deduped per player per step, so only the player's first-ever successful tool grab is recorded.

Note: the cup dispenser recipe has **no** `ToolNameValidityCheck` (unlike Milk/Syrup/Tapioca/Sink). The gates before `FirstItemTaken` are exactly: clocked in, stock available, station has PrimaryPart, character has a root, within 10 studs, a size chosen in the dialog, held tool unchanged during the dialog, and under the 10-tool cap.

## 4. What happens when handing the drink to the NPC

`CustomerService:_onServeTriggered(npc, player)` runs when the player triggers the NPC's Serve prompt (state `AtPickup`, prompt made by `_onAtPickup`). Exact sequence:

1. Resolve the tip bonus first (`PerkService:GetTipBonus`; may yield on a cold pass cache). Failure → `tipBonus = 0`.
2. **Guards (no yield after this point):**
   - clocked in (`ShiftService:IsClockedIn`);
   - within 15 studs (matches the prompt's `MaxActivationDistance`);
   - NPC still waiting (`not npc.Left`, state `AtPickup` or `AtCounter`);
   - `Rules.CanServe(assigned, fractionLeft)` — the assigned barista always; anyone else only as a Rescue below `RESCUE_FRACTION` (0.3). Wrong customer → a "Wrong customer" toast names the right one.
3. **Tool matching** — `OrderService:FindServeTools(player, npc.Specs)` collects the held tool first then backpack tools, skips tools with `Served == true`, and grades with `OrderSpec.PickTools`/`Match`. No match → `WrongOrderRejected` custom event, the NPC plays `Confused` and `SayWrong`, and a "Wrong drink" toast names the mistake (`MistakeText.FromSpec`). The tool is **not** consumed. Grade must be `Perfect` or `Close` to continue.
4. **Consume the tools** — (`Close` mistake text and the pour tip are read first), optional seating clone, then every matched tool is `:Destroy()` with no yield between pick and destroy.
5. **Payout** (all synchronous):
   - `Rules.Payout(npc.Orders, grade, fractionLeft, combo, npc.Scripted, rescue)` — base pay by category × grade mult × fast mult (scripted serves are always Fast) × combo × rescue;
   - `Rules.PayoutVariant` for Karen/VIP;
   - Rush Hour multiplier (`RUSH_PAY_MULT`) if `workspace.RushHour`;
   - Team Combo multiplier via `ApplyTeamCombo`;
   - pass/pet tip extra via `PerkService:TakeTipExtra`, plus the pour-skill tip (`KitchenService:GetPourTip`).
   - `CurrencyService:Modify(player, "BobaBucks", pay, "Gameplay")`.
6. **Measurement & stats** — reads `servedBefore = _readServedCount(player)` **before** incrementing, then fires funnel step 4 (`FirstOrderServed`/`FirstServe`), conditionally step 5 (`OnboardingCompleted`, see §5), `NpcServed`, `ServeSeconds`, `PourAccuracy`; then `StatisticsService:IncrementStat(player, "CustomersServed")`, `LeaderboardService OrdersServed`, quest progress (`CustomersServed` + `BobaOrdered`, spawned).
7. **Combo & feedback** — personal combo update, `RecordTeamServe` (server-wide 10-chain → Team Combo window), the `+N · Grade` toast, a special "Your first order!" toast when `_firstServe[player] == true and npc.Scripted`, and the floating `+N BB` BillboardGui.
8. **Cleanup** — `RemoveCustomerOrder`, `_clearTicket` (fires `TicketChanged(player, nil, slot)`, frees the slot, restarts the idle clock, dispatches pending real orders, re-checks the shift end), release the pick-up spot, notify a rescue holder if any, then `npc:Leave("Served", grade)` → `CustomerResolved:Fire(player, { Kind = "Served", Grade, Pay, ... })`.
9. **Shift bookkeeping** — `ShiftService` listens to `CustomerResolved` and calls `RecordCustomer`: `Resolved += 1`, `Served/Perfects/Pay/Tips/BestCombo` updated, then `_checkEnd`.
10. **Next tutorial order** — if `servedNow < AUTO_GRANT_TUTORIAL_ORDERS` (3), `_checkAutoGrantFirstOrder(player, servedNow)` is scheduled 1 s later, which auto-grants the next scripted order.

## 5. Exact conditions for `OnboardingCompleted`

In `CustomerService:_onServeTriggered`, immediately after a **successful** serve (grade `Perfect` or `Close`; a Wrong serve never reaches this):

```lua
local servedBefore = self:_readServedCount(player)  -- profile Statistics.CustomersServed, read BEFORE incrementing
-- ...
if (servedBefore + 1) >= CustomerConfig.FIRST_SESSION_COUNT then
    a:OnboardingFunnel(player, 5, "OnboardingCompleted")
    a:Funnel(player, 5, "OnboardingCompleted")
end
```

So the exact conditions are:
1. The player is clocked in, within 15 studs, the NPC is still waiting, and `Rules.CanServe` passes.
2. `FindServeTools` returns a non-nil set of unserved tools and the overall grade is `Perfect` or `Close`.
3. `(Statistics.CustomersServed at serve time) + 1 >= FIRST_SESSION_COUNT`, with `FIRST_SESSION_COUNT = 3`. In other words, **the serve that brings the player's lifetime `CustomersServed` to 3 or more** fires it. With the tutorial auto-grant, this is the 3rd tutorial serve.
4. It fires inside a `pcall` alongside the other analytics; the actual `LogOnboardingFunnelStepEvent`/`LogFunnelStepEvent` calls are deferred (`task.spawn` in `AnalyticsEvents`) and deduped per player per step index (session memory only).

Diagnostic caveat (important for later): `_readServedCount` returns `CustomerConfig.FIRST_SESSION_COUNT` (3) when the profile read fails or times out. In that case the condition becomes `(3 + 1) >= 3` on the player's **first** serve, so `OnboardingCompleted` can fire prematurely — and the same fallback makes auto-grant see `served >= 3` and skip the tutorial entirely.

Also note: no check requires the serve to be Perfect, fast, or scripted. Any successful serve that crosses the threshold fires it.

## 6. Purpose of the recently added "Sink Washout"

Location: `src/shared/Kitchen/Recipes.luau` — `Recipes.Items["Sink"]` ("Wash Cup" branch), plus the `ClearAttributes` path in `KitchenService/Actions/SetToolAttributes.luau` and `RenameToolHolding.luau`. Historical rationale: `.review/agent-workflow/archive/FTUE-FIXES/plan.md`.

Purpose: the Sink is an **instant, in-kitchen reset station for a ruined or in-progress drink**. Before it existed, a player who made a mistake had to walk to a distant corner trash can, hold for 3 s, answer a Yes/No dialog, and walk back to the cup dispenser — a major first-session churn point.

Mechanics:
- The Sink's validity gate (`ToolNameValidityCheck`) was widened to accept any kitchen container/drink (cup, mug, milk, boba, water, coffees, tea, hot chocolate) — so it can receive a dirty drink, not just clean cups.
- Hold duration was reduced (3 s → 1 s).
- The `SelectFrom` dialog offers `Wash Cup` (plus `Cold Water` / `Hot Water`, which still make water drinks).
- `Wash Cup` branch runs, in order:
  1. `SetToolHoldingProperty` — hide `Liquid`, `BobaBalls`, and `CoffeeLid` (Transparency = 1);
  2. `RenameToolHolding` — a size-preserving rename that returns `"Mug"` for mugs, otherwise `"<Size> Clear Cup"` / `"<Size> Cup"` (determines clear vs. solid cup from the physical `CoffeeCup`/`CoffeeHolder` parts, falling back to the old name);
  3. `SetToolAttributes { ClearAttributes = true, Item = "Clear Cup" }` — the `ClearAttributes` path wipes `Syrup`, `Tapioca`, `Iced`, `Sugar`, `Lid`, `Blended`, **and `Served`**, then restores `Item`/`Size` (preserving the cup's real size from its `Size` StringValue, falling back to the `Size` attribute, then "Medium").

Net effect: the player holds an empty cup of the same size, correctly attributed, with the `Served` flag cleared, and can retry the recipe immediately. The earlier review pass specifically fixed `Served` retention (a washed cup would otherwise be skipped by `FindServeTools`), cup-size desynchronization when washing flavored drinks, a `#Chocolate` food-item false positive, and Clear-Cup demotion for tea — i.e., the washout had to manually reproduce the exact attribute/name state the normal cup-giver chain produces.

(Related client-side recovery: `KitchenController` detects a completed-but-wrong drink, points the beam/highlight at the nearest `TrashCan`, and toasts "Wrong recipe! Throw it in the trash can to try again." — trash is the fallback; the Sink is the preferred in-kitchen reset.)

## Chronological summary (the full first session)

Join → step 1 `Joined` → profile loads → auto clock-in → step 2 `ClockedIn` → CustomerService enables → auto-grant order #1 (Classic Milk Tea Boba, Medium; NPC appears at pick-up, ticket on HUD) → client guidance walks player to Clear Cup → grab cup → step 3 `FirstItemTaken` → Milk → Syrup (Classic Milk Tea) → Tapioca (Normal) → Serve the NPC → step 4 `FirstServe` (and `FirstOrderServed`) → order #2 (Fudge Brownie) auto-grants after 1 s → grab brownie → Serve → order #3 (Regular Coffee, Small) → make → Serve → `servedBefore = 2`, so `(2 + 1) >= 3` → **step 5 `OnboardingCompleted`** → `CustomersServed` now 3 → shift target `FIRST_SHIFT_SIZE = 3` met → shift ends → step 6 `FirstShiftCompleted` → ShiftEnding listeners: `CapsuleService` grants one Regular Pet Capsule (first shift, `StarterCapsule` guard), `ProgressionService` awards XP → level 2 → step 8 `FirstLevelUp` → nickname prompt opens after the shift card closes → step 7 `FirstNicknameSet` (or Skip). After the first successful serve, `DailyRewardController` also auto-opens the Daily Rewards dialog once `Statistics.CustomersServed > 0` (when a reward is claimable).

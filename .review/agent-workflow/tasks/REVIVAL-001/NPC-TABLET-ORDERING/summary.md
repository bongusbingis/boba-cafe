# NPC-TABLET-ORDERING — Evidence & Summary (REVIVAL-001)

Implementation of Jack's approved gameplay flow for NPC customer ordering via the Ordering Tablet and pickup counter transition.

## Flow Implementation

1. **At Counter**:
   - NPC arrives at Counter spot (`workspace["Ordering System"].Counter`).
   - Overhead displays a greeting bubble ("Hi, can I order?") without revealing drink details.
   - Patience timer does not tick down while waiting at counter; patience bar is hidden.
   - ProximityPrompt on NPC displays `ActionText = "Take Order"`.

2. **Taking Order (Ordering Tablet)**:
   - Clocked-in barista interacts with "Take Order" prompt (`CustomerService._onTakeOrderTriggered`).
   - Server picks or confirms customer order tailored to player recipe unlocks and fires `OpenOrderingTablet` client signal with order data and notepad text.
   - Client (`OrderController` & `App.luau`) mounts `Pages.Ordering` tablet with customer order.
   - `renderNotepad` and `RightPanel` display the customer request text (e.g. `1x Strawberry Milk Tea with Tapioca Pearls, Ice, Half Sweet`).

3. **Submit & Validation**:
   - Barista selects cup, base tea, flavor, milk, sweetness, and toppings, adding drink(s) to order.
   - Client-side validation (`Ordering/init.luau`) and Server-side validation (`Rules.ValidateSubmittedOrder` via `CustomerService:SubmitNpcOrder`):
     - If submitted drink(s) do not match what customer requested: notification displays `"That doesn't match what the customer asked for!"` and tablet stays open.
     - If matches: tablet closes with `"Order sent to kitchen!"` notification.
   - Server creates kitchen ticket assigned to taking barista (`CustomerConfig.ASSIGNMENT_MODE = "Dedicated"`).
   - Server frees counter spot (`ctx.ReleaseCounter(npc)`), allowing the next queued customer to advance.

4. **At Pick Up**:
   - NPC transitions to `AtPickup` state and walks to an assigned spot in `workspace["Ordering System"]["Pick Up"]`.
   - On arrival at pickup spot, patience timer starts ticking down (`npc:StartPatience()`).
   - Overhead bubble switches to display order drink icons (`npc:ShowOrderBubble()`) and patience bar.
   - ProximityPrompt switches to `ActionText = "Serve"`.

5. **Fulfillment**:
   - Barista brings prepared drink to NPC at pickup spot and triggers "Serve".
   - `CustomerService._onServeTriggered` validates drink match, completes ticket, awards BobaBucks + Tips + XP.
   - Pickup spot is released (`ctx.ReleasePickupSpot(npc)`), customer sits or leaves via Exit.

## Files Modified

- `src/shared/Configuration/CustomerConfig.luau`:
  - Added `ASSIGNMENT_MODE = "Dedicated"` to assign tickets directly to the barista who took the order.
- `src/server/Modules/CustomerService/Rules.luau`:
  - Added `Rules.FormatOrderItemForNotepad(item)` and `Rules.FormatOrderForNotepad(orderList)`.
  - Added `Rules.ItemsMatch(submitted, expected)` and `Rules.ValidateSubmittedOrder(submitted, expected)`.
- `src/server/Modules/CustomerService/Npc.luau`:
  - Added `AtPickup` state to State type enum.
  - Added `ShowGreetingBubble()`, `ShowOrderBubble()`, `StartPatience()`, `GoToPickup(pickupSpot)`.
  - Updated `_run()` loop to wait at counter until order submitted, navigate to pickup spot, start patience, and wait out patience.
- `src/server/Modules/CustomerService/init.luau`:
  - Added `OpenOrderingTablet` signal and `SubmitNpcOrder` remote method.
  - Added pickup spot management (`ClaimPickupSpot`, `ReleasePickupSpot`) and `OnAtPickup` callback in context.
  - Updated `_ensureNpcPrompt` to dynamically flip between "Take Order" (at counter) and "Serve" (at pickup).
  - Implemented `_onTakeOrderTriggered` and `_submitNpcOrder`.
  - Guarded automatic assignment loop in `_pacingLoop` when `ASSIGNMENT_MODE == "Dedicated"`.
- `src/client/Modules/OrderController.luau`:
  - Added `OpenOrderingRequested`, `CloseOrderingRequested`, `ActiveNpcOrder`, `OpenOrdering(data)`, `CloseOrdering()`.
  - Listened to `CustomerService.OpenOrderingTablet`.
- `src/shared/UI/App.luau`:
  - Connected `OrderController.OpenOrderingRequested` and `CloseOrderingRequested` to mount/unmount `Pages.Ordering`.
- `src/shared/UI/Pages/Ordering/RightPanel.luau`:
  - Added `CustomerRequest` section rendering `props.NpcOrderText`.
  - Updated button label to "Submit Order".
- `src/shared/UI/Pages/Ordering/init.luau`:
  - Integrated `npcOrderData`, customer request notepad view, and order matching validation.
  - Submits valid orders via `CustomerService:SubmitNpcOrder` and handles mismatch alerts.
- `src/server/Tests/CustomerService.spec.luau`:
  - Added unit test suites for `ASSIGNMENT_MODE`, `FormatOrderForNotepad`, and `ValidateSubmittedOrder`.

## Verification & Gates

- **Selene**:
  - Baseline warnings verified clean (2 pre-existing unused variable warnings in HEAD, 0 new warnings or errors introduced).
- **StyLua**:
  - `stylua --check` on all modified files: PASS (0 formatting violations).
- **Rojo**:
  - `rojo build default.project.json -o <temp>`: PASS (exit code 0).
- **Studio Unit Tests (TestEZ)**:
  - `CustomerService.spec.luau`: 104 passed, 0 failed.
  - Full Studio Server TestEZ suite: 713 passed (1 pre-existing failure in `OrderSpec.spec:114` unrelated to CustomerService/Ordering UI).

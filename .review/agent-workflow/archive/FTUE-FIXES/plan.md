# FTUE Remediation Plan: Boba Cafe

**Task ID**: FTUE-FIXES  
**Goal**: Resolve the FTUE funnel drop-offs at Step 3 $\to$ 4 (50% churn) and Step 4 $\to$ 5 (57% churn), and raise average session time from 1.4 minutes.

---

## Game-Design & UX Investigations

### 1. The Shift Length Wall (`ShiftConfig.luau`)
* **Finding**: `FIRST_SHIFT_SIZE` is currently set to 5 (`ShiftConfig.luau:9`), while onboarding (`FIRST_SESSION_COUNT`) requires 3 customers. Players who finish 3 tutorial drinks are still 2 customers away from completing their first shift. Because average session duration is 1.4 minutes, they quit before ever seeing the victory fanfare.
* **Remediation**: Align `FIRST_SHIFT_SIZE = 3`. Completing the 3 tutorial orders will simultaneously complete the player's first shift, granting 3 Stars, the Star Bonus BobaBucks, Career Level 2 (`FirstLevelUp`), and the Paycheck summary card.

### 2. Visual / Audio Juice (`InteractionRunner.luau` & `KitchenController.luau`)
* **Finding**: Every station model under `Workspace.Assets.Kitchen.Givers` contains an authored `Sparks` part with 3 `ParticleEmitter`s (`MiniSparks`, `Sparks`, `CoreMiniSparks`). Currently, no script ever triggers them. Interactions only play a sound effect with zero visual particle reward.
* **Remediation**: On successful station completion in `InteractionRunner.luau` (or via client event), trigger `:Emit(15)` on all particle emitters under `model:FindFirstChild("Sparks", true)`.

### 3. The Mobile Backpack Trap
* **Finding**: On mobile devices, tapping the screen or backpack button unequips the tool. `KitchenController` loses track of the cup, resets guidance to Step 1 (`Clear Cup`), and clicking any station displays `"You need to grab a cup first!"`. Mobile players assume their cup was lost or deleted and return to the dispenser.
* **Remediation**: In `KitchenController.luau`, track in-progress tools in `Backpack` when `heldToolAttributes()` is nil. Keep the guidance beam pointing to the active recipe station, and toast: `"Equip your cup from your inventory to continue!"`.

### 4. The Sink Reset Mechanic (`Recipes.luau` & `TrashService.luau`)
* **Finding**: `Sink` (`Recipes.luau:142`) currently rejects any cup with milk or syrup (`#Cup|!Milk`), and only turns clean cups into water. If a player makes a mistake, they must walk all the way to a corner trash can, hold for 3 seconds, answer a confirmation dialog, and walk back to the cup dispenser.
* **Remediation**: Allow the `Sink` to wash out in-progress or ruined drinks back to an empty cup (`Medium Clear Cup`), providing an instant, intuitive reset station inside the kitchen island. For trash cans, ensure `KitchenController` highlights the nearest trash can if a completed drink cannot be served.

### 5. Default Intent: `DEFAULT_CLOCKED_IN` (`ShiftService.luau`)
* **Finding**: Changing `DEFAULT_CLOCKED_IN` to `false` would break the single-player/early-game loop: if a new player orders as a customer with no other baristas present, nobody makes their drink. Furthermore, `AUTO_GRANT_FIRST_ORDER` explicitly requires `IsClockedIn == true`.
* **Conclusion**: Keep `DEFAULT_CLOCKED_IN = true`. The solution is not to defer clock-in, but to make the barista onboarding fast, rewarding, frictionless, and packed with visual/audio satisfaction.

---

## Detailed Implementation Roadmap

### Priority 1: Fix Destructive Station Feedback & Guidance Traps (Step 3 $\to$ 4) [COMPLETED - GATE PASS]
* **Dynamic Error Toasts (`KitchenController.luau`)**:
  Refactored `InteractionFailed` listener. Instead of the blanket `"You need to grab a cup first!"`, inspect the player's held tool (or backpack tool) and target station:
  - Holding cup without milk, clicking Syrup/Tapioca/Blender: `"Add Milk to your cup first!"`
  - Holding cup with Milk, clicking Tapioca: `"Add Syrup to your cup first!"`
  - Holding flavored milk, clicking Milk: `"You already added milk! Add Syrup next."`
  - Holding nothing: `"Grab a cup from the cup dispenser first!"` (or `"Equip your cup from your backpack!"` if in backpack)
* **Backpack Tool Awareness (`KitchenController.luau`)**:
  If `heldToolAttributes()` is `nil`, inspect `candidates` (including Backpack) for an in-progress cup/drink. Use that tool's attributes for `KitchenGuidance.FindActiveSpec` and `KitchenGuidance.Compute` so the guidance beam does NOT snap back to Step 1.
* **Wrong Drink Recovery & Trash Can Guidance (`KitchenController.luau`)**:
  Fixed the `allDone == false` and `guidance.IsServe == true` soft-lock. If a player holds a completed but wrong drink, point the guidance beam and highlight to the nearest Trash Can (tagged `TrashCan`), set `Label = "Throw wrong drink in Trash"`, and toast: `"Wrong recipe! Throw it in the trash can to try again."`
* **Station Particle Juice (`InteractionRunner.luau`)**:
  In `InteractionRunner:Run`, emitted particles from `model:FindFirstChild("Sparks", true)` upon interaction success.
* **Station Name Transmission (`InteractionRunner.luau` & `KitchenService/init.luau`)**:
  Updated `_onFailure` and `KitchenService.Client.InteractionFailed` to pass `stationName: string?` (`model.Name`) to client.

### Priority 2: Smooth the Onboarding Funnel (Step 4 $\to$ 5) [COMPLETED - GATE PASS]
* **Auto-Grant First 3 Tutorial Orders (`CustomerConfig.luau` & `CustomerService/init.luau`)**:
  - Configured `AUTO_GRANT_TUTORIAL_ORDERS = 3`.
  - Refactored `_checkAutoGrantFirstOrder(player, servedCountOverride)` and `_autoGrantFirstOrder(player, served)` to cycle through `FIRST_SESSION_ORDERS[served + 1]`.
  - Chained next tutorial order in `_onServeTriggered` when `servedNow < 3` after a 1s pacing delay.
  - Preserved normal "Dedicated" mode for all players with `served >= 3`.
* **Shift Size Alignment (`ShiftConfig.luau`)**:
  - Aligned `FIRST_SHIFT_SIZE = 3` (from 5), so completing the 3 tutorial orders immediately completes the player's first shift, granting 3 Stars, Star Bonus BobaBucks, Career Level 2 (`FirstLevelUp`), and the Paycheck summary card.
* **Dynamic Register Toast (`KitchenController.luau`)**:
  - Updated fallback toast text to `"Head to the register to take your next customer's order!"` after order 1+ is served.
* **Regression Audit & Verification**:
  - Verified `ASSIGNMENT_MODE = "Dedicated"` is unaffected for graduated baristas.
  - Verified manual POS tablet is untouched and opens properly when taking orders at the register.
  - Verified mid-tutorial disconnect/rejoin cleans up orphaned NPCs (60s limit) and seamlessly resumes at the player's saved step on rejoin.
  - Verified `bash scripts/gate.sh` (`GATE: PASS` with 0 new Selene findings, StyLua ok, clean Rojo build).

### Priority 3: Reduce Kitchen Interaction Friction [COMPLETED - GATE PASS]
* **Station Hold Durations (`Recipes.luau`)**:
  - Reduced `HoldDuration` on `Milk` (2.0s $\to$ 1.0s), `Syrups` (2.0s $\to$ 1.0s), and `Tapioca` (2.0s $\to$ 1.0s).
* **The Blender Trap (`Recipes.luau` & `KitchenService/init.luau`)**:
  - Reduced `Blender` hold duration from 5.0s to 2.5s.
  - Configured prompt `ActionText = "Blend (Optional)"` so players understand blending is not mandatory for standard drinks.
* **Sink Washout Station (`Recipes.luau` & `SetToolAttributes.luau`)**:
  - Reduced `Sink` hold duration from 3.0s to 1.0s.
  - Expanded validity check to allow all kitchen drinks and containers.
  - Added `"Wash Cup"` action branch that resets cups/mugs back to empty (`Liquid`, `BobaBalls`, `CoffeeLid` transparency = 1) and removes drink modifier attributes, allowing quick recovery right at the kitchen island without trekking to a distant trash can.

---

## Verification Plan
1. **Gate Verification**: Run `bash scripts/gate.sh` after each priority. Must show `GATE: PASS` with 0 new Selene findings.
2. **Logic & Spec Verification**: Run TestEZ suite in Studio or verify specs.

---

## Independent Code Review & Resolution (Subagents 1-3)
- **Subagent 1 (Sink Washout & State Reset)**: Flagged attribute retention (`Served`), cup size desynchronization when washing flavored drinks, `#Chocolate` food-item conversion, and Clear Cup demotion on tea.
  - **Resolution**: Patched `RenameToolHolding.luau` to supply the tool instance, updated `SetToolAttributes.luau` to wipe `Served` and preserve `tool.Size.Value`, tightened Sink gate to `#Hot Chocolate`, and added physical cup part discrimination (`CoffeeCup`/`CoffeeHolder`).
- **Subagent 2 (FTUE Auto-Grant & Shift Flow)**: `RESULT: PASS`. Verified `CustomersServed` gating, disconnect/rejoin persistence, clean transition to dedicated counter orders, shift math alignment (`FIRST_SHIFT_SIZE = 3`), and fail-safe order handling.
- **Subagent 3 (Kitchen UX & Toast Feedback)**: `RESULT: PASS`. Verified duplicate toast suppression via `SmallNotification.Route`, sound/animation independence from hold times, `OrderSpec` ignoring optional blender steps, and instantaneous ProximityPrompt triggers.
- **Final Gate**: `GATE: PASS` across all 9 touched files.

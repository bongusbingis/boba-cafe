# BOBA-PHONE: deferred brief (pick-up document)

Status: **packet written** (`packets/BOBA-PHONE.md`, 2026-10-21; Jack: port faithfully, wire to current gameplay). Previously DEFERRED by Jack, 2026-10-19: "I'd rather defer it so that we can focus on the task as a whole (gameplay especially) rather than a faithful port of something that's already proven in legacy code ... document it explicitly so that another agent can pick it up down the line (since it's a relatively easy port)".
Pick it up after the gameplay milestones Prime is driving, or when Jack asks. Prime owns scheduling. The first step is that an Architect turns this brief into `packets/BOBA-PHONE.md`.

## What Jack decided (source of truth: `.review/agent-workflow/decisions.md`)
- **DEC-040 (Q19 = B):** real players order through the legacy **Boba Phone**, not the counter registers.
  - The counter "Use Ordering System" prompt is disabled, once the phone exists (see "Interim" below).
  - Only the **"Boba"** app is kept, the Starbucks-app-style ordering page. Every other app is retired.
  - The phone is a **Tool in every player's inventory**.
- **DEC-043:**
  - **Q20 = A:** port the legacy look **faithfully**. It's existing UI, so DEC-013 is satisfied without restyling to STYLE.md tokens.
  - **Q21 = A:** after "Place Order", show the result via the existing notification toast (success, or the server's refusal reason). Hide the unwired Home/History tabs. An order-status screen is a later, separate ask.

## What exists (verified by PHONE-RECON; full detail in `../PHONE-RECON/evidence.md`)
- **Legacy GUI:** `StarterGui.UIArchive.OldUI.BobaPhone`.
  - Home has 8 icons: Boba, Subs, Web, Jokes, Games, Chat, Gifts, Event.
  - Only Boba, Web, Chat, Jokes and Word Of The Day have app frames. Retire everything but Boba.
- **Boba app flow** (`legacy-src/BobaPhone.Frame.Screen.Apps.Boba.Menus.Order.PhoneMenuController.luau`, saved in full):
  1. Category list.
  2. Item cards (ViewportFrames).
  3. Popups: Select, RequiredSelection, Options.
  4. "Add Item" adds to My Order (cap 3).
  5. "Place Order" fires `PhoneServiceReplica:FireServer("PlaceMobileOrder", order)`, with no response handling.
  - Only the Order page works; the Home/Order/History tab bar is not wired.
- **Raw React port by Jack's plugin:** chunked modules named `__REACT_…` under `StarterGui.UIArchive.OldUI.BobaPhone.Frame`. The earlier single module `__REACT_PHONE` is empty (0 bytes), so ignore it. Chunk inventory, compile check and quality notes: `../PHONE-RECON/evidence.md`, section "Chunked React port (DEC-043)". Sources are saved in `../PHONE-RECON/react-port/`.
  - **Chunk summary (recon 2026-10-19):**
    - There are two modules: `__REACT_TOPFRAME` (774 bytes, the status-bar notch) and `__REACT_SCREEN` (175,905 bytes, 3,444 lines). The Boba app is lines 549-1380; the rest is the shell, Home, CloseApps and the retired apps. The phone body Frame and its constraints were not chunked; port them from the legacy tree.
    - Both compile under `loadstring`. Each is a bare static `c("Frame", {...}, {...})` dump: no `return`, no `require`, `c` undefined, and no state or handlers. Script children are empty stubs.
    - 56 legacy image ids. Sizing is mostly scale, with offsets in the popups and Order rows.
    - Dropped or degraded: the item-card ViewportFrame survives only as an empty template, the Boba root's background image is missing, and the greeting and date/time are hard-coded.
    - Fonts and colours stay as in the dump: Q20 = A means a faithful port, not a STYLE.md token mapping.
    - **The files in `../PHONE-RECON/react-port/` were transcribed by an agent from the script reader, so they are not byte-exact.** Read the source of truth from the Studio modules themselves.
- **Phone Tool:** `ReplicatedStorage.ToolsStorage."Boba Phone"` (place content).
  - No Handle (`RequiresHandle = false`).
  - One 16-line LocalScript toggles `PlayerGui.BobaPhone.Enabled` on Equipped/Unequipped (`legacy-src/ToolsStorage.Boba_Phone.LocalScript.luau`).
  - StarterPack is empty.
- **Device sizing:** `legacy-src/BobaPhone.ModifyDeviceSize.luau`.

## Mapping legacy to current
| Legacy | Current |
|---|---|
| `Boba.Shared.FoodService.FoodTable` | `src/shared/Ordering/Menu.luau` (same shape plus `IsLaunchItem`). Show launch items only. |
| `PhoneServiceReplica "PlaceMobileOrder"` | `OrderService:CreateOrder(Players.LocalPlayer.UserId, {{Category, Item, CustomInfo}})` returns `{Success, Message}`. The server allows 1-4 items, a 5 s debounce and one open order per player, and checks customerId == caller (`OrderService.luau` `OrderService.Client:CreateOrder`). |
| Request shape | Copy how `src/shared/UI/Pages/MobileOrder/init.luau` and `src/shared/UI/Pages/Ordering/init.luau` build `orderItems` (`OrderSpec.spec.luau` "a MobileOrder order item resolves"). |
| replica / Maid | Knit / Janitor |
| ViewportProvider | No equivalent found by name. Search before building anything (DEC-008). |

## Scope for the eventual packet
1. **React phone** (Rojo-managed, e.g. `src/shared/UI/Pages/BobaPhone/`):
   - Phone shell plus the Boba app only, ported faithfully from the chunks and the legacy tree. Use legacy asset ids as-is.
   - Wire it to `Menu.luau` and `CreateOrder`.
   - Toast the result.
   - Keep the 3-item cart cap (legacy).
   - Hide the Home/History tabs.
2. **Tool:** the server gives every player a clone of `ReplicatedStorage.ToolsStorage."Boba Phone"` on spawn. Destroy the clone's legacy LocalScript, so no place edit is needed. A client controller opens/closes the React phone on Equipped/Unequipped.
3. **Disable the counter register prompt** (`src/shared/UI/Components/Core/Hud/TopBar.luau`, the "Use Ordering System" prompt on `Ordering System.Computers`). Do this in the same change as the phone, so players are never left with no way to order.
4. Specs for the request builder (pure), and a Lens edit-mode capture of the phone for Jack.

## Port risks
- The legacy server and dependencies are absent (`ReplicatedStorage.Boba`, RemoteStorage, ReplicatedValues, ViewportProvider). Rewire to the current services; don't resurrect them.
- Item-card ViewportFrames need models. Find where the current UI gets drink models before building anything; otherwise report BLOCKED.
- The legacy scripts contain bugs: undeclared globals in MenuHandler, and TimeHandler. Port the behaviour, not the bugs.
- The Tool and the legacy GUI are place content, not Rojo. Code must name exact instance paths (AGENTS.md).

## Interim until the phone lands (DEC-046: register prompt hidden for clocked-in players)
The register prompt stays, because removing it now would leave real players no way to order. It shows for everyone and fights with the NPC Serve prompt for clocked-in baristas (the Q19 context). See the board note for the interim fix status.

## Hard constraints for whoever picks this up
- Never run Play or TestEZ (DEC-019); Jack does.
- Gate every changed Luau file: `wsl bash -lc 'cd /mnt/c/Users/jackc/desktop/boba-cafe && . .review/agent-workflow/tools/wsl/env.sh && stylua <files> && gate <files>'`.
- No Studio saves without a Rigger lease.
- Serve-path invariant (M3-REM-B): nothing may yield between the serve guards and the payout in `CustomerService:_onServeTriggered` or the `RealOrderService` payout. The phone must not touch those spans.
- The real-player order bonus and every price are unchanged (economy = Jack approval).

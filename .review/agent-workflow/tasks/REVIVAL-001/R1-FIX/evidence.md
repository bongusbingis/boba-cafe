RESULT: PASS
Task: REVIVAL-001-R1-FIX (Mason). Base commit: cbf5271 (working tree also has accepted uncommitted M1.5cd edits, untouched).

## Per-finding
| Finding | Fixed | How | Where |
|---|---|---|---|
| P1-1 | yes | Launch allowlist in Menu data (`LaunchItems`, `LaunchChoices` for syrup/tapioca, `IsLaunchItem`); `CreateOrder` refuses off-menu items ("That item isn't available right now.") before any state change; `_releaseClaimedOrder` returns a Being Prepared order to Pending on clock-out (via `_onClockedInChanged`, used by the ClockedInChanged connection); leave path unchanged | Menu.luau (LAUNCH_* block, end of file); OrderService.luau `getFoodTable`, `_releaseClaimedOrder`, `_onClockedInChanged`, `CreateOrder` loop, KnitStart connection |
| P1-2 | yes | Server refuses a deposit into a node with OrderOwner ~= 0 (Announcement + hides prompt); client hides deposit prompt when OrderOwner ~= 0 and watches OrderOwner while the prompt is on | OrderService `_handlePickUp` staff branch; OrderController.luau PickUpNodeVisibilityChanged handler |
| P2 | yes | `SetStateEnabled(Seated,false)` | Npc.luau next to Climbing/Swimming |
| P3-6 | yes | `_runSelectFrom` snapshots the held tool before the dialog and aborts (`SelectFrom: held tool changed`) before any branch action if it differs | InteractionRunner.luau |
| P3-7 | yes | `CollisionGroupSetCollidable(NPC,"Default",true)`; no other pairs | CustomerService/init.luau `_setUpCollisionGroups` |
| P3-8a | yes | barista count moved inside the pacing pcall; new `warnThrottled` (60 s) | CustomerService/init.luau `_pacingLoop` |
| P3-8b | yes | `_safeWatchPlayer` (pcall) used by KnitStart loop and PlayerAdded | CustomerService/init.luau |
| P3-8c | not changed | Menu's unbounded `WaitForChild("SelectorModels")` feeds `Models["Cup"]`/`Models["IceCream"]` at require time; bounding it needs nil handling throughout Menu, not a small local change. Stays tracked with M0.5 | Menu.luau:2 |
| P3-8d | not changed | out of the asked scope; leak negligible | |
| P3-9 | yes | `Served=true` set on deposited tools; `FindServeTools` skips Served tools (OrderSpec untouched) | OrderService.luau |
| P3-10a/c | yes | specs added (TestEZ, unrun) | OrderService.spec.luau, CustomerService.spec.luau |
Not in lane: P3-4, P3-5, Q12 UI filtering (UI pages untouched).

## Changed files (sha256)
5cb125b4ebcd88f018eebd588de5df6e872807e00ed9d5a7c430b6840f737b61  src/client/Modules/OrderController.luau
06f7be5280ba842153371cd458610fa2d4082d7c678312f307d5b06c8c0c9cd5  src/server/Modules/CustomerService/Npc.luau
3948b6bdf96a813c786f537da3d4d2df7c5c9a9a69da8148d717cc2d92f6ab8d  src/server/Modules/CustomerService/init.luau
742ffddefbfee799738386ceaef79f8741fd68920aba7d29fc81a0f3914d8363  src/server/Modules/KitchenService/InteractionRunner.luau
512afe0b06eda232c2fb6bbbcbe2d54dcf93f32845480658d209f18748bbe9f2  src/server/Modules/OrderService.luau
a38bc378d28e4ea38eeddc5017ca6ac336a58b4a37f8a6990e57ea1d716bc067  src/server/Tests/CustomerService.spec.luau
7192eab798cba56ad5bb8a5a410610746286d4dc5148a2f31d0699b38ed9644e  src/server/Tests/OrderService.spec.luau
56dea6c344047244d47dd3d38967f11f47fa9ecf165e2803bdad82ddcdaf6583  src/shared/Ordering/Menu.luau

Note: stylua rewrote these files with LF line endings (they were CRLF in the working tree).

## Gate output (gate.txt)
PASS  src/server/Modules/OrderService.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
PASS  src/server/Tests/OrderService.spec.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
PASS  src/shared/Ordering/Menu.luau  selene new=0 (baseline[HEAD]=1 now=1)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
PASS  src/client/Modules/OrderController.luau  selene new=0 (baseline[HEAD]=1 now=1)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
PASS  src/server/Modules/CustomerService/init.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
PASS  src/server/Modules/CustomerService/Npc.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
PASS  src/server/Tests/CustomerService.spec.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS
PASS  src/server/Modules/KitchenService/InteractionRunner.luau  selene new=0 (baseline[HEAD]=0 now=0)  stylua=ok
PASS  rojo build -> /mnt/c/Users/jackc/AppData/Local/Temp/boba-gate/gate-build.rbxl
GATE: PASS

## Shim results (lune, NOT TestEZ)
Menu launch block extracted and run with a fake FoodService: 9/9 IsLaunchItem checks (pool boba/coffee/brownie accepted; smoothie, latte, croissant, Almond syrup, non-string tapioca, nil refused).

## Gauge Studio steps (batched)
1. Run TestEZ: OrderService.spec (new: off-menu refusals, occupied node, Served re-deposit, picked-up drink, clock-out release) and CustomerService.spec (ORDER_POOL x SIZE_WEIGHTS via real OrderSpec/Menu; pool on launch menu). Also rerun OrderSpec/KitchenAttributes specs.
2. Play with 2 baristas + 1 customer: B claims, C deposits into node 1, B presses E on node 1 -> "This spot is taken", prompt hides; B's prompt hides without pressing when C fills it.
3. Barista claims an order, clocks out -> order shows Pending, notepad clears, another barista can claim it.
4. Order via the current UI an off-menu item (smoothie) -> refused; Regular/Brownie/Boba (Classic Milk Tea, Normal) still work end to end.
5. Pick up a deposited drink, re-deposit it for a new order -> "An item is missing".
6. NPC walk past a Seat: no sitting; NPCs do not fall through the floor (NPC<->Default); log the registered collision groups.
7. Station with a dialog (Coffee Machine): swap the held tool during the dialog -> interaction aborts, tool unchanged.

## Open
- The current ordering UIs still list off-menu items (refused with a message); filtering is a UI lane via `Menu.IsLaunchItem`.
- Items with launch status but unconfirmed stations (Milk, Flavored Milk, Decaf/Cortado/Koa) follow design section 7; Latte excluded.
- Release on clock-out leaves the barista's tools untouched.
- P3-8c, P3-8d, P3-4, P3-5 not done (see above).

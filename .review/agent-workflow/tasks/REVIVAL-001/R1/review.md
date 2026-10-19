RESULT: FAIL
Verdict: **BLOCK** (until P1-1 and P1-2 are fixed or Jack accepts them; everything else can be fixed or tracked)

# REVIVAL-001-R1: Sentry review of the overnight M1.3 / M1.4core / M1.5a commits

- **Task:** REVIVAL-001-R1 (Sentry lane; independent of the Mason lanes that wrote M1.3a-d, M1.4core and M1.5a)
- **Source state:** committed range `2c6e248..cbf5271` on branch `uhweifh`
  (`2c6e24873363cd59221647e6b32d43de1d928abf..cbf5271f506eee95c46b160c17d56a464af088ce`), i.e. `2bdbba1`, `041888d` and `cbf5271`.
  Code was read only through git objects (`git diff 2c6e248 cbf5271 -- src/`, `git show cbf5271:<path>`). The working tree was not
  read for `src/`: another lane is editing it, and every tracked file has a CRLF-only change.
- **Context read:** the Sentry contract and the Review gate in `docs/AI_AGENT_WORKFLOW.md`; `docs/CONVENTIONS.md`; M1.1 design; M1.2 design §9;
  the lane evidence for M1.3, M1.3c, M1.3d, M1.4core and M1.5a. Unchanged code on the affected paths was read at `cbf5271`:
  `InteractionRunner`, `ToolNameValidityCheck`, `RenameToolHolding`, `SetToolHoldingProperty`, `ActionRegistry`, `OrderController`,
  `init.server.luau`, `Styles`, `WorldPath`, `Menu`.
- **Mode:** read-only. No Studio, no TestEZ, no lune. File:line references are at `cbf5271`.

## Summary

The core contracts are sound. Specs are rebuilt on the server from the Menu. Matching reads only server-written attributes, on tools in
the caller's own Character and Backpack. The deposit is synchronous, with no yield between the pick and the move. Every station writes
its attributes as its last step. `CustomerService` never blocks start-up, has a clean disabled path, and wraps each NPC thread in a pcall.

There are two blockers, and both are on the rewritten deposit path:

1. **P1-1 (regression in this range).** A deposit now needs a tool whose attributes match. Many items on the orderable Menu cannot be
   made by any station, and the current place has none of the kitchen tools yet. Once a barista claims such an order, they cannot claim
   or queue for another one, and the customer cannot place a new order. Both stay stuck until one of them leaves.
2. **P1-2 (existing; the dialog that slowed it down is now gone).** A barista can deposit into a pick-up node that another barista has
   already filled. The first customer's order is then lost, and that customer cannot order again for the rest of the session.

## Findings

| # | Sev | File:line (cbf5271) | Issue and failure scenario | Conf. | Smallest fix |
|---|---|---|---|---|---|
| 1 | **P1** (regression, `041888d`) | `src/server/Modules/OrderService.luau:706-715` (deposit refuses unless `FindServeTools` matches); lock-in at `:311-313`, `:621-623`, `:553` (no claiming or queueing while a "Being Prepared" order exists), `:846-848` (customer cannot order while an order is open), `:964-970` (clocking out keeps the order), `:339-347` (released only when someone leaves) | Before this range the deposit counted tools: any N tools would do. Now each spec must match a tool's `Item`, which only kitchen stations write. **Orderable but impossible to make:** all 16 Smoothies (`Menu.luau:347-352`); Custom Boba with Almond, Mint, Orange, Blueberry, Banana, Avocado, Honeycomb or Peach syrup (on the Menu, but no dispenser in `Recipes.luau:86-112`); Latte, Oolong Tea, Salted Hot Chocolate and 13 pastries; Teas and Water (no Sink in the place). In the current place every item is impossible to make, because `SharedStorage.Tools.Kitchen` is still pending (M0.1, M1.3d Risks). **Scenario:** a player orders a Banana Smoothie. A barista claims it, but every deposit attempt says "Wrong item", and there is no way to drop the order. That barista cannot claim or queue again, and the customer cannot reorder. If the barista leaves, the order returns to Pending, and the next barista who claims it (oldest first) is stuck the same way. M1.4e's assignment will also skip this barista through `HasActiveOrder`. This breaks continued play (Review gate: changed readiness gates must hold up through degraded or broken content). | High | (a) **Required:** reject impossible items in `CreateOrder` (`buildOrderItem`, `:199-204`) with `{Success=false, Message="That item isn't available right now."}`. Check against a server-side launch allowlist, the "Launch menu (works today)" table in M1.1 §1, kept in config and marked `-- PROPOSED (Jack, Q12)`. (b) Defence in depth: let a barista release a claimed order. For example, triggering the staff screen while preparing an order returns it to Pending, so a broken station or missing content cannot lock anyone. (c) Q12 menu trim so the UI stops offering these items. Add specs for (a) and (b). |
| 2 | **P1** (existing; on the rewritten block) | `OrderService.luau:696-717` (staff path; `ownerValue.Value = playerOrder.customer` at `:717` with no "is this node free" check); `src/client/Modules/OrderController.luau:74-75`; free nodes are shown only at claim or dispatch time, `OrderService.luau:518-522`, `:600-604` | Barista B claims an order, and B's client turns on the prompt of every node that is free *at that moment*. Barista C then fills node 1 for customer X. Nothing turns node 1's prompt off for B. B presses E at node 1 (often the nearest node). The deposit is now immediate, because the selection dialog and the `_areaDebounces` lock are gone, so the node's owner becomes B's customer Y. X's prompt now leads to the staff path and does nothing (`:644`, `:698-700`). X's order stays "Ready for Pick Up" (`:688-693` removes it only on pickup), so `_hasOpenOrder(X)` blocks X from ordering for the rest of the session. X's `Order_X` folder also leaks in ServerStorage, because cleanup is keyed by the node's owner (`:363-380`). Mason recorded this as a question (M1.3d Q2); this review asks for the fix. | High (code path); Medium (how often) | Put this at the top of the staff branch, before `FindServeTools`: `if ownerValue.Value ~= 0 then self.Client.PickUpNodeVisibilityChanged:Fire(player, area, false); self.Client.Announcement:Fire(player, "Cannot Deposit Order!", "This spot is taken. Use a free one.", COLOR_ERROR); return end`. Add a spec: depositing into an occupied node changes nothing. |
| 3 | P2 | `src/server/Modules/CustomerService/Npc.luau:110-111`, `:318-324` | Only Climbing and Swimming are turned off. The place has 243 seats (recon-memo). An NPC whose path brushes a `Seat` sits down. `MoveTo` does not stand it up, so every segment times out. The `PivotTo` fallback then either fails to move the NPC off the seat or drags the seat's assembly with it. After 3 fallbacks the NPC is despawned, and a chair may be left in the queue lane. | Medium (depends on how the Path sits relative to seats) | Add `humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)` next to the existing lines. |
| 4 | P3 | `src/shared/Ordering/OrderSpec.luau:484-523`; `OrderService.luau:79-87`, `:711` | `PickTools` is greedy, as designed, so it can refuse a deposit that has a valid assignment. Example: the order is {Small Regular, Medium Regular} and the barista holds [Small Regular, Small iced Regular]. Pass 1 gives the Small spec the plain cup. The Medium spec then has only the iced cup, which is Wrong. The result is "An item is missing", although Small→iced (Close) plus Medium→plain (Close) is valid. In multi-item orders, "An item is missing" is also the only text shown when every item is present but one is wrong. | High (logic); Low (impact) | Accept as designed, or with at most 4 specs, fall back to a small backtracking search when the greedy pass fails. For a multi-spec miss, report the unfilled spec's `Match` reasons against its best candidate instead of "Missing". |
| 5 | P3 | `OrderSpec.luau:224-241` and `:301-333`; `src/shared/Kitchen/Recipes.luau:252`; `src/server/Tests/OrderSpec.spec.luau:757-761` | An iced, sugared coffee that gets sugar before ice: `StepState` returns current = Ice row and no problem. The Ice Machine gate takes only the exact coffee name, so it refuses "Regular + Sugar" (M1.1 §0.4). The card (M1.5b) would point the player at a station that rejects the tool and say nothing. The spec case "sugar before ice leaves ice current" encodes the implementation, not the kitchen. Not in the NPC slice (the pool's coffee is not iced), but a player can order it. | High | When the spec wants ice, the tool has `Sugar == true` and `Iced ~= true`, return `{Step = <ice row>, Severity = "Close", Reason = "Iced", Reasons = {"Iced"}}`, which is the grade `Match` gives the finished tool. Update the spec case to expect it. |
| 6 | P3 | `Recipes.luau:194-229` (Coffee Machine: gate at `:194`, then a dialog), `:130-166` (Sink); `src/shared/Kitchen/RecipeConstructors.luau:81-89`; `src/server/Modules/KitchenService/InteractionRunner.luau:85-140`; `.../Actions/SetToolAttributes.luau:17-19,29` | At stations that check the gate and then open a dialog, the held tool is validated before the dialog yields. Each later action looks up whatever tool is held at that moment. A player who switches tools during the dialog has the rename and the `SetToolAttributes` applied to a tool that never passed the gate (for example, a brownie becomes `Item=Regular`). So the claim that a failed gate leaves the tool unmarked holds only for the validated tool. This is pre-existing for names; it now also affects grading. No real gain today, because cups are free and the 7 s hold happens before the trigger. Related: the Sink gate `#Cup|!Milk` accepts any tool without "Milk" in its name (a coffee, a mug, a brownie) and marks it `Item=Water`. | High (mechanism); Low (impact) | Repeat the station's gate as the first step of each branch: `{ "ToolNameValidityCheck", { "#Cup", "!Clear" } }` in `makeCoffeeVariant`, and `{ "ToolNameValidityCheck", { "#Cup|!Milk" } }` in both Sink branches. Tighten the Sink gate under Q14 (attribute gates), not here. |
| 7 | P3 | `src/server/Modules/CustomerService/init.luau:197-208`, `:212-230` | The groups are only partly hardened. (a) `NPC`↔`Default` is never set explicitly. If the place already has an authored `NPC` group (an old NPC system exists in `OldScriptables.NPCFolder`) that does not collide with Default, NPCs fall through the floor. They then churn: spawn, fall, despawn, every few seconds. (b) `CafePlayers` starts out colliding with every group. If the place has authored groups that let players through (Default set not to collide with some group X), players in `CafePlayers` would start colliding with X. No `src` code uses collision groups (`git grep` at cbf5271), so the only risk is authored groups, which are UNVERIFIED (Mason Q5). | Low to Medium | In `_setUpCollisionGroups`, add `CollisionGroupSetCollidable(NPC, "Default", true)`. For each group from `GetRegisteredCollisionGroups()` other than NPC, set `CafePlayers`↔g to match `CollisionGroupsAreCollidable("Default", g)`. Gauge records the place's registered groups. |
| 8 | P3 | `init.luau:326-335` (`:328` is outside the pcall), `:353-357`, `:219-223`; `OrderSpec.luau:105-119` reaches `Menu.luau:2` | (a) `self._baristas = self:_countBaristas()` is outside the pcall. One throw from `ShiftService:IsClockedIn` ends the pacing thread, and no NPC spawns for the rest of the server's life, with no warning. (b) In KnitStart, the `_watchPlayer` loop runs unprotected before `task.spawn(_pacingLoop)`, so an error there leaves `Enabled = true` with no spawning. (c) Existing issue (M0.5 P3): `Menu` does an unbounded `WaitForChild("SelectorModels")`. That is now also reached from the pacing thread through `FromOrderItem`, so if it is missing the thread hangs silently. (d) The per-character `DescendantAdded` connection is not tracked, which goes against the CONVENTIONS cleanup rule. The leak is negligible, because the closure does not capture the character. | High (a, b, c); Low impact | Move the barista count inside the pcall'd function. Start the pacing loop before watching players, or pcall `_watchPlayer`. Keep the per-character connection in `_characterConnections` and disconnect it on the next `CharacterAdded` and in `PlayerRemoving`. (c) stays tracked with M0.5. |
| 9 | P3 (existing; stricter than before this range) | `OrderService.luau:656-673` (`:672` hands the tools back with their attributes); `:785-802` | A picked-up order keeps its marks, so one made drink can satisfy any number of orders. Solo loop: order a brownie for yourself, clock in, claim it, deposit, pick up, reorder after 5 s, and deposit the same brownie again. Every loop adds `OrdersCreated`, `OrdersPrepared` and `ItemsOrdered`. No currency is involved today (there is no QuestService at cbf5271), but leaderboard stats are inflated. M1.4e must decide whether a drink received from a pick-up can be served to an NPC for pay. | High | At deposit, `tool:SetAttribute("Served", true)`. In `FindServeTools`, skip tools that have `Served`. That is 2 lines. |
| 10 | P3 (tests) | `src/server/Tests/CustomerService.spec.luau:1-170`; `src/server/Tests/KitchenAttributes.spec.luau:41`, `:89-113`; `OrderService.spec.luau` | (a) `CustomerService.spec` tests only `Rules`. Nothing proves that every `ORDER_POOL` entry, at every `SIZE_WEIGHTS` size, resolves through the real `OrderSpec.FromOrderItem` against the real Menu. The evidence lists this as UNVERIFIED; a pool typo would silently skip spawns. (b) `KitchenAttributes.spec` has its own copy of the InteractionRunner loop and skips `SetToolHoldingProperty`, so a runner change would not be caught. This is acceptable because the actions themselves are real. (c) No spec covers P1-1, P1-2 or P3-9. (d) None of these specs has run under TestEZ in Studio; all runs so far were lune shims. Otherwise the OrderService and OrderSpec specs test real behaviour (real Tools, real `_handlePickUp`, an agreement-with-`Match` check), not a mirror of the code. | High | (a) Add a loop over `ORDER_POOL` × sizes that calls `FromOrderItem` and asserts a spec. (c) Add specs alongside the fixes. (d) Gauge runs the batched TestEZ pass. |

**Counts:** P0 0 · P1 2 · P2 1 · P3 7.

## Verified OK (at cbf5271)

- **Server authority.** `CreateOrder` takes only `{Category, Item, CustomInfo}`, rebuilds each item from the server Menu, and derives
  `specs` on the server (`OrderService.luau:155-205`, `:834-855`). The client's `DefaultInfo` is ignored. `FindServeTools` reads only
  `player.Character` and `player.Backpack` of the caller (`:785-802`, `:255-272`). Attributes are set only by server actions, so a client
  cannot forge them or deposit another player's tools. No new remotes were added: `CustomerService.Client = {}`, and `HasActiveOrder`,
  `GetPendingCount` and `FindServeTools` are server-only.
- **Deposit atomicity.** `FindServeTools` → status Ready → tools moved runs with no yield (`:706-750`). A second press finds no
  Being Prepared order, so a double deposit is impossible. A miss changes nothing except the Announcement (the spec checks this).
- **Attribute writes.** `SetToolAttributes` and `GiveTool` validate every pair before writing anything (`SetToolAttributes.luau:39-54`,
  `GiveTool.luau:32-58`). Every station's write is its last action (`Recipes.luau:152,164,186,244,259,318,337,376`;
  `RecipeConstructors.luau:87,100,117,130`). `InteractionRunner` stops at the first false or error (`:143-169`, pcall at `:182`), so a
  failed gate leaves the validated tool unmarked (see P3-6 for the swap caveat). Blender writes nothing, as Q3 requires. The slice-item
  attribute shapes match M1.2 §9.
- **OrderSpec.** `Match` and `PickTools` follow M1.1 §4 exactly. `FromMenuItem` and `FromOrderItem` reject bad input. Matcha Tea Boba
  stays safe even though it shares `ServeItem = "Boba"`, because its syrup set is Matcha only. The Menu loads lazily, so OrderSpec can
  be required at start-up.
- **Steps and StepState (M1.5a acceptance).** Checked by hand for the 3 slice items. Each step advances; holding nothing gives 1; a wrong
  syrup at step 3 is Wrong with Step = 3; a wrong size is Close with Step = 1. Severity agrees with `Match` on finished tools.
- **CustomerService start-up and continued play.** KnitStart runs in Knit's `task.spawn`, so the 10 s world budget does not block other
  services or joining. `WorldPath.waitFor` uses one shared deadline. When the contract is missing there is exactly one warn, and no
  folder, loop or collision-group change. `PlayerAdded` and `PlayerRemoving` are wired after `Knit.Start` (`init.server.luau:64-96`), and
  players who join while the world is resolving are caught by the `GetPlayers` loop. Each NPC thread is pcall'd and always ends in an
  idempotent `Destroy`, which releases its line and counter spots and its count. `SetNetworkOwner(nil)` is pcall'd. The `PivotTo`
  fallback is bounded (6 s per segment, 3 in a row, then despawn). `Styles` is pure and safe to require on the server. No data,
  currency or ProfileTemplate change. `TESTS_ENABLED` is not touched.
- **Client ordering UIs (M1.3b).** Both send `Category`, guard against double submits, and use `pcall(...:expect())`
  (`MobileOrder/init.luau`, `Ordering/init.luau`).

## Evidence claims cross-check

The behaviour claimed in the M1.3, M1.3c, M1.3d, M1.4core and M1.5a evidence matches the code at cbf5271, apart from the gaps above.
Every TestEZ and Studio acceptance in those rows is still open. The lune shims (54/54, 34/34, 27/27, 116/116) are not the acceptance test.

## Not verified

- Any runtime behaviour. Studio was not run: no MoveTo or PivotTo, no collision groups, no seat behaviour, no bubble rendering, no
  disabled path, no 10-minute soak, and no deposit round trip (M0.4 §4).
- The authored collision groups and seat layout in the place, and whether `workspace.Assets.NPC` will exist (M1.4a).
- `CreateHumanoidModelFromDescription` failure modes in a live server.
- How often P1-2 happens with real multi-barista traffic.

## Tracked (not findings for this range)

- `docs/SYSTEMS.md` must name `workspace.Assets.NPC.{Entry,Exit,Path,Queue,Counter}`, the runtime `workspace.Customers` folder and the
  `NPC` / `CafePlayers` groups (CONVENTIONS §2). This is a Quill follow-up, already noted by Mason.
- M0.5 P3 items that are still open: rejected `CreateOrder` calls warn without a debounce (`OrderService.luau:839`), and the unbounded
  `Menu` wait (see P3-8c).

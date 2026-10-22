# Systems

Each system's responsibility, owner modules, key invariants, and protected contracts. Paths are relative to `src/`.

All systems serve the four highest product priorities: **monetization, engagement, retention, and CCU**. Default to continued play even when presentation or a feature is degraded or broken. Showing a failure screen or deliberately blocking a player from joining or playing requires Jack's explicit approval, including for critical errors. Preserve purchase, ownership, server-authority, and saved-data correctness while isolating failures. See `CONVENTIONS.md` and `AI_AGENT_WORKFLOW.md` for design and review requirements.

Statements here describe the working tree on branch `uhweifh` as read on 2026-10-14 (HEAD `92f6144` plus the uncommitted M0 changes). Studio runs (REVIVAL-001 M0.4 run 2, one player) exercised boot, the clock-in gate on kitchen stations, and a `CreateOrder` / claim / deposit / pick-up round trip; each of those is marked below. Everything else was read from source and not run, and no multiplayer path has been run. Verify before relying on them for a release decision, and update this file in the same change that alters a system.

### Startup & Lifecycle
**Purpose:** Boots Knit on server and client and fans player join/leave out to every service and controller.
**Owner modules:** `server/init.server.luau`, `client/init.client.luau`.
**Key invariants:**
- `AddServicesDeep` / `AddControllersDeep` `require` every ModuleScript under `Modules/`, helpers included (`Spill`, `PromptBuilder`, `Actions/*`, `Pets/*`, `PlayerSetup`). A module that calls `CreateService` / `CreateController` is registered automatically; helpers are only required, so they must be safe to require at startup. The client loop indexes every result for `PlayerAdded` / `PlayerRemoving` without a type check, so a helper under `client/Modules/` must return a table. The server loop skips non-tables.
- `PlayerAdded(player)` runs for players already present and for later joins; `PlayerRemoving(player)` runs in a `pcall` per service so one failure cannot stop the rest. `DataService` is last so profile data stays readable during teardown.
- `STUDIO_GRANT_ALL_ITEMS` grants every Capsule and Particle item in Studio only and is a development shortcut.
- There is no join gating. The group-rank join kick that used to live in `init.server.luau` was a debug lock and was removed with Jack's approval (DEC-004). Group rank is not read at join and does not gate gameplay (DEC-002); do not add a join check.
- Content authored in the place is resolved at `KnitStart` or at use time with bounded waits (`shared/Utility/WorldPath.luau`: `find` never yields and returns nil; `waitFor` spends one shared deadline across the whole path), not at require time, because every module under `Modules/` is required at startup. A missing authored folder disables only the feature that needs it, with a `warn` naming the path. Known exceptions at require time: `RecipeConstructors` makes the bounded 5 s wait described under Kitchen; `Inventory` still does an unbounded `WaitForChild` for `ReplicatedStorage.Networking.InventoryEvent` at require time, and `Ordering/Menu.luau` does an unbounded `WaitForChild("SelectorModels")` (OrderService requires Menu lazily, on first order).
**Depends on:** Knit.
**Consumers:** Every service and controller.

### Player Data
**Purpose:** Single source of truth for loading, replicating, and saving persistent player profiles.
**Owner modules:**
- `server/Modules/DataService/init.luau`
- `server/Modules/DataService/PlayerSetup.luau`
- `shared/Configuration/ProfileTemplate.luau`
- `client/Modules/DataController.luau`
**Key invariants:**
- Profiles are read through `DataService:GetDataAsync(player)` (yields until loaded) and written with `:SetValue(path, value)` so mutations replicate to the owning client.
- `ProfileTemplate` is both the default data and the type. New fields are reconciled into existing profiles; renames and removals need a migration. Changing `PROFILE_STORE_NAME` abandons all saved data and needs Jack's approval.
- A failed or lost profile session kicks the player with a retry message (data-integrity protection). `PlayerRemoving` adds the session's playtime to `Statistics.TimePlayed` and ends the session.
- `PlayerSetup` functions run once per join in their own thread and must not block profile availability: first-join nickname prompt (3 s delay, 15 characters, text-filtered, unchangeable afterwards), cosmetics and pet replication setup, and the one-time group pet grant (`FreeItemsRedeemed` guards repeats).
- `DataService:SaveAsync(player, isSaved?)` forces a save and resolves `true` only once a DataStore write that satisfies `isSaved` finishes (15 s timeout, never rejects). `ProcessReceipt` uses it before answering `PurchaseGranted`.
- `ProcessedReceipts` (`PurchaseId` to grant time, bounded to the newest 200) is the idempotency record for developer-product receipts. Do not rename or clear it.
- `Playtime.MostRecentJoin` / `FirstJoin` are written directly on `proxy.Data` and are saved but not replicated.
**Depends on:** ProfileStore, ReplicaService, DialogService, CosmeticsService, PetService.
**Consumers:** Nearly every server service; `DataController` on the client.

### Currency & Statistics
**Purpose:** Owns BobaBucks and Points balances and the lifetime counters shown in the Statistics page.
**Owner modules:**
- `server/Modules/CurrencyService.luau`
- `server/Modules/StatisticsService.luau`
**Key invariants:**
- Balances change only through `CurrencyService:Modify(player, "BobaBucks" | "Points", amount)`; amount must be non-zero and the currency must exist in `ProfileTemplate.Currency`.
- BobaBucks changes also increment `BobaBucksEarned` or `BobaBucksSpent`.
- `IncrementStat` ignores names not present in `ProfileTemplate.Statistics`; add the counter to the template first.
- `Modify` does not prevent a negative balance and does not yield for the caller (it queues on the profile). Anything that spends must use `CurrencyService:TrySpendAsync(player, currency, amount)`, which yields until data loads, then checks the balance and deducts in one non-yielding step, and returns `(true)` or `(false, reason)` (`InvalidCurrency`, `InvalidAmount`, `NoData`, `InsufficientFunds`). Amounts must be positive whole numbers. Nothing in `src/` calls `TrySpendAsync` yet; covered by `Tests/CurrencyService.spec.luau` (not run in Studio by this task).
- `SpillsCleaned`, `TreasureChestsFound`, and `CelebritiesMet` exist in the template and the Statistics page, but nothing in `src/` increments them yet. `ItemsOrdered`, `BobasOrdered`, `OrdersCreated`, `OrdersPrepared`, and the BobaBucks totals are wired.
**Depends on:** DataService.
**Consumers:** SpillService (Points), shop and promo-code rewards, Statistics UI. Future spend paths (`TrySpendAsync`).

### Inventory
**Purpose:** Typed, replicated item storage for Capsules, Pets, Nametags, and Particles.
**Owner modules:**
- `shared/Inventory/InventoryServer.luau`, `InventoryClient.luau`, `InventoryItem.luau`, `ItemActions.luau`, `ItemsMap.luau`, `CapsuleUtil.luau`
- `shared/Configuration/InventoryItemDefinitions/` (`Capsules`, `Pets`, `Nametags`, `Particles`, `Tiers`)
- `shared/Configuration/InventoryLimits.luau`
**Key invariants:**
- Items live in `Inventory.Items.<Type>` keyed by GUID with `Name`, optional `Tier`, `Equipped`, `StackCount`, and `Properties`. `Name` must exist in `InventoryItemDefinitions`; item definitions are the catalog and are product data.
- Mutations happen on the server (`Insert`, `RemoveItems`, equip, stack, property writes) and emit change events that other services (cosmetics, pets) listen to. The client only sends packets (`removeItems`, `setItemEquipped`, `useItem`, `renameItem`, `sellItem`) over `ReplicatedStorage.Networking.InventoryEvent`; the server type-checks each payload, resolves items inside that player's own inventory, and rejects unknown item types. Any new packet gets the same checks.
- `Inventory/init.luau` returns the server or client implementation by environment; shared code must not assume which.
- `Packets.luau` is an intentional no-op kept for compatibility.
**Depends on:** DataService (profile), Janitor, `InventoryEvent` remote.
**Consumers:** CapsuleService, PetService, CosmeticsService, Inventory/Shop UI, PromoCodes.

### Capsules & Pet Hatching
**Purpose:** Opens capsules and runs the timed pet hatch.
**Owner modules:**
- `server/Modules/CapsuleService.luau`
- `shared/Configuration/CapsuleConfig.luau`
- `shared/Inventory/CapsuleUtil.luau`
- `shared/UI/Components/Core/CapsuleOpening.luau`, `Dialogs/CapsuleOpening.luau`
**Key invariants:**
- Non-pet capsules resolve instantly; pet capsules hatch over `PET_HATCH_DURATION` seconds of **active play** (offline time does not count). One pending hatch per player (`HatchingPet`).
- The reward is rolled when the hatch completes, not when it starts, so pool changes during the wait apply. Rewards are inserted through the inventory API and announced with the `HatchCapsule` signal.
- Elapsed time for the current session is added to stored `TimeAccumulated` on removal; completion can happen on the next login or server check.
- The client's `TryCompleteReadyHatch` is a hint only; the server recomputes elapsed time.
- Capsule tiers, odds, and the hatch duration are product data (Jack approval to change).
- The skip-hatch developer product (see Purchases) sets progress to `PET_HATCH_DURATION - 5`, so the normal completion check finishes it. It is valid only while a hatch is pending (DEC-006); the HUD hatch button (`Core/Hud/BottomLeft.luau`) only prompts the purchase while one is, and the server enforces it again.
**Depends on:** DataService, Inventory, DialogService, `InventoryItemDefinitions`.
**Consumers:** Inventory UI, Shop UI, ProcessReceipt.

### Pets
**Purpose:** Publishes each player's equipped pets and renders followers.
**Owner modules:**
- `server/Modules/PetService.luau`
- `shared/Pets/PetShared.luau`, `shared/Configuration/PetConfig.luau`
- `client/Modules/PetController.luau`, `client/Modules/Pets/PetFollowerRenderer.luau`, `PetFollowerConfig.luau`
**Key invariants:**
- Equipped pets are derived from the inventory change signal; the server publishes, clients render. Follower movement is client-side presentation only.
- Renames are validated and text-filtered on the server (string type, length cap `MAX_RENAME_LENGTH`, unchanged after filtering) and stored as an item property; an empty name clears it.
- `PlayerRemoving` clears the player's equipped pets for all clients and disconnects listeners.
**Depends on:** Inventory, DataService.
**Consumers:** Pet UI, other players' clients.

### Cosmetics & Nametags
**Purpose:** Applies equipped nametags, nicknames, and particle effects to characters.
**Owner modules:**
- `server/Modules/CosmeticsService.luau`
- `client/Scripts/PlayerOverheads.client.luau`
- `shared/Configuration/InventoryItemDefinitions/Nametags.luau`, `Particles.luau`
**Key invariants:**
- Cosmetics state is derived from equipped inventory items and the saved nickname; the server caches it per player and broadcasts `CosmeticsChanged`. Clients fetch the cache with `GetAllPlayerCosmeticsAsync`.
- Particles are re-applied on every `CharacterAdded`; the connection is replaced on re-setup and removed on leave.
- A missing or unknown cosmetic definition must degrade to "nothing applied", not an error for the player.
**Depends on:** Inventory, DataService.
**Consumers:** Overhead nametags, other players' views.

### Ordering
**Purpose:** Runs the customer order lifecycle: any player orders for themselves, clocked-in baristas claim and prepare orders, customers collect them.
**Owner modules:**
- `server/Modules/OrderService.luau`
- `shared/Ordering/Menu.luau`
- `client/Modules/OrderController.luau`
- `shared/UI/Pages/Ordering/`, `shared/UI/Pages/MobileOrder/`, `shared/UI/Components/Core/Hud/OrderTicket.luau`, `OrderQueue.luau`
- `server/Tests/OrderService.spec.luau`
**Key invariants:**
- Orders are in-memory only (not saved) and carry `status` of `Pending Preparation`, `Being Prepared`, or `Ready for Pick Up`. `orderNum` is a rolling four-digit number.
- `Client:CreateOrder(customerId, orderItems)` is open to every player (no rank or clock-in check). `customerId` must equal the caller's UserId, there is a 5 s per-player debounce, a player may have only one open order, and an order has 1 to 4 items. Only the array part of `orderItems` is read. Every argument is untrusted.
- The client sends each item as `{ Category, Item, CustomInfo }` only. The server rebuilds it in `buildOrderItem` against `Shared.Ordering.Menu.FoodTable`: `Category` and `Item` must exist; `DefaultInfo` is always the server's Menu definition (never client data); `CustomInfo` must be a table whose keys are exactly the choices the item offers (each `Select` value is one of the listed strings, each `RequiredSelection` value is one of its keys, each `Options` value is a boolean, with the Menu default when absent). Unknown keys, wrong types, and missing required selections reject the whole order (`Invalid order.`, plus a server `warn`). A new item field that the client may choose needs a matching check there.
- The Menu module is required on the first order inside a `pcall`; if it fails, ordering replies `Ordering is unavailable right now.` and nothing else is affected.
- The `Ordering` and `MobileOrder` pages call it as `pcall(function() return OrderService:CreateOrder(userId, request):expect() end)` inside `task.spawn`, with an `isSubmitting` in-flight guard so a Promise that never settles cannot leave the UI stuck on a double-submit, and show the server's `Message`. New callers copy this shape.
- Claiming and the barista queue require the player to be clocked in (`ShiftService:IsClockedIn`, see Shifts) and not already preparing an order. Baristas who find no pending order join a FIFO queue; a new order is dispatched to the first queued barista still online and clocked in. Clocking out removes a player from the queue; an order already being prepared stays with them. Queue positions are pushed with `QueueUpdated`. Before `KnitStart` resolves `ShiftService`, nobody counts as clocked in.
- If the customer leaves, their order is removed. If the preparing barista leaves, the order returns to `Pending Preparation`. Pick-up areas owned by departed customers are cleared.
- Staff deposit prepared items as tools into a pick-up area (one depositor at a time per area); the customer collects them from there. Item and boba counts feed `ItemsOrdered`, `BobasOrdered`, and `OrdersPrepared`.
- The service depends on authored instances: `workspace["Ordering System"]` (`Status Screens`, `Staff Screens`, `Pick Up` nodes with `OrderOwner` and `ProximityPrompt`), waited for at most 10 s in `KnitStart` (after `ShiftService` is resolved and the clock-out hook is connected). If it is missing, a `warn` is logged and ordering screens and pick-up are disabled; each sub-folder is also optional and disables only its own feature. `ServerStorage.OrderPickUp` and `ReplicatedStorage.ModelStorage` are created in code when absent. `TopBar` resolves `Ordering System.Computers` (30 s wait, after the HUD mounts) to attach register prompts, which are available to every player.
- Studio evidence (M0.4 run 2, one player): rejection of malformed orders, a valid order, the one-open-order rule, claim, deposit, and customer pick-up all worked. Two baristas claiming, the queue, and one player collecting another's order are unverified.
- **OrderSpec and tool attributes.** `shared/Ordering/OrderSpec.luau` grades a finished tool against an order spec. Tool attributes: `Item`, `Size`, `Syrup`, `Tapioca`, `Iced`, `Sugar` (choices), and `Served` (set when a drink is picked up). `GiveTool` copies `Item` onto the tool; the other choice attributes are written by `SetToolAttributes` from the recipe. Stations also write `Lid`, which nothing reads. `OrderSpec.Match` grades `Perfect` (no mistake), `Close` (one minor mistake) or `Wrong` (two or more); a Grab item is always `Perfect`. Tool names are never read.
- **Auto-match deposit.** `OrderService:FindServeTools(player, specs)` is a plain synchronous call (no yield) that finds the held or backpack tools that satisfy the specs and skips tools already marked `Served`. The pick-up step sets `Served = true` on each tool it hands over, so a drink can never satisfy a second order.
- **Launch allowlist.** `Menu.IsLaunchItem` (`shared/Ordering/Menu.luau`, `LAUNCH_ITEMS` and the launch choice sets) is checked in `OrderService:CreateOrder` before any item is built. An item or choice not on the list is refused with `That item isn't available right now.` (no order is created, so no barista or customer is locked). If `IsLaunchItem` is missing, ordering is disabled (fail closed).
**Depends on:** ShiftService, StatisticsService, DialogService, Promise, authored Ordering System. `QuestService` is used if it exists.
**Consumers:** Ordering and mobile ordering UI, staff screens, Statistics, `OrderController` (pick-up beam; `SharedStorage.Effects.PickupBeam` is looked up on use and skipped with one `warn` when missing).

### Customers (NPCs)
**Purpose:** Spawns NPC customers who walk in, queue, and wait at a counter with a patience clock. A clocked-in barista is assigned each waiting customer and serves it at the counter prompt. Customers who run out of patience leave. Trash cans and the barista uniform are handled here too.
**Owner modules:**
- `server/Modules/CustomerService/init.luau`, `Npc.luau` (model, walk, bubble, Serve prompt), `Rules.luau` (pure pacing, patience, order and pay rules)
- `server/Modules/UniformService.luau`, `server/Modules/TrashService.luau`
- `shared/Configuration/CustomerConfig.luau`, `shared/Configuration/CustomerDialogue.luau`
- `client/Modules/KitchenController.luau` (Serve or Rescue prompt label and visibility), `client/Modules/OrderController.luau` (ticket listener)
- `server/Tests/CustomerService.spec.luau`

**Authored contract (`workspace.Assets.NPC`, RIG-1):**

| Path | Contents |
| --- | --- |
| `workspace.Assets.NPC.Entry` | BasePart. Where NPCs spawn. |
| `workspace.Assets.NPC.Exit` | BasePart. Where NPCs leave. |
| `workspace.Assets.NPC.Path` | Parts named `1`..`n`, walked in order from Entry. |
| `workspace.Assets.NPC.Queue` | Parts named `1`..`k`; `1` is the front of the line. |
| `workspace.Assets.NPC.Counter` | Parts named `1`..`m`; the NPC faces the Counter part's rotation (toward the kitchen). |

Part rules: Entry and Exit must be BaseParts; Path, Queue and Counter each need at least one numbered BasePart. RIG-1 parts are 2x1x2, Anchored, with `CanCollide`, `CanQuery` and `CanTouch` off and `Transparency` 1. Current positions (RIG-1, y -11.4): Entry (4.6, 323.9); Exit (9.6, 323.9); Path.1 (4.4, 320.3); Queue 1..6 (4.2, 316.7), (1.3, 315.9), (-1.6, 315.1), (-4.5, 314.3), (-7.4, 313.6), (-10.3, 312.8); Counter 1..5 are the five registers of `workspace["Ordering System"].CustomerAreas` nearest Entry, at (-8.8, 305.9), (-1.5, 307.9), (6.0, 309.9), (14.0, 312.0), (21.9, 314.2), LookVector (0.26, -0.97) toward the kitchen. These are a first placement; the Rigger may move the parts.

**Key invariants:**
- `KnitStart` resolves the five paths above with one shared 10 s budget. If any is missing, the service logs one `warn` naming it, `Enabled` stays false, and no folder, loop or NPC is created.
- A 1 s pacing loop spawns one NPC while the present count is below `Rules.PacingTarget(clockedInBaristas)` (1 barista: 2; 5: 7; 20 and 40: 16), the queue has room, and `SPAWN_GAP_SECONDS` (3) have passed. `SERVER_CAP` (16) limits NPCs present at once. All TUNING.
- The NPC walks Entry, then Path, then its queue spot. The front NPC takes the lowest free Counter spot. The patience clock (`PatienceEnd`, server time, on the model) starts at assignment, not at arrival, and pauses while no barista is clocked in. At zero the NPC leaves with reason `PatienceOut`: no BobaBucks are taken, the barista's combo resets, and Cafe Rating takes a walkout hit.
- Patience bar: Green above 50%; Yellow at or below `PATIENCE_YELLOW_FRACTION` (0.5); Red at or below `PATIENCE_RED_FRACTION` (0.25).
- Walking uses `Humanoid:MoveTo` per node. After 6 s a segment is finished with `PivotTo`. Three `PivotTo` fallbacks in a row despawn the NPC with a `warn`. Each NPC thread runs inside `pcall`.
- Collision groups are registered at runtime: `NPC` and `CafePlayers`. `NPC` collides with neither `CafePlayers` nor `NPC`, and still collides with the floor. Every player character's parts are moved into `CafePlayers`, including parts added later.
- Runtime folder: `workspace.Customers` holds the NPC models (`BuiltBy` `REVIVAL-001-M1.4core`).
- Serve prompt: each assigned NPC gets a `ProximityPrompt` named `ServePrompt` on its `HumanoidRootPart` (ActionText `Serve`, HoldDuration 0, MaxActivationDistance 8, model attribute `PromptAction = "Serve"`). The client shows `Rescue` locally for a clocked-in barista who is not assigned, once patience is at or below `RESCUE_FRACTION` (0.3). On `Triggered` the server checks, in order: clocked in (`ShiftService`); within 10 studs of the player's `PrimaryPart`; state `AtCounter`; `Rules.CanServe` (the assigned barista, or anyone on a Rescue); then `OrderService:FindServeTools`. The matched tool(s) are destroyed with no yield between pick and destroy.
- Tickets: a barista holds up to `SLOTS_PER_BARISTA` ticket slots (1; a second from level 5, see M2 Systems). `CustomerService.Client.TicketChanged` fires `(player, ticket, slot)` on assignment, serve, walkout and reassignment, and `(player, nil, slot)` to clear. The ticket table:

```
ticket = {
  Id = string,            -- npc.Model.Name (unique per NPC)
  NpcModel = Model,       -- the NPC model in workspace.Customers
  Label = string,         -- OrderSpec label, e.g. "Medium Custom Boba"
  Spec = { Category = string, Item = string, CustomInfo = {...}?, Size = string? },
  Items = { ... },        -- every item of the order; Spec is the first
  Variant = string?,      -- "Karen" or "VIP"; nil for a normal customer
  PatienceEnd = number,   -- server time (GetServerTimeNow)
  PatienceTotal = number, -- seconds
  Scripted = boolean,
  Rescue = false,         -- the server always sends false; the client flips the prompt label
  Slot = number,          -- added by the server on assignment
}
```

- Pay (`Rules.Payout`): `CustomerConfig.PAY_TABLE` by Category, times `GRADE_MULT` (Perfect 1.0, Close 0.5), `FAST_MULT` on a fast serve, a combo of `COMBO_STEP` per consecutive Perfect up to `COMBO_CAP`, and `RESCUE_MULT` on a rescue. Every economy value is PROPOSED (Jack) until the economy is approved:
  - `PAY_TABLE` (PROPOSED): Boba Teas 3, Coffees 2, Hot Cocoas 2, Teas 2, Pastries 1, Grab 1. The packet spellings (Coffee, Hot Cocoa, Tea) alias the same values.
  - `GRADE_MULT` Perfect 1.0, Close 0.5; `FAST_MULT` 1.5; `FAST_FRACTION` 0.5; `COMBO_STEP` 0.1; `COMBO_CAP` 0.5; `RESCUE_MULT` 1.5; `RESCUE_FRACTION` 0.3 (all PROPOSED).
- Order pool (`CustomerConfig.ORDER_POOL`, TUNING weights): Classic Milk Tea Boba 55, Regular coffee (hot, no sugar) 30, Fudge Brownie 15. Boba and coffee sizes: Small 30, Medium 40, Large 30 (TUNING). PENDING JACK Q3: whether boba keeps three sizes.
- Variants (`CustomerConfig`, PROPOSED): a Karen's look comes from `SharedStorage.NPCStorage.Karen`, and a Karen plays `Confused` on a wrong serve. Ordinary NPCs take a random `HumanoidDescription` from `SharedStorage.NPCs`.

**Authored paths used by this system (RIG-1 import, spelled as in the place):**
- `ReplicatedStorage.SharedStorage.CleanlinessStorage`: `Spills` (`Boba`, `MeltedPopsicle`, `Donut`), `Sparkles`, `Animations`, `Tools` (`Broom`, `MopBucket`, `Mop`, `DishTowel`, `SprayBottle`), `BoardInterface`.
- `ReplicatedStorage.SharedStorage.NPCStorage`: `Karen` (HumanoidDescription) and `Animations` (`Wave`, `Confused`, `BoothSit`, `ComfySit`, `CafeSit`, `CouchSit`, `Idle`). NPC-LOOK reports the imported `.rbxm` has no `Idle`, so the code skips `Idle` until one exists. RIG-1 lists it; this is open (see the RIG-1 and NPC-LOOK evidence).
- `ReplicatedStorage.SharedStorage.NPCs`: HumanoidDescriptions for ordinary NPCs. Read by the code; not in the RIG-1 import (NOT VERIFIED in the place).
- `ReplicatedStorage.SharedStorage.KitchenStorage.Assets`: `S_DefaultUniform` (Shirt), `P_DefaultUniform` (Pants).
- `workspace.Map.SpawnInterior1` to `SpawnInterior4`: transparent, non-colliding Neutral spawns (RIG-1). The four old `workspace.Map.SpawnLocation` parts are disabled and kept.

**UniformService (`server/Modules/UniformService.luau`):** On clock-in, a barista's Shirt and Pants templates are set to `S_DefaultUniform` and `P_DefaultUniform`; on clock-out the saved templates are restored. A missing uniform piece warns once and is skipped. Visuals are UNVERIFIED until M1.6.

**TrashService (`server/Modules/TrashService.luau`):** Finds the cans by the CollectionService tag `TrashCan`, and each can gets a prompt. A player holding a drink (tool) who uses a can gets a Yes/No dialog: Yes removes the tool (refused for tools with `NotDisposable`), No keeps it. The player must still be within 12 studs when Yes is pressed. With no tool held, a toast is shown. The six cans are Models named `Trash` (PrimaryPart unset) under `workspace.Assets.Kitchen.TrashCans`, tagged `TrashCan`, with pivots (RIG-1): (-33.9, 327.6), (-19.1, 282.2), (34.7, 345.7), (55.0, 287.3), (-8.2, 377.6), (65.1, 383.0), all at y -11.1.

**Depends on:** ShiftService, OrderService, CurrencyService, StatisticsService, DialogService, Progression (ticket slots), WorldPath, the authored NPC contract and NPC storage.
**Consumers:** Serve and Rescue prompts and tickets in `KitchenController` and `OrderController`; Cafe Rating (walkout and serve deltas); Statistics (`CustomersServed`).

### Kitchen
**Purpose:** Turns kitchen props into proximity-prompt interactions that run recipe action sequences.
**Owner modules:**
- `server/Modules/KitchenService/init.luau`, `InteractionRunner.luau`, `PromptBuilder.luau`, `ActionRegistry.luau`, `Actions/*`
- `shared/Kitchen/Recipes.luau`, `RecipeConstructors.luau`, `KitchenTypes.luau`
- `shared/Configuration/KitchenConfig.luau`
- `client/Modules/KitchenController.luau`
- `client/Modules/KitchenGuidance.luau` (pure logic, no Instances: recipe card `Steps`, Highlight target, beam and toast rules; spec `server/Tests/KitchenGuidance.spec.luau`; required by `KitchenController` and `AppDialogs`)
**Key invariants:**
- Every key in `Recipes.Items` is matched by name to models under `workspace.Assets.Kitchen`; each match gets a prompt. Syrup dispensers are cloned from `ReplicatedStorage.SelectorModels.Kitchen.SyrupDispenser` along `Kitchen.Syrups` parts. `workspace.Assets.Kitchen` is waited for at most 10 s in `KnitStart`; if it is missing the kitchen is disabled with a `warn`, and a missing `Syrups` folder or dispenser template disables only the dispensers. `RecipeConstructors` (required by `Recipes` at startup) waits at most 5 s for `ReplicatedStorage.SharedStorage` and then looks up `Tools.Kitchen` and `Animations.Kitchen` with `WorldPath.find`; a missing tool skips the recipe or branch that needs it, and a missing animation drops only that step, each with a `warn`.
- The prompt handler re-checks on the server: the player is clocked in (`ShiftService`; a clocked-out player's prompt fires and is silently ignored, with no toast), a primary part, a character, and `MAX_INTERACTION_DISTANCE`. Rank is not consulted.
- `KitchenController` applies the Instant Brew hold-time perk after a 30 s bounded wait for the kitchen; a missing kitchen disables only that perk.
- Studio evidence (M0.4 run 2): boot, the clock-in gate (clocked out: no dialog or tool; clocked in: the Cup size dialog opens), regular coffee, and Fudge Brownie worked. Boba recipes were not working at that run; the fix is tracked separately and is not described here.
- `InteractionRunner` debounces per player and runs the recipe's `Actions` in order; each action is a function module in `Actions/` looked up by name. An action that is not a function is skipped with a warning; failures report to the client via `InteractionFailed`.
- A new action is a new module in `Actions/` with the `ActionFn` signature from `KitchenTypes`, not a branch in the runner.
- Q14 attribute gates (`KitchenService/Actions/ToolAttributeCheck.luau`, used by `Recipes.luau`) check a held tool's attributes before a Sugar or Ice step. TUNING (Q14): the Coffee Machine holds 4 s (was 7 s); the Ice Machine holds 3 s (was 5 s) and requires a coffee item that is not iced yet (`Iced = false`).
- `KitchenGuidance` shows the hints: the recipe card rows (`Steps`), which station to highlight, the beam for the first few customers of a session, and the toasts. The Serve step highlights the NPC (`ticket.NpcModel`), not a station.
- Recipe, drink, syrup, and menu names are shared with Ordering; keep `Recipes` and `Menu` consistent.
**Depends on:** ShiftService, WorldPath, authored Kitchen models, tools, and SFX.
**Consumers:** Ordering, Recipes UI, `SetItemEnabled` callers.

### Spills & Cleanliness
**Purpose:** Spawns spills, lets players clean them for Points, and tracks a global cleanliness meter.
**Owner modules:**
- `server/Modules/SpillService/init.luau`, `Spill.luau`
- `shared/Configuration/Spills.luau`
- `client/Modules/SpillController.lua`
**Key invariants:**
- Spill regions come from `workspace.Assets.Spills.Areas`, with templates from `ReplicatedStorage.SharedStorage.CleanlinessStorage` (its `Spills` folder); counts are capped by `MaxTotal` and `MaxSpawned`, with overflow queued, and a new spill is attempted every `SpawnInterval` seconds (30, tuning value). All of that content shares one 10 s budget in `KnitStart` (`WorldPath.waitFor` with a common deadline); if any path is missing, spills are disabled with one `warn` listing the missing paths, and the service also disables itself after repeated spawn failures. `SpillController` does the same on the client for its folders and storage. Studio run M0.4 run 2 showed `Spills disabled (4 authored paths missing)` in the current place, so spills are not exercised there.
- Only clocked-in players can clean (`Spill.luau` checks `ShiftService` in the prompt handler).
- Cleaning awards `PointIncrement` Points through `CurrencyService:Modify` and raises the global `CleanlinessReplica` (`Percent`, replicated to all) by 1 to 2.
- Trip zones use `Zone`; tripping fires the `Trip` signal to that player only.
- Each spill owns a Janitor; `Clean` and `Destroy` must release the player's locked movement and animation.
- Cleanliness saturates at 100. The earlier `GlobalMulti` / `BoostMultiplier` path is gone; the reward for reaching 100% (a Cafe Rating boost) is not implemented. Do not invent reward values; they are Jack-approved economy data.
**Depends on:** CurrencyService, ShiftService, Zone, Janitor, ReplicaService, WorldPath, authored Spills assets.
**Consumers:** HUD cleanliness meter.

### Shifts & Teams
**Purpose:** Decides who works as a barista. A clocked-in player is a barista (kitchen stations, claiming and queueing for orders, cleaning spills); a clocked-out player is a customer. Replaces group-rank gating of gameplay (DEC-002: ranks are titles, moderation, and event hosting only).
**Owner modules:**
- `server/Modules/ShiftService.luau`
- `server/Scripts/Teams.server.luau`, `shared/Configuration/TeamsConfig.luau`
- `shared/UI/Components/Core/Hud/BottomLeft.luau` (Clock In / Clock Out button)
- `server/Tests/ShiftService.spec.luau`
**Key invariants:**
- The state is the `ClockedIn` attribute on the `Player`, set only by the server. Every player starts clocked in (`DEFAULT_CLOCKED_IN`) unless the attribute is already set. `IsClockedIn(player)` is true only when the attribute is exactly `true`.
- Anyone may clock in or out at any time. `Client:SetClockedIn(boolean)` type-checks its argument, has a 2 s per-player cooldown cleared in `PlayerRemoving`, and replies `{ Success, Message }`. The server-side `SetClockedIn(player, value)` skips the cooldown and fires the `ClockedInChanged(player, clockedIn)` GoodSignal only on a change.
- Consumers read it server-side only: `KitchenService` (station prompts), `OrderService` (claim, queue, dispatch; it also leaves the queue on clock-out), and `Spill.luau` (cleaning). Each resolves `ShiftService` in `KnitStart` or at call time; none cache the answer. The client HUD (`BottomLeft`) mirrors the attribute and calls `ShiftService:SetClockedIn`; the HUD is presentation, and the server re-checks.
- `Teams.server.luau` creates `Baristas` (clocked in, `AutoAssignable`) and `Customers` from `TeamsConfig` and moves each player when `ClockedIn` changes. It no longer reads rank.
- Studio evidence (M0.4 run 2, one player): the HUD button toggles the attribute and team, and the kitchen gate follows it. Per-player state with two players is unverified.
**Depends on:** Knit, GoodSignal.
**Consumers:** KitchenService, OrderService, SpillService, Teams, HUD.

### Ranks & Gamepasses
**Purpose:** Group rank is informational; gamepass ownership gates perks.
**Owner modules:**
- `shared/Utility/RankUtil.luau`, `shared/Utility/GamepassUtil.luau`
- `shared/Configuration/GamepassConfig.luau`, `Gamepasses.luau`
**Key invariants:**
- `RankUtil` caches group rank (and role) per player, pre-fetches on join, de-duplicates concurrent fetches, expires entries, and falls back to rank 1 (Customer) when the lookup fails. In Studio it returns a simulated rank. Its checks (`CanUseOrderingSystem` 7, `CanEnterKitchen` 8, `IsMR` 11, `IsHR` 16, `IsSHR` 19) remain as helpers but must not gate ordering, the kitchen, claiming, or any other gameplay (DEC-002).
- Remaining rank reads are not gameplay gates: the `FirstStaff` badge (`BadgeService`), `MinRank` on a setting (`SettingsService`, server-enforced; `SyrupHighlighting` and `ShiftTimerEnabled` use it), the admin-only shift timer in the HUD, and display of role and rank in the Ordering page and HUD (presentation).
- `RankClaiming.server.luau`, the `ClaimRank` remote, `RankingService`, and the "Claim Barista / Kitchen Leader" settings were removed; rank-granting passes no longer exist. DEC-002 says legacy passes will be remapped to perks; that remapping is not implemented in this code.
- `GamepassUtil` caches `UserOwnsGamePassAsync` results the same way; always resolve passes through it or `GamepassConfig`.
**Depends on:** Roblox Groups and Marketplace, Promise.
**Consumers:** BadgeService, SettingsService, Ordering and HUD display, KitchenController (Instant Brew).

### Purchases
**Purpose:** Fulfils Robux purchases and presents the shop.
**Owner modules:**
- `server/Scripts/ProcessReceipt.server.luau`
- `shared/Configuration/Gamepasses.luau`, `GamepassConfig.luau`
- `shared/UI/Pages/Shop/*`, `shared/UI/Pages/Menu/Purchases.luau`
- `ReplicatedStorage.Networking.GetPurchases` (RemoteFunction created by this script when absent)
**Key invariants:**
- `MarketplaceService.ProcessReceipt` is assigned before anything that can yield and answers `NotProcessedYet` until Knit has started. `ProductActionMap` maps `ProductId` to `{ name, callback }`; the callback receives the player's profile data and must return `true` only once the grant has been applied. A callback that errors or returns anything else grants nothing and yields `NotProcessedYet`.
- Idempotent on `PurchaseId`: the id is recorded in the profile's `ProcessedReceipts` (newest 200 kept) right after the grant, and a receipt whose id is already recorded is never granted again. Concurrent calls for one id are rejected by an in-flight guard. `PurchaseGranted` is returned only after `DataService:SaveAsync` confirms the record reached the DataStore; if the save is not confirmed the answer is `NotProcessedYet` and the retry takes the "already granted" path. If the id cannot be recorded after a grant, it answers `PurchaseGranted` rather than risk a double grant.
- An offline player or profile data that does not load within 30 s yields `NotProcessedYet`. A `ProductId` with no entry in `ProductActionMap` logs a warning and yields `NotProcessedYet`, so payment is never consumed for something undelivered. Today only the skip-hatch product is mapped.
- Skip Hatch (DEC-006): with no hatch pending the action grants nothing, stores no credit, and the receipt stays unconsumed (`NotProcessedYet`, not recorded). The HUD also refuses to prompt it without a pending hatch.
- `ProductPurchaseDatastore_0001` history is informational only and written after the decision; it never decides whether a purchase was granted. `GetPurchases` returns it with a per-player cooldown; clients cannot write it.
- Product IDs, prices, gamepass IDs, and the shop catalog are Jack-approved economy data. A new product also needs the matching product on Roblox and an entry in `ProductActionMap`.
- UI only prompts and reflects ownership; it never decides entitlement.
- The receipt logic is read from source and has no runtime evidence yet (M0.4 did not exercise it); treat it as unverified until a Studio purchase test is recorded.
**Depends on:** MarketplaceService, DataService, CapsuleService (skip hatch).
**Consumers:** Shop, Passes, hatch skipping.

### Promo Codes
**Purpose:** Redeems codes for currency or items.
**Owner modules:**
- `server/Scripts/PromoCodes.server.luau`
- `server/Configuration/PromoCodes.luau` (server only)
- `shared/UI/Pages/Menu/PromoCodes.luau`
**Key invariants:**
- Codes are normalized (uppercase, no whitespace) and checked only on the server, so clients cannot enumerate them. The config file must stay out of `src/shared/`.
- The `RedeemCode` RemoteFunction under `ReplicatedStorage.Networking` is created by the script when absent (the `Networking` folder too), not authored in the place.
- Per-player redemption is recorded in `RedeemedCodes`; optional global `MaxClaims` is enforced with an atomic `UpdateAsync` counter in `PromoCodeClaimCounts_0001`; `ExpiresAt` is a UTC timestamp.
- Redemption is rate-limited per player and replies `{ Success, Message }`.
- Reward values and code lists are Jack-approved economy data.
**Depends on:** DataService, CurrencyService, Inventory, DataStoreService.
**Consumers:** Menu promo UI.

### Badges
**Purpose:** Awards Roblox badges for milestones.
**Owner modules:** `server/Modules/BadgeService.luau`
**Key invariants:**
- Badge IDs live in `Service.Badges`; clients may trigger only badges listed in `ClientAwardableBadges`.
- Awards, ownership checks, and badge info are cached per player and cleared on leave; failures warn and never block play.
- Join-time awards are skipped in Studio.
- The special "met the owner/co-owner/developer" badges use hard-coded user ID lists in this file; changing those lists is a staffing decision for Jack.
**Depends on:** BadgeService (Roblox), RankUtil (only for the `FirstStaff` badge).
**Consumers:** Join flow, Slipped (client-awardable).

### Settings
**Purpose:** Stores per-player toggles and exposes them to the Settings page.
**Owner modules:**
- `server/Modules/SettingsService.luau`
- `shared/Configuration/SettingsConfig.luau`
- `shared/UI/Pages/Menu/Settings.luau`
**Key invariants:**
- Only boolean values for known toggle keys are accepted; action-type entries have no stored state. Settings with `MinRank` are enforced on the server, and `GamepassId` settings are only shown to owners (presentation). The claim-rank action settings were removed.
- The Music and SFX toggles set the volume of `SoundService.Music` / `SoundService.SFX` only if they exist and are `SoundGroup`s; otherwise the toggle is skipped with one `warn` per name. M0.4 run 2 logged that warning in the current place.
- Settings are saved under `Settings` in the profile and must exist in `ProfileTemplate.Settings`.
**Depends on:** DataService, RankUtil.
**Consumers:** Settings UI, audio and character-behavior controllers that read the values.

### Dialogs & Notifications
**Purpose:** Lets the server ask a player a question or show a toast, and wait for the answer.
**Owner modules:**
- `server/Modules/DialogService.luau`
- `client/Modules/AppDialogs.luau`
- `shared/UI/Components/Dialogs/*`, `shared/UI/Components/Core/Hud/SmallNotification.luau`
**Key invariants:**
- `CreateDialog(player, dialogType, props, timeout?)` returns a Promise; `dialogType` must name a component in `Components/Dialogs/` or the call rejects. Pending dialogs are tracked by GUID and dropped on `PlayerRemoving`.
- Answers come back as `{ id, value }` and must be treated as untrusted input: type-check and range-check before use.
- `Notify` shows a toast and never blocks. Its props are `{ Title, Description }`. Dialog sounds are looked up with `WorldPath.find` (`SoundService.SFX.UI`, then `UISounds`) and skipped when absent.
**Depends on:** HttpService, Promise, React UI.
**Consumers:** PlayerSetup, OrderService, KitchenService, CapsuleService, PromoCodes.

### UI Shell
**Purpose:** Hosts the React app and its pages, HUD, and shared components.
**Owner modules:**
- `client/Modules/App/AppEntry.luau`
- `shared/UI/App.luau`, `Styles.luau`
- `shared/UI/Components/` (`Pane`, `Core/Page`, `Core/Hud/*`, `Buttons/*`, `Dialogs/*`, `Decoration/*`)
- `shared/UI/Pages/` (`Inventory`, `Menu`, `MobileOrder`, `Ordering`, `Recipes`, `Shop`)
- `shared/UI/Hooks/`, `shared/UI/Utility/`, `shared/UI/Stories/`
**Key invariants:**
- HUD pieces that depend on authored content (`TopBar` register prompts) resolve it after mounting with a bounded wait and never at require time, so a missing folder cannot block the HUD.
- One `ScreenGui` (`ResetOnSpawn = false`) is created by `AppEntry` and the React root is rendered inside a protected call; a render failure warns and must not stop the rest of the client.
- `App` shows one page at a time through `Page`, closing the previous page before opening the next.
- UI reads replicated data and calls services; it does not write saved data or decide authorization.
- Visuals come from `Styles.luau` (see `STYLE.md`).
**Depends on:** React, ReactRoblox, ReactSpring, controllers.
**Consumers:** Every player-facing screen.

### M2 Systems (progression, rating, real orders, areas)
**Purpose:** The M2 layer on top of the M1 cafe: XP and levels, a shared Cafe Rating with Rush Hour, real-player orders and ratings, shift summaries, break-area gates, and measurement events. Every value marked PROPOSED is a placeholder until Jack approves the economy. Studio checks for each system are listed in its task evidence and are UNVERIFIED until run.

| Service | What it does | Key signals, attributes and paths | Config (`shared/Configuration/`) |
| --- | --- | --- | --- |
| `ShiftService` (M2-SHIFT) | Counts a shift's served customers, walkouts, perfects and pay; awards stars; ends the shift with a summary and a HUD card. `_endShift` also fires `Client.Paycheck` with the receipt-only paycheck (`Pay`, `Tips`, `Bonus`, `Total`, `StreakBonus`, `Stars`, `Served`, `Walkouts`, `Shift`, `First`; the money itself moved at serve time for base/tips and in `_endShift` for bonus). | `ShiftEnding` (server signal; the summary may include `Xp`, `LevelBefore`, `LevelAfter`), `Client.ShiftEnded`, `Client.Paycheck`; `ClockedIn` attribute (see Shifts & Teams); `Hud/ShiftCard.luau`, HUD `PaycheckCard` (PAYCHECK-WIRE: the popup is the check itself — ported check art with overlay fields, CloseButton on its top-right corner, 8 s auto-dismiss, queued, silent; breakdown stays on `ShiftCard`) | `ShiftConfig.luau`: `SHIFT_XP` 10, `SHIFT_XP_PER_STAR` 5, `SHIFT_BONUS_PER_STAR` 0 (PROPOSED) |
| `ProgressionService` (M2-PROGRESS) | XP and levels 1 to 50. Serving earns XP; each level-up shows a toast naming what opened (title, ticket slots, items per order, VIP/Karen, nametag; read from shared config) and fires `Client.LeveledUp` with `{ Level, Title, Unlocks }` for the non-modal HUD `LevelUpCelebration` card (centered Page pop, GREEN header with a GOLD `Banner`, unlock rows, GREEN dismiss, 8 s auto-dismiss, queued across multi-level grants; the toast stays as the tier-1 fallback). The level-up sting is `SoundService.SFX.UI.SuperSuccess`, else `SoundService.UISounds.SuperSuccess`, via `UiSfx` (falls back to `LevelUp`, `Success`; a missing sound warns once and is skipped); the ShiftEnding listener adds `XpIntoLevel`, `XpForLevel` and `NextUnlock` to the shift summary; every 5 levels grants a nametag from the first ten `Nametags` entries. Never blocks serving. | Player attributes `Level`, `LevelTitle` and `EquippedTitle`; profile `Level` and `XP` (`ProfileTemplate`); `Progression.SlotsFor(level)` sets ticket slots (1, or 2 from level 5). Titles are an earned cosmetic (`shared/Configuration/Titles.luau`, level titles derived from `Progression.TITLES`): profile `Titles = { Owned, Equipped }` is written only by this service, level titles are granted on join and level-up, manual/event titles only through the server-only `GrantTitle(player, titleId)` (add the title to `Titles.MANUAL_TITLES` first with optional `UnearnedDisplay = "Hidden" | "Secret"`; deliberately not a `Client` method), and players equip/unequip owned titles through `Client:EquipTitle` from the Inventory Titles tab (split into Level Titles and Event Titles sections). `PlayerOverheads` shows `EquippedTitle` first (empty string clears title), then `LevelTitle`. The Menu Staff tab shows level, XP progress, equipped title, ticket slots, orders served, shifts completed, recipes unlocked, titles earned, and next title. Profiles without a `Titles` field are filled in on join (no `ProfileTemplate` change yet; that add-only field is serialized after the Q6-CHAINS lease on that file) | `Progression.luau`: `XP_PER_ITEM` 10, `XP_PERFECT` 5, `XP_FAST` 5, `MAX_LEVEL` 50, level thresholds, title names (PROPOSED) |
| `RealOrderService` (M2-REALORDER, M2-HEARTS) | Real-player orders. The customer gets a "Real customer!" bubble; the barista gets double pay (x2) for the first 3 orders from the same customer within 10 minutes. After pick-up the customer rates the barista 1 to 5 (once per order; 60 s timeout). | Bubble `RealCustomerBubble`; `Statistics.HeartsReceived` (plus hearts to the barista) and `Statistics.HeartsCount` (plus 1); `Statistics.RegularOrders` (customer); `Served` attribute on the kept drink. Rating buttons are plain "1" to "5" (question for Jack) | `RealOrderConfig.luau`: `PAY_MULT` 2, `BONUS_ORDER_COUNT` 3, `WINDOW_SECONDS` 600 (PROPOSED) |
| `CafeRatingService` (M2-RATING) | Server-wide Cafe Rating (0 to 100) and Rush Hour. Perfect, fast, walkout, cleaned-spill and drain deltas move the rating, divided by the number of clocked-in baristas. A Rush raises NPC pay. | Workspace attributes `CafeRating` and `RushHour`; `SpillService` `SpillCleanedSignal`; `Hud/CafeRating.luau` (meter frozen during Rush) | `RatingConfig.luau`: `START` 50, `PERFECT` +4, `CLOSE` +1, `FAST` +1, `WALKOUT` -2, `SPILL_CLEANED` +3, `SPILL_DRAIN` -0.5 per 5 s while spills exist, `SPILL_XP` 5, `RUSH_SECONDS` 120 (all PROPOSED) |
| `TrashService` | Trash can prompts (see Customers). | Tag `TrashCan`; `workspace.Assets.Kitchen.TrashCans.Trash` (x6) | none |
| `UniformService` | Barista uniform on clock-in (see Customers). | `SharedStorage.KitchenStorage.Assets.S_DefaultUniform` / `P_DefaultUniform` | none |
| `AnalyticsEvents` (M1.MEASURE) | Thin wrapper over AnalyticsService: first-session funnel steps, BobaBucks economy events, custom events. Warns once, never errors or yields the caller. | Methods `Funnel`, `Economy`, `Custom` | none |
| `AreaController` (client, M2-AREAS) | Break-area gates: below Level 3 a clone of each gate is placed in `workspace.AreaLimitsLocal`; at Level 3 that folder is destroyed. Re-runs when the `Level` attribute changes. | Waits 10 s for `ReplicatedStorage.AreaLimits.BreakGates` (the parked `Gate_Template` is never cloned); desert walls are authored at `workspace.Assets.AreaLimits.DesertWalls` and are not referenced by code. No server check | `OPEN_LEVEL` = 3 in `client/Modules/AreaController.luau` (Q20) |

### M3/M4 Systems (retention, perks, events)
**Purpose:** The M3 perk and Team Combo layer and the M4 retention loops, documented in the sections below. Reward and price values are Jack-approved economy data (DEC-036, DEC-037); do not retune them without Jack. Studio checks are UNVERIFIED unless a task's evidence says otherwise.

### Cafe Rating & Boba Party
**Purpose:** Server-wide Cafe Rating (0 to 100), Rush Hour, and the Boba Party (a purchasable 10-minute server-wide Rush Hour).
**Owner modules:**
- `server/Modules/CafeRatingService.luau`, `shared/Configuration/RatingConfig.luau`
- `server/Scripts/ProcessReceipt.server.luau`, `shared/UI/Components/Core/Hud/CafeRating.luau`
- `server/Tests/CafeRating.spec.luau`
**Key invariants:**
- The server publishes the workspace attributes `CafeRating`, `RushHour` and `BobaParty`; `CustomerService:IsRushHour()` reads `RushHour`. `Apply` is `clamp(rating + delta / max(1, clocked-in baristas), 0, 100)`. The meter is frozen (`_change` returns early) while any Rush is active.
- A natural Rush starts when the rating reaches 100, unless a Boba Party is active, the party cooldown is running, or `MIN_GAP_SECONDS` have not passed since the last Rush. It ends after `RUSH_SECONDS` (120) and resets the rating to `AFTER_RUSH`; its end timer does nothing while a party is active.
- `StartOrExtendBobaParty(buyer)` starts a party (`BOBA_PARTY_SECONDS` 600; sets `RushHour` and `BobaParty`) or, when one is active, adds `BOBA_PARTY_EXTENSION_SECONDS` (600). On end it sets `BobaPartyCooldownEndsAt` (server time, `BOBA_PARTY_COOLDOWN` 600) so the purchase prompt can hide itself. A receipt that arrives during the cooldown is still granted (Jack, 2026-10-19). Every player is notified through `DialogService`.
- The purchase is wired in `ProductActionMap` only when `BOBA_PARTY_PRODUCT_ID` is set. It is `nil` in code (Creator Hub product pending Jack, DEC-029 E18), so the party cannot be bought yet.
**Depends on:** ShiftService, CustomerService (`CustomerResolved`), SpillService, ProgressionService, DialogService.
**Consumers:** CustomerService (pay x2 and pacing), HUD meter, ProcessReceipt.

### Group Benefit (Ant Pet)
**Purpose:** One free "Ant Pet" for members of group 3174578, claimed from the Shop "Group Benefit" tab.
**Owner modules:** `server/Modules/GroupBenefitService.luau`, `shared/UI/Pages/Shop/GroupBenefit.luau`
**Key invariants:**
- `GetClaimStatusAsync` returns `Retry`, `Claimed` or `Available`. `ClaimAntPetAsync` returns `Retry`, `Claimed` or `NotMember`. Membership is checked on the server with `IsInGroupAsync`. One claim per player at a time (`claimsInProgress`, cleared in `PlayerRemoving`).
- The claim is a three-step durable sequence using `DataService:SaveAsync` predicates: save a `GroupPetPending:<guid>` marker in `Inventory.FreeItemsRedeemed`; insert the pet tagged with that claim id (`GroupPetClaimId`) and save; replace the pending marker with `GroupPet` and save. A failed final save rolls back only its own change, so a retry resumes from the pending marker and never grants a second pet.
- Each write composes `FreeItemsRedeemed` against the live list immediately before a synchronous write, because other services (for example `StarterCapsule`) write the same list across yields.
**Depends on:** DataService, Inventory, HttpService.
**Consumers:** Shop UI.

### BobaBucks Refund (PendingBobaBucksRefund)
**Purpose:** Durable compensation when a paid capsule purchase fails after BobaBucks were deducted (DEC-031).
**Owner modules:** `server/Modules/CapsuleService.luau` (`refundBobaBucks`, `retryPendingBobaBucksRefund`, `settlePendingBobaBucksRefund`), `shared/Configuration/ProfileTemplate.luau` (`PendingBobaBucksRefund`)
**Key invariants:**
- The owed amount is recorded in `PendingBobaBucksRefund` first. Settling saves that obligation, then in one `SetValues` adds it to `Currency.BobaBucks`, subtracts it from `Statistics.BobaBucksSpent` (floored at 0) and zeroes the field, then confirms that save. A failed step returns false and leaves the obligation recorded.
- Paid purchases call `retryPendingBobaBucksRefund` first inside the per-player transaction and fail with `RefundPending` until it settles; `PlayerAdded` retries it on join.
- It writes the balance directly, not through `CurrencyService:Modify`, so it adds no leaderboard or analytics event.
**Depends on:** DataService.
**Consumers:** CapsuleService purchase paths.

### Daily Rewards
**Purpose:** A 7-day login streak reward claimed from the Daily button.
**Owner modules:**
- `server/Modules/DailyRewardService.luau`, `shared/Configuration/DailyRewardConfig.luau`
- `client/Modules/DailyRewardController.luau`, `shared/UI/Components/Dialogs/DailyRewardsDialog.luau`
- `server/Tests/DailyRewardService.spec.luau`
**Key invariants:**
- Rewards are `DailyRewardConfig.REWARDS` (DEC-036): 30, 45, 60, 60 + Regular Pet Capsule, 90, 120, 180 + Rare Pet Capsule. Claim cooldown 20 h; a gap over 48 h restarts at day 1. The VIP gamepass (12385781) doubles the BobaBucks, not the capsule.
- Server-authoritative. `Client.ClaimReward` has a 2 s per-player rate limit and `ClaimReward` a per-player in-progress lock. State is `DailyRewards.Streak` and `LastClaimTime` in the profile.
- On a capsule day the capsule is granted first. If there is no space (`HasCapsuleSpace`) or the grant fails, nothing changes and the streak is not consumed. BobaBucks are paid with reason `DailyReward`.
- UI (DEC-041, approved in DEC-045): a one-tab `OpenableMenu` (seven `ShopItem` rows, a `PromptButton` Claim, red X to close) with no modal backdrop, opened by the Daily button through the dialog host.
**Depends on:** DataService, CapsuleService, CurrencyService, GamepassUtil.
**Consumers:** HUD Daily button.

### Quests
**Purpose:** Daily quests with claim and reroll, shown in a pop-up card.
**Owner modules:**
- `server/Modules/QuestService.luau`, `shared/Configuration/QuestConfig.luau`
- `shared/UI/Components/Core/Hud/QuestCard.luau`, `Hud/BottomRight.luau`, `Hud/init.luau`
- `server/Tests/QuestService.spec.luau`
**Key invariants:**
- Profile `Quests` holds `AssignedDay`, `ActiveQuests` and `FreeRerollsRemaining`. `_ensureDailyQuests` regenerates the set when the day changes: 3 slots (`BASE_SLOTS`), +1 for the More Quests or Star Employee pass, and 1 free reroll for Star Employee. Types are `BobaOrdered`, `CustomersServed`, `SpillsCleaned`, `RegularOrders`, `ShiftsCompleted`; rewards by rolled target are in `QuestConfig` (DEC-036).
- `AdvanceQuest(player, type, amount)` (alias `Progress`) caps progress at the target and sets `Completed`. Claim needs `Completed` and not `Claimed`; it sets `Claimed` before paying BobaBucks (reason `QuestReward`) and XP. Reroll is refused for a completed or claimed quest and costs the free reroll or 20 BB (`REROLL_COST_BOBABUCKS`, DEC-037) through `TrySpendAsync`. It re-checks the quest after that yield, and a charged reroll that lost the race is refunded with reason `QuestRerollRefund`. One claim or reroll per player at a time (`questLocks`); indexes are validated.
- UI (DEC-047, DEC-048, DEC-049): the QuestCard is a centred pop-up, closed by default, mounted only while open, closed by its X or by tapping Quests again. The Quests button is a text-only green `NormalButton` in the `BottomRight` mount, shifted left to clear the mobile jump zone (DEC-049: right edge at or left of 0.75 width in the 844 x 390 frame). There is no always-on HUD quest card and no Quests menu page (DEC-045 B). Jack still confirms the placement in the device emulator.
**Depends on:** DataService, CurrencyService, ProgressionService, GamepassUtil.
**Consumers:** CustomerService, RealOrderService, the Quests button.

### Treasure Hunt
**Purpose:** Shared hidden chests that pay BobaBucks and sometimes a capsule.
**Owner modules:** `server/Modules/TreasureHuntService.luau`, `shared/Configuration/TreasureHuntConfig.luau`, `server/Tests/TreasureHuntService.spec.luau`
**Key invariants:**
- Nodes come from `workspace.OldScriptables.ChestNodesFolder`, else `workspace.Assets.Chests` (bounded waits). If neither exists it warns and spawning is disabled. Chests are code-built Parts tagged `BuiltBy`. Up to `MAX_ACTIVE_CHESTS` (5) sit on unoccupied nodes; a claimed chest respawns after 90 s.
- `ClaimChest` checks distance (prompt range + 5 studs). After the data yield it re-checks the claimed flag and the per-player cooldown (`PLAYER_COOLDOWN_SECONDS` 15 min, `LastTreasureChestTime`), then writes the timestamp and the claimed flag back to back, so two triggers cannot both pass. Only the cooldown toast is throttled.
- Reward: 20 to 40 BB (reason `TreasureChest`) and a 10% chance of a Regular Pet or Nametag capsule; the BB are kept if the capsule cannot be given. It awards the `TreasureChest` badge and counts `TreasureChestsFound`.
- The `TreasureFrenzy` workspace attribute raises the cap to 8 and the respawn to 15 s; it never shortens the per-player cooldown (DEC-035 Q2).
**Depends on:** DataService, CurrencyService, CapsuleService, BadgeService, StatisticsService, DialogService.
**Consumers:** EventService (Treasure Frenzy).

### Cafe Upgrades (BIG-B2)
**Purpose:** BobaBucks sink and server pride: players buy server-wide cafe upgrades (Potted Plants, Fairy Lights, Tip Jar, Jukebox) at a board whose plaque names the buyers.
**Owner modules:** `server/Modules/CafeUpgradeService/` (`init`, `Builders`), `shared/Configuration/CafeUpgradeConfig.luau`, `server/Tests/CafeUpgradeService.spec.luau`
**Key invariants:**
- Per-server state, never saved (DEC-058 Opus-set): a new server starts bare. Prices, levels and the tip-jar chance live in `CafeUpgradeConfig`.
- No authored content. `KnitStart` builds `workspace.CafeUpgrades` (BuiltBy `Opus-B2`) with the board and each bought level's models, placed from `CafeUpgradeConfig.ORIGIN` * `PLACEMENT` (rough; Jack adjusts).
- Purchase: board prompt, then server-driven `ActionPrompt` (one button per upgrade) and `ButtonPrompt` confirm. `TryPurchaseAsync` spends through `CurrencyService:TrySpendAsync`; a per-upgrade pending lock and the expected-level check stop two buyers paying for one level. A distance check runs before the spend.
- Tip Jar: the level is the workspace attribute `CafeTipJarLevel`. The NPC serve path (`CustomerService:_onServeTriggered`) rolls `CafeUpgradeConfig.TipJarExtra` synchronously (no yield) and adds the extra to `Tip` and pay.
**Depends on:** CurrencyService, DialogService, AnalyticsEvents.
**Consumers:** CustomerService (tip jar).

### Leaderboards
**Purpose:** Five monthly OrderedDataStore boards, in-world SurfaceGuis and top-player statues.
**Owner modules:** `server/Modules/LeaderboardService.luau`, `shared/Configuration/LeaderboardConfig.luau`, `server/Modules/CurrencyService.luau` (`LEADERBOARD_EXCLUDED_REASONS`), `server/Tests/LeaderboardService.spec.luau`
**Key invariants:**
- Keys are `YYYY_MM_<board>` (`GetMonthKey`), so boards reset monthly. `MostTips` and `TopDonators` are `Hidden`: `IncrementStat` ignores them, they are never queried, their SurfaceGui is disabled, and they feed no statue (DEC-035 Q4, DEC-037 Q13). Statue 1 shows Most Orders Served and statue 2 shows Most Boba Bucks. The in-world boards and statues are authored in the place at `workspace.OldScriptables.LeaderboardsFolder` (`Monthly`, `Statues`); if the folder is missing the board refresh is disabled but batching still runs.
- `IncrementStat` only adds to an in-memory batch (positive numeric deltas, real users). One `UpdateAsync` per (user, board) is written every `REFRESH_INTERVAL_SECONDS` (120), on `PlayerRemoving` (that user only) and in `BindToClose` (waits up to 25 s for in-flight writes). `MostActive` adds 1 per player per minute.
- A failed write re-queues its delta into the pending batch (`_settleFlush`) and retries on the next flush, up to `FLUSH_MAX_ATTEMPTS` (3) total attempts. After that it is dropped with a warn, and it is dropped at once once shutdown has begun (`_closing`). A delta is in exactly one place at a time, so a re-queue does not double-count. Known residual: if `UpdateAsync` errors after Roblox already committed the write, a retry can add the delta twice (accepted, rare).
- `CurrencyService:Modify` adds positive BobaBucks to `MostBobaBucks` unless the reason is in `LEADERBOARD_EXCLUDED_REASONS`: `QuestRerollRefund`, `PromoCode`, `ItemSell` (DEC-035 Q4, DEC-038 Q14). The call is `pcall`-guarded, so a leaderboard failure never blocks a payment. A new non-play BB credit must add its reason to that table.
- A "Most Tips" sign on a statue is a Studio follow-up for Jack (DEC-037).
**Depends on:** DataStoreService, WorldPath.
**Consumers:** CurrencyService, CustomerService, RealOrderService.

### Events
**Purpose:** Server-wide timed events, hosted by staff or started on a schedule.
**Owner modules:** `server/Modules/EventService.luau`, `shared/Configuration/EventConfig.luau`, `server/Tests/EventService.spec.luau`
**Key invariants:**
- Events (`RushHour`, `KarenRush`, `TreasureFrenzy`) are workspace boolean attributes set true on start and false on end. They last `EVENT_DURATION_SECONDS` (600) and only one runs at a time (`_startingEvent` guards the rank-check yield). Readers: `KarenRush` in `CustomerService/Rules.luau`, `TreasureFrenzy` in `TreasureHuntService`, `RushHour` through `CustomerService:IsRushHour()`.
- A host needs `IsAdmin` or rank `MIN_STAFF_RANK` (10) and is subject to `HOST_COOLDOWN_SECONDS` (1800) after any event ends. The client call has a 5 s per-player debounce and validates the name. A random event starts every `AUTO_EVENT_INTERVAL_SECONDS` (3600) when none is active. Start and end are announced through `DialogService`.
**Depends on:** RankUtil, DialogService.
**Consumers:** CustomerService, TreasureHuntService.

### Veteran
**Purpose:** Marks players who owned a pre-revival badge.
**Owner modules:** `server/Modules/BadgeService.luau` (`LEGACY_BADGES`, `CheckVeteranStatusAsync`), `client/Scripts/PlayerOverheads.client.luau`, `server/Tests/BadgeService.spec.luau`
**Key invariants:**
- On join (the check runs before the Studio early-return) the server checks `LEGACY_BADGES`: exactly FirstQuest, Celebrity, SakuraIsland, ShinyPet and HalloweenEvent (DEC-035 Q3, DEC-037 Q12). FirstStaff is not one; staff-rank players still get it on join. Owning any of them sets the `IsVeteran` player attribute; a failed lookup is ignored.
- The overhead shows "Veteran" or "Veteran - <LevelTitle>" from the attribute; presentation only.
**Depends on:** Roblox BadgeService.
**Consumers:** Overheads.

### Perks & Pass Catalog
**Purpose:** Maps gamepass ids to perks and resolves boosts on the server.
**Owner modules:** `server/Modules/PerkService.luau`, `shared/Configuration/PassCatalog.luau`, `shared/Configuration/Perks.luau`, `server/Tests/PerkService.spec.luau`
**Key invariants:**
- `PassCatalog` maps pass id to `{ Name, Perks, Listed, Legacy }`. Owners get the perks whether the pass is `Listed` or not; `Listed` only controls shop display. Catalog-only ids are registered on `GamepassUtil.Gamepasses` at require time. Deferred (DEC-028): x2/x4 Multiplier, Unlock All Pets, Unlimited Stock.
- Boost families in `Perks.luau` are Tip and Xp (25% or 50%). Within a family the highest value wins and values never add (DEC-036 B3). `GetTipBonus` is the higher of the pass bonus and the best equipped pet bonus (`PetTipBonus`). The XP boost applies to all XP earned (`ProgressionService`, DEC-036 B2).
- `TakeTipExtra(player, basePay, bonus)` adds `basePay * bonus` to a per-player remainder, pays `floor` of it and keeps the fraction (`_tipRemainder`). It is synchronous and must be called right after `GetTipBonus`, with nothing yielding between. Base pay is untouched.
- Double Storage (`InventoryX2`, `StorageMultiplier` 2; DEC-040..042) doubles Storage limits only; Equipped limits are unchanged (Q-D1). `PlayerAdded` prefetches the passes, then `RefreshStorageMultiplier` caches the multiplier per player (skipped if the player already left). `GetStorageMultiplier` is synchronous, never yields, and returns 1 until resolved, so an unresolved cache can only block an addition. `InventoryServer` inserts and `CapsuleService` `storageLimit` read it inside count-then-insert spans. A player who loses the pass while over the normal limit loses nothing; additions stay blocked until they are under it (Q-D2). The cache is cleared in `PlayerRemoving`.
**Depends on:** GamepassUtil, PetService, DataService.
**Consumers:** CustomerService, RealOrderService, ProgressionService, InventoryServer, CapsuleService.

### Team Combo & the Serve Path
**Purpose:** A server-wide pay bonus after a chain of successful serves, and the rule that keeps a serve payout atomic.
**Owner modules:**
- `server/Modules/CustomerService/init.luau` (`RecordTeamServe`, `ApplyTeamCombo`, `_onServeTriggered`), `CustomerService/Rules.luau` (`NextTeamChain`, `TeamComboPay`)
- `server/Modules/RealOrderService.luau`, `shared/Configuration/TeamComboConfig.luau`
- `server/Tests/TeamCombo.spec.luau`
**Key invariants:**
- Any `CHAIN_TARGET` (10) consecutive successful serves server-wide, NPC and real-player, open a window of `DURATION_SECONDS` (60) paying `PAY_BONUS` (+10%). Only a customer walkout (assigned or not) resets the chain. A chain completed inside an open window refreshes it to a full 60 s. It stacks multiplicatively with Rush Hour (x2 then x1.10), and the tip boost is applied on the result. It is announced through the existing Notify path, with no HUD element (DEC-036 C1-C5).
- Throttled real serves (DEC-042 Q-P3): when the repeat-pair rule gives multiplier 1, `RealOrderService.CountsForTeamChain` is false, so the serve neither advances nor resets the chain. It still gets the combo pay bonus on its reduced pay.
- Serve-path invariant: nothing may yield between the serve guards and the payout. In `CustomerService:_onServeTriggered` the tip bonus is resolved first (it may yield on a cold pass cache); after that nothing yields from the guards (clocked in, distance, still waiting, assigned or rescue, matching tool) through the tool destroy, the payout and `RecordTeamServe`. In `RealOrderService._onOrderPickedUp` the tip bonus is resolved first and nothing after it (history record, `ApplyTeamCombo`, `TakeTipExtra`, payout) may yield. Any new call on either path must be synchronous or move before that point, or a tool can be consumed twice or a payout counted twice.
- `ApplyTeamCombo` and `IsTeamComboActive` are plain clock reads, safe on the serve path.
**Depends on:** PerkService, CurrencyService, DialogService.
**Consumers:** CustomerService, RealOrderService.

### Register Prompt (Interim)
**Purpose:** Keeps the counter "Use Ordering System" prompt from fighting the NPC Serve prompt (DEC-046).
**Owner modules:** `shared/UI/Components/Core/Hud/TopBar.luau`
**Key invariants:**
- The prompt is created per register but `Enabled` only while the local player's `ClockedIn` attribute is not `true`, and it follows `GetAttributeChangedSignal("ClockedIn")`. Clocked-in baristas see only Serve and Rescue; customers still order at the registers. This is presentation only; `OrderService` still validates every order.
- It is removed together with the Boba Phone and not before (DEC-040, DEC-044). The phone is deferred (board task BOBA-PHONE; pick-up brief `tasks/REVIVAL-001/BOBA-PHONE/brief.md`), so until then real players order at the registers.
**Depends on:** ShiftService (`ClockedIn` attribute).
**Consumers:** Ordering page.

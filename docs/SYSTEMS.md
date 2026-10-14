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
**Depends on:** ShiftService, StatisticsService, DialogService, Promise, authored Ordering System. `QuestService` is used if it exists.
**Consumers:** Ordering and mobile ordering UI, staff screens, Statistics, `OrderController` (pick-up beam; `SharedStorage.Effects.PickupBeam` is looked up on use and skipped with one `warn` when missing).

### Kitchen
**Purpose:** Turns kitchen props into proximity-prompt interactions that run recipe action sequences.
**Owner modules:**
- `server/Modules/KitchenService/init.luau`, `InteractionRunner.luau`, `PromptBuilder.luau`, `ActionRegistry.luau`, `Actions/*`
- `shared/Kitchen/Recipes.luau`, `RecipeConstructors.luau`, `KitchenTypes.luau`
- `shared/Configuration/KitchenConfig.luau`
- `client/Modules/KitchenController.luau`
**Key invariants:**
- Every key in `Recipes.Items` is matched by name to models under `workspace.Assets.Kitchen`; each match gets a prompt. Syrup dispensers are cloned from `ReplicatedStorage.SelectorModels.Kitchen.SyrupDispenser` along `Kitchen.Syrups` parts. `workspace.Assets.Kitchen` is waited for at most 10 s in `KnitStart`; if it is missing the kitchen is disabled with a `warn`, and a missing `Syrups` folder or dispenser template disables only the dispensers. `RecipeConstructors` (required by `Recipes` at startup) waits at most 5 s for `ReplicatedStorage.SharedStorage` and then looks up `Tools.Kitchen` and `Animations.Kitchen` with `WorldPath.find`; a missing tool skips the recipe or branch that needs it, and a missing animation drops only that step, each with a `warn`.
- The prompt handler re-checks on the server: the player is clocked in (`ShiftService`; a clocked-out player's prompt fires and is silently ignored, with no toast), a primary part, a character, and `MAX_INTERACTION_DISTANCE`. Rank is not consulted.
- `KitchenController` applies the Instant Brew hold-time perk after a 30 s bounded wait for the kitchen; a missing kitchen disables only that perk.
- Studio evidence (M0.4 run 2): boot, the clock-in gate (clocked out: no dialog or tool; clocked in: the Cup size dialog opens), regular coffee, and Fudge Brownie worked. Boba recipes were not working at that run; the fix is tracked separately and is not described here.
- `InteractionRunner` debounces per player and runs the recipe's `Actions` in order; each action is a function module in `Actions/` looked up by name. An action that is not a function is skipped with a warning; failures report to the client via `InteractionFailed`.
- A new action is a new module in `Actions/` with the `ActionFn` signature from `KitchenTypes`, not a branch in the runner.
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
- Spill regions come from `workspace.Assets.Spills.Areas`, with templates from `ReplicatedStorage.SharedStorage.Spills`; counts are capped by `MaxTotal` and `MaxSpawned`, with overflow queued, and a new spill is attempted every `SpawnInterval` seconds (30, tuning value). All of that content shares one 10 s budget in `KnitStart` (`WorldPath.waitFor` with a common deadline); if any path is missing, spills are disabled with one `warn` listing the missing paths, and the service also disables itself after repeated spawn failures. `SpillController` does the same on the client for its folders and storage. Studio run M0.4 run 2 showed `Spills disabled (4 authored paths missing)` in the current place, so spills are not exercised there.
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

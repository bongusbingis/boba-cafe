# Phase 1: Purchase-Flow Completeness Matrix & Release-Gate Audit

## Purchase Flow Matrix

| Product / Pass | ID in ProductIds / PassCatalog | ProductActionMap / Pass System | Grant Handler Exists | Handler Saves Before PurchaseGranted | Shop UI Reachable & Clickable | Duplicate-Safe (PurchaseId) | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Boba Bucks Pack 50** | `1780164398` | `BobaBuckReceipts` | Yes (`CurrencyService:ApplyLoaded`) | Yes (`DataService:SaveAsync`) | Yes (`Shop/Products`) | Yes (`ProcessedReceipts`) | **PASS** |
| **Boba Bucks Pack 150** | `1780164611` | `BobaBuckReceipts` | Yes (`CurrencyService:ApplyLoaded`) | Yes (`DataService:SaveAsync`) | Yes (`Shop/Products`) | Yes (`ProcessedReceipts`) | **PASS** |
| **Boba Bucks Pack 500** | `1780165079` | `BobaBuckReceipts` | Yes (`CurrencyService:ApplyLoaded`) | Yes (`DataService:SaveAsync`) | Yes (`Shop/Products`) | Yes (`ProcessedReceipts`) | **PASS** |
| **Boba Bucks Pack 1000** | `1780165241` | `BobaBuckReceipts` | Yes (`CurrencyService:ApplyLoaded`) | Yes (`DataService:SaveAsync`) | Yes (`Shop/Products`) | Yes (`ProcessedReceipts`) | **PASS** |
| **Boba Bucks Pack 5000** | `1780164860` | `BobaBuckReceipts` | Yes (`CurrencyService:ApplyLoaded`) | Yes (`DataService:SaveAsync`) | Yes (`Shop/Products`) | Yes (`ProcessedReceipts`) | **PASS** |
| **Donations (12 Tiers: 5–500,000 R$)** | `928273533` .. `1168137385` | `DonationReceipts` | Yes (`RobuxDonated` + Leaderboard) | Yes (`DataService:SaveAsync`) | Yes (In-World Donate Board) | Yes (`ProcessedReceipts`) | **PASS** |
| **Boba Party** | `3300909405` | `ProductActionMap[3300909405]` | Yes (`CafeRatingService:StartOrExtendBobaParty`) | Yes (`DataService:SaveAsync`) | Yes (`Featured`, `Products`, Board) | Yes (`ProcessedReceipts`) | **PASS** |
| **Rush Hour** | `3318558073` | `ProductActionMap[3318558073]` | Yes (`CafeRatingService:StartOrExtendRush`) | Yes (`DataService:SaveAsync`) | Yes (`Featured`, `Products`, Board) | Yes (`ProcessedReceipts`) | **PASS** |
| **Season Pass (Brew Bonus)** | `3721438870` | `ProductActionMap[3721438870]` | Yes (`SeasonPassService:GrantPremium`) | Yes (`DataService:SaveAsync`) | Yes (`Featured`, `Season`) | Yes (`ProcessedReceipts`) | **PASS** |
| **Starter Bundle** | `3721439110` | `StarterBundleReceipts` | Yes (300 BB, 2 Capsules, 1x Claimed) | Yes (`DataService:SaveAsync`) | Yes (`Featured`, `Products`) | Yes (`ProcessedReceipts` + 1x flag) | **PASS** |
| **Change Nickname** | `1152995517` | `ProductActionMap[1152995517]` | Yes (`CosmeticsService` pending name) | Yes (`DataService:SaveAsync`) | Yes (`Settings`, `NicknameDialog`) | Yes (`ProcessedReceipts`) | **PASS** |
| **Skip Hatch** | `1143554452` | `ProductActionMap[1143554452]` | Yes (Sets `TimeAccumulated` near end) | Yes (`DataService:SaveAsync`) | Yes (`Hud/BottomLeft` when hatching) | Yes (`ProcessedReceipts`) | **PASS** |
| **Boba Buddy: Cleaner** | `3721839758` | `ProductActionMap[3721839758]` | Yes (`BobaBuddyService:SpawnBuddyForPlayer`) | Yes (`DataService:SaveAsync`) | Yes (`Products`, Upsell Toast) | Yes (`ProcessedReceipts`) | **PASS** |
| **Boba Buddy: Stocker** | `3721839790` | `ProductActionMap[3721839790]` | Yes (`BobaBuddyService:SpawnBuddyForPlayer`) | Yes (`DataService:SaveAsync`) | Yes (`Products`, Upsell Toast) | Yes (`ProcessedReceipts`) | **PASS** |
| **Boba Buddy Costume** | `3721840647` | `ProductActionMap[3721840647]` | Yes (`CharacterCustomizationService:GrantCostume`) | Yes (`DataService:SaveAsync`) | Yes (`Featured`, `Inventory/Character`) | Yes (`ProcessedReceipts`) | **PASS** |
| **Pumpkin Launcher Pass** | `2055509330` | `PassCatalog` / `PassToolService` | Yes (Tool granted on spawn/clockin) | N/A (Roblox Game Pass) | Yes (`Shop/Passes`, `Featured`) | N/A (Game Pass) | **PASS** |
| **VIP Pass** | `12385781` | `PassCatalog` / `PerkService` | Yes (`DailyReward2x`, `VipLounge`, `VipTag`) | N/A (Roblox Game Pass) | Yes (`Shop/Passes`) | N/A (Game Pass) | **PASS** |
| **Star Employee Pass** | `219650999` | `PassCatalog` / `QuestService` | Yes (`+1 Slot`, `+1 Free Reroll`) | N/A (Roblox Game Pass) | Yes (`Shop/Passes`) | N/A (Game Pass) | **PASS** |
| **Instant Brewing Pass** | `12385760` | `PassCatalog` / `KitchenService` | Yes (`StationHold50` 50% hold speed) | N/A (Roblox Game Pass) | Yes (`Shop/Passes`) | N/A (Game Pass) | **PASS** |
| **Faster Walk Speed Pass** | `12385742` | `PassCatalog` / `ProgressionService` | Yes (WalkSpeed boosted to 30.4) | N/A (Roblox Game Pass) | Yes (`Shop/Passes`) | N/A (Game Pass) | **PASS** |
| **Rainbow Pack Pass** | `12385796` | `PassCatalog` / `CosmeticsService` | Yes (Rainbow Nametag, Trail, Emoji) | N/A (Roblox Game Pass) | Yes (`Shop/Passes`) | N/A (Game Pass) | **PASS** |
| **Uniform Remover Pass** | `16728123325` | `PassCatalog` / `UniformService` | Yes (Wear personal style in cafe) | N/A (Roblox Game Pass) | Yes (`Shop/Passes`) | N/A (Game Pass) | **PASS** |
| **Emote Pack Pass** | `219651061` | `PassCatalog` / Emote System | Yes (Unlocks exclusive dance emotes) | N/A (Roblox Game Pass) | Yes (`Shop/Passes`) | N/A (Game Pass) | **PASS** |
| **Mop Whack Pass** | `40973940` | `PassCatalog` / `PassToolService` | Yes (Mop Whack tool granted) | N/A (Roblox Game Pass) | Yes (`Shop/Passes`) | N/A (Game Pass) | **PASS** |
| **Flying Mop Pass** | `219651106` | `PassCatalog` / `FlyingMopController` | Yes (Mountable flying mop tool) | N/A (Roblox Game Pass) | Yes (`Shop/Passes`) | N/A (Game Pass) | **PASS** |
| **Headless Head Pass** | `14067340` | `PassCatalog` / `PassSettingsService`| Yes (Toggle invisible head in Settings)| N/A (Roblox Game Pass) | Yes (`Shop/Passes`) | N/A (Game Pass) | **PASS** |
| **Unlimited Stock Pass** | `43707849` | `PassCatalog` / `RestockService` | Yes (Stations never deplete; Jack-confirmed)| N/A (Roblox Game Pass) | Yes (`Shop/Passes`) | N/A (Game Pass) | **PASS** |
| **Barista Pass** | `6202153` | `PassCatalog` (`Listed = false`) | Unlisted (Not sold in shop/boards) | N/A | Excluded (`Listed = false`) | N/A | **PASS** |
| **Kitchen Leader Pass** | `15243046` | `PassCatalog` (`Listed = false`) | Unlisted (Not sold in shop/boards) | N/A | Excluded (`Listed = false`) | N/A | **PASS** |
| **Robux Capsule Packs (1, 10, 50)** | `3721439802`..`3721439975` | None (Unmapped stubs in ProductIds) | No handler in `ProcessReceipt` | N/A | Not in UI (Capsules sold for BB) | N/A | **MEDIUM** (Dead IDs) |

---

## Additional System Verifications

### 1. Configuration Syntax
- **`ProductIds.luau`**: Parses cleanly with zero syntax/type errors.
- **`PassCatalog.luau`**: Parses cleanly with zero syntax/type errors. All 12 listed passes have valid perk tables, descriptions, and icon asset IDs.

### 2. Season Reward Grant Handlers (`SeasonPassService:ClaimTier`)
All reward types declared in `SeasonConfig.Reward` have verified execution handlers:
- **`BobaBucks`**: Modifies balance via `CurrencyService:Modify(player, "BobaBucks", amount, "SeasonPass")`.
- **`Capsule`**: Dispatched via `CapsuleService:GrantEarnedCapsule(player, capsuleName)`.
- **`Nametag`**: Directly inserted into `Inventory.Items.Nametags` with `RandomSource = "SeasonPass"`.
- **`Title`**: Dispatched to `ProgressionService:GrantTitle(player, id)`.
- **`Costume`**: Calls `CharacterCustomizationService:GrantCostume(player, id)`.
- **`Perk`**: Handled synchronously by `SeasonPassService:HasPerk(player, perk)` checking `stateCache[player.UserId].ClaimedTiers[perkTier]`.

### 3. Boba Buddy Costume Id Integrity
- `SeasonConfig.TRACK[25]` specifies `Id = "BobaCostume"`.
- Matches exact costume key in `CharacterCustomizationService.luau`, `ProcessReceipt.server.luau`, `UI/Pages/Inventory/Character.luau`, and `UI/Components/ViewportCostumePreview.luau`.

### 4. Capsule Name Exact Matches
- SeasonConfig Track entries: `"Nametag Capsule"` and `"Regular Pet Capsule"`.
- `InventoryItemDefinitions/Capsules.luau`: Keyed exactly as `["Nametag Capsule"]` and `["Regular Pet Capsule"]`. Verified 100% character match.

### 5. Perk Wiring Trace
- **`QuestSlot`**: Read in `src/server/Modules/QuestService.luau:106` (`seasonSlot = season:HasPerk(player, "QuestSlot") == true`). Adds +1 active quest slot.
- **`QuestReroll`**: Read in `src/server/Modules/QuestService.luau:107` (`seasonReroll = season:HasPerk(player, "QuestReroll") == true`). Adds +1 free daily reroll.
- **`HatchSpeed`**: Read in `src/server/Modules/CapsuleService.luau:538` (`season:HasPerk(player, "HatchSpeed") == true`). Multiplies pet hatch progress by `SeasonConfig.HATCH_SPEED_MULT` (1.25x).

---

## Active Order Ticket Clock-Out Bug Analysis (Reported by Jack)

- **Symptom**: When a player clocks out while having an active order, the order ticket HUD does not go away.
- **Root Cause Analysis**:
  1. **Client-Side Failure to Clear State**: In `src/client/Modules/OrderController.luau:209`, `LocalPlayer:GetAttributeChangedSignal("ClockedIn")` only updates counter proximity prompts. It **never clears** `self._ticketsById`, `self.Tickets`, `self.Ticket`, or `self.CurrentOrder`, nor does it fire `self.OrderChanged` or `self.TicketsChanged`. As a result, `OrderTicket.luau` continues rendering the existing ticket because it only listens to `controller.OrderChanged`.
  2. **Server-Side Incomplete Release**: In `src/server/Modules/CustomerService/init.luau:2381` (`_releaseTicket`), the method loops over `self._assignee` to release tickets. If a player holds a real player order (`self._tickets[player]` issued via `IssueRealTicket`) or if the NPC was unassigned/in transition, `self._tickets[player]` is not cleared and no `TicketChanged:Fire(player, nil, slot)` event is dispatched to the client. Additionally, `CloseOrderingTablet` is not fired if the player was at the counter with an open ordering tablet.
- **Recommended Remediation (Post-Audit)**:
  - Client: In `OrderController.luau`, when `ClockedIn` changes to `false`, reset `self._ticketsById = {}`, `self.Tickets = {}`, `self.Ticket = nil`, `self.CurrentOrder = nil`, and fire `self.TicketsChanged:Fire({})` and `self.OrderChanged:Fire(nil)`.
  - Server: In `CustomerService:_releaseTicket(player)`, iterate through `self._tickets[player]` and fire `self:_fireTicket(player, nil, slot)` for all slots, clear `self._tickets[player] = nil`, and fire `self.Client.CloseOrderingTablet:Fire(player)`.

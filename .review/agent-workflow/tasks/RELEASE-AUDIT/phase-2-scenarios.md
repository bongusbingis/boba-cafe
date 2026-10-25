# Release-Gate Audit: Phase 2 — Release-Day Scenarios

**Date:** 2026-10-24  
**Branch:** `uhweifh`  
**Commit Analyzed:** `5afa32f` + working tree changes  
**Auditor:** Release Gate Specialist  

---

## Scenario Evaluations

### S-1: First join ever (new player, no ProfileStore record, tutorial flag unset)
- **Status:** **PASS**
- **Trace:**
  - `DataService/init.luau:65`: `PlayerStore:StartSessionAsync(getPlayerKey(player))` retrieves no existing record; initializes fresh profile from `PROFILE_TEMPLATE` (`src/shared/Configuration/ProfileTemplate.luau:178-275`).
  - `DataService/init.luau:73`: `playerProfile:Reconcile()` deep-copies defaults (Points = 0, BobaBucks = 0, Level = 1, XP = 0, default inventory tables).
  - `DataService/PlayerSetup.luau:36`: `FirstJoin` is stamped with `os.time()`. Nickname prompt is armed to trigger after their first shift (`ShiftEnding` listener).
  - Character spawns normally via Roblox character spawning.
  - On first shift, `CustomerService/init.luau:1349`: `self:_sessionShiftOf(player) == 1` flags `scripted = true`. When the player takes their first order, `Guided = true` is passed to the ordering tablet (`src/shared/UI/Pages/Ordering/init.luau`), which guides the user step-by-step.
  - No crash, clean grant of default state.

---

### S-2: Returning player who played v1 (has old schema profile)
- **Status:** **PASS**
- **Trace:**
  - `DataService/init.luau:65`: `PlayerStore:StartSessionAsync` loads existing ProfileStore record `PlayerStore_0006`.
  - `DataService/init.luau:73`: `playerProfile:Reconcile()` deep-fills any missing schema fields introduced recently:
    - `SeasonPass`: `{ SeasonId = 0, Xp = 0, Premium = false, ClaimedTiers = {} }`
    - `StarterBundleClaimed`: `false`
    - `UpsellsSeen`: `{ Cleaner = false, Stocker = false }`
    - `Character`: `{ EquippedUniform = nil, OwnedCostumes = {}, EquippedCostume = nil }`
    - `WeeklyQuests`: `{ AssignedWeek = 0, ActiveQuests = {} }`
  - Existing points, Boba Bucks, legacy pets, nametags, stats, and nicknames are 100% preserved. No data loss.

---

### S-3: Player buys Season Pass on day 1 (Season 1 active)
- **Status:** **PASS**
- **Trace:**
  - MarketplaceService prompts DevProduct `3721438870` (`ProductIds.SeasonPass`).
  - `src/server/Scripts/ProcessReceipt.server.luau:61`: `SeasonPassReceipts.IsSeasonPass(receiptInfo.ProductId)` evaluates `true`.
  - `src/server/Modules/SeasonPassReceipts.luau:48`: `GrantSeasonPass(player, playerData)` executes:
    - Sets `playerData:SetValue({ "SeasonPass", "Premium" }, true)`
    - Sets `playerData:SetValue({ "SeasonPass", "SeasonId" }, SeasonConfig.GetCurrentSeasonId(os.time()))`
  - `ProcessReceipt.server.luau:71`: `DataService:SaveAsync(player)` guarantees profile is persisted to DataStore before returning `ProductPurchaseDecision.PurchaseGranted`.
  - ReplicaService syncs replica value change `SeasonPass.Premium = true` to client.
  - Client UI (`src/shared/UI/Pages/Season/init.luau`) unlocks the premium tier track instantly.
  - Player claims Tier 1: `SeasonPassService.ClaimTier(1)` validates tier status, awards Tier 1 rewards (Nametag Sunrise / Boba Bucks), and records claim in `playerData.SeasonPass.ClaimedTiers[1]`.

---

### S-4: Player reaches Season Tier 25 and equips Boba Buddy
- **Status:** **PASS**
- **Trace:**
  - Player earns 7,000 Season XP (`SeasonConfig.TIER_XP * 25`).
  - In `SeasonPassService.luau:290`: claiming Tier 25 with Premium awards reward `{ Type = "Costume", Id = "BobaCostume" }`.
  - `SeasonPassService.luau:284` calls `CharacterCustomizationService:GrantCostume(player, "BobaCostume")`.
  - `CharacterCustomizationService.luau:280`: updates `playerData.Character.OwnedCostumes["BobaCostume"] = true`.
  - Player opens Character Customization UI: costume is listed as owned. Player clicks Equip.
  - Client calls `CharacterCustomizationService.EquipCostume("BobaCostume")`.
  - `CharacterCustomizationService.luau:128`: loads `BobaCostume` model from `workspace.Assets.BobaBuddy` (or ServerStorage fallback). Welds costume parts to player's R15 character rig (`UpperTorso` / `Torso`).
  - On character respawn, `CharacterAdded` re-applies `state.EquippedCostume`. Character visually appears as Boba Buddy.

---

### S-5: Player buys Boba Buddy Cleaner in shop, summons buddy, buddy cleans a spill
- **Status:** **PASS**
- **Trace:**
  - Player buys product `3721438964` (`ProductIds.BobaBuddyCleaner`).
  - `ProcessReceipt.server.luau` -> `BobaBuddyReceipts.luau` grants cleaner buddy ownership in profile.
  - Player summons buddy via HUD / UI: `BobaBuddyService:SummonBuddy(player, "Cleaner")`.
  - Model spawns, sets collision group `BobaBuddies`, and starts `CleanerBehavior.Start(model, owner, setBusy)` (`src/server/Modules/BobaBuddyService/CleanerBehavior.luau:19`).
  - Every 2.5s (`CHECK_INTERVAL_SECONDS`), scans `SpillService.Spills.Mopping` within 25 studs (`RANGE_STUDS`).
  - Tags nearest spill with attribute `ClaimedByBuddy = true`.
  - Navigates via `Navigator.WalkTo(model, bestPos)` using PathfindingService.
  - Plays `MoppingAnim` on humanoid animator, waits `MOP_DURATION_SECONDS` (3s).
  - Calls `bestSpill:Clean()` (`src/server/Modules/SpillService/Spill.luau`).
  - Spill disappears; player receives prompt toast / notification. Buddy returns to follow behavior.

---

### S-6: Player buys Unlimited Stock pass, stocker restocks a station
- **Status:** **PASS**
- **Trace:**
  - Player purchases GamePass `43707849` (`PassCatalog.luau:148`).
  - `PerkService.luau:101`: `player:SetAttribute("PerkUnlimitedStock", true)`.
  - When player pours at any station, `KitchenService/init.luau:441` runs:
    ```luau
    local hasUnlimited = perkService:HasPerk(player, "UnlimitedStock") == true
    if not hasUnlimited then
        local newStock = math.max(0, currentStock - 1)
        prompt:SetAttribute("CurrentStock", newStock)
        updateStationVisual(model, newStock, defaultStock)
    end
    ```
  - Station stock never decreases below full. Station is effectively always stocked.
  - Stocker buddy behavior handles manual/idle restock when player is not actively holding the station.

---

### S-7: Player joins, plays 30 min, crashes / Alt+F4s
- **Status:** **PASS**
- **Trace:**
  - ProfileStore manages persistent session with `AUTO_SAVE_PERIOD = 300` (5 minutes).
  - When client disconnects / crashes / Alt+F4s, Roblox server fires `Players.PlayerRemoving`.
  - `DataService:PlayerRemoving(player)` (`DataService/init.luau:200`) calculates session elapsed time, updates `Statistics.TimePlayed`, and calls `profile:EndSession()`.
  - `profile:EndSession()` forces an immediate release and DataStore save.
  - Maximum possible uncommitted gameplay data in the catastrophic event of a host server process crash is bounded to 5 minutes (auto-save interval). All Robux purchases are saved immediately via `SaveAsync`.

---

### S-8: Server shutdown for update (SoftShutdown / standard deploy)
- **Status:** **PASS (WITH PREREQUISITE: `IS_MOCK_STORE_ENABLED = false`)**
- **Trace:**
  - ProfileStore connects to `game:BindToClose(function() ... end)` (`ProfileStore.luau:2208`).
  - On shutdown, `ProfileStore.IsClosing = true`.
  - Iterates all active profiles in `AutoSaveList` and calls `SaveProfileAsync(profile, true, nil, "Shutdown")`.
  - `BindToClose` yields until all save jobs finish (`while on_close_save_job_count > 0 do task.wait() end`).
  - > [!CAUTION]
  - **Prerequisite:** If `IS_MOCK_STORE_ENABLED = true`, ProfileStore line 2204 exits `BindToClose` immediately without saving! As established in Phase 0, `IS_MOCK_STORE_ENABLED` must be set to `false` for production release.

---

### S-9: Two players interact (barista serves a real player customer)
- **Status:** **PASS**
- **Trace:**
  - Customer player places drink order at register or kiosk.
  - `OrderService:CreateOrder(customer, orderData)` registers order with status `"Pending Preparation"`.
  - `OrderService:_dispatchPending()` assigns order to longest-idle clocked-in barista:
    - Sets `order.status = "Being Prepared"`, `order.preparedBy = barista.UserId`.
    - Fires `self:_issueTicket(barista, order)` -> `CustomerService.TicketChanged` -> `OrderController` on client.
  - Barista's HUD renders `OrderTicket` with exact recipe step instructions.
  - Barista completes drink at kitchen stations.
  - Direct handoff beam links barista and customer (`RealOrderHandoffBeam`).
  - Barista hands off drink to customer via ProximityPrompt or PickupNode deposit.
  - Customer receives drink; barista receives shift payment, points, and tip. `CustomerService:ClearRealTicket` removes ticket from barista's HUD.

---

### S-10: Group membership and progression
- **Status:** **PASS (AUDIT CLARIFICATION)**
- **Trace:**
  - The game does not implement a 1.2x cash multiplier for group members.
  - Instead, group benefits are implemented through:
    1. **Group Rank Progression:** `src/shared/Configuration/GroupRankProgression.luau` and `src/server/Modules/RankingService.luau` map career levels (1, 5, 10, 15, 20) and legacy passes (Barista 6202153, Kitchen Leader 15243046) to official Roblox group ranks 6 through 10.
    2. **Group Pet Reward:** `src/server/Modules/GroupBenefitService.luau` checks `player:IsInGroupAsync(3174578)` to award the exclusive "Ant Pet" companion.
    3. **Titles:** `Titles.luau:127` grants the "Boba Staff" title to group members.
  - All group checks are handled asynchronously via `pcall(player.IsInGroupAsync, ...)` with timeouts and cache tables to prevent rate limits.

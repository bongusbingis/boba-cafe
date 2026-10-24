---> services
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

---> networking
-- The Networking folder is not guaranteed to exist in the place, so find or create it (and the remote) in code.
-- This has no yields, so it is safe to run before ProcessReceipt is assigned.
local function getOrCreateRemoteFunction(name: string): RemoteFunction
	local networking = ReplicatedStorage:FindFirstChild("Networking")
	if not networking then
		networking = Instance.new("Folder")
		networking.Name = "Networking"
		networking.Parent = ReplicatedStorage
	end

	local remote = networking:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = networking
	elseif not remote:IsA("RemoteFunction") then
		warn(`[ProcessReceipt] Networking.{name} is a {remote.ClassName}, expected a RemoteFunction`)
	end
	return remote :: RemoteFunction
end

local GetPurchases = getOrCreateRemoteFunction("GetPurchases")

---> constants
local SKIP_HATCH_PRODUCT_ID = 1143554452
local DATA_TIMEOUT_SECONDS = 30
local MAX_PROCESSED_RECEIPTS = 200

---> receipt callback
-- MarketplaceService.ProcessReceipt must be assigned before anything that can yield (the dependency waits below),
-- otherwise receipts that arrive early are never answered. Until the real handler is ready, ask Roblox to retry.
local processReceipt: (({ [string]: any }) -> Enum.ProductPurchaseDecision)? = nil

MarketplaceService.ProcessReceipt = function(receiptInfo)
	if not processReceipt then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return processReceipt(receiptInfo)
end

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local ProductIds = require(Shared.Configuration.ProductIds)

---> lifecycle
local HATCH_DURATION_SECONDS = require(Shared.Configuration.CapsuleConfig).PET_HATCH_DURATION
local ProductPurchaseDatastore = DataStoreService:GetDataStore("ProductPurchaseDatastore_0001")

--- [number]: {string, (Player, ReceiptInfo, playerData) -> boolean}
--- Maps productId to array consisting of (productName, callback function). The callback receives the player's
--- profile data and must return true only once the grant has been applied to it. Returning false (optionally with a
--- reason) grants nothing: the receipt is answered NotProcessedYet and is not recorded as processed.

type PendingHatch = {
	CapsuleName: string, -- definition name of the capsule that was used
	TimeAccumulated: number, -- active-play seconds accumulated so far
}

local ProductActionMap = {
	[SKIP_HATCH_PRODUCT_ID] = {
		"Skip Hatch",
		function(_, _, playerData)
			-- DEC-006: Skip Hatch only has value while a pet is hatching. With no hatch pending nothing is granted and
			-- no skip credit is stored; the receipt stays unconsumed (NotProcessedYet, not recorded) so Roblox keeps it.
			local hatchingPet = playerData.HatchingPet
			if not hatchingPet or hatchingPet == false then
				return false, "no hatch pending"
			end
			local updatedHatch: any = table.clone(hatchingPet)
			updatedHatch.TimeAccumulated = HATCH_DURATION_SECONDS - 5
			playerData:SetValue({ "HatchingPet" }, updatedHatch)
			return true
		end,
	},
}

-- Donate! board products (IDs in Shared.Configuration.ProductIds). The optional third element runs once, only
-- after the receipt is answered PurchaseGranted (Top Donators credit).
local DonationReceipts = require(ServerScriptService:WaitForChild("Server").Modules.DonationReceipts)
for productId, donationAction in DonationReceipts.BuildActions() do
	if ProductActionMap[productId] then
		warn(`[ProcessReceipt] Donation ProductId {productId} collides with an existing product; skipped`)
		continue
	end
	ProductActionMap[productId] = { donationAction.Name, donationAction.Grant, donationAction.OnGranted }
end

-- Robux Boba Bucks packs (IDs in Shared.Configuration.ProductIds). The grant is applied to the loaded profile
-- synchronously, so it is recorded with the receipt like every other product.
local BobaBuckReceipts = require(ServerScriptService:WaitForChild("Server").Modules.BobaBuckReceipts)
for productId, packAction in BobaBuckReceipts.BuildActions() do
	if ProductActionMap[productId] then
		warn(`[ProcessReceipt] Boba Bucks ProductId {productId} collides with an existing product; skipped`)
		continue
	end
	ProductActionMap[productId] = { packAction.Name, packAction.Grant }
end

-- Starter Bundle (SEASON-PASS): one-time bundle grant on the loaded profile.
local StarterBundleReceipts = require(ServerScriptService:WaitForChild("Server").Modules.StarterBundleReceipts)
for productId, bundleAction in StarterBundleReceipts.BuildActions() do
	if ProductActionMap[productId] then
		warn(`[ProcessReceipt] Starter Bundle ProductId {productId} collides with an existing product; skipped`)
		continue
	end
	ProductActionMap[productId] = { bundleAction.Name, bundleAction.Grant }
end

-- Season Pass premium (SEASON-PASS): flags premium for the current season (sync,
-- no yield). Retroactive: already-reached premium tiers become claimable at once.
local SEASON_PASS_PRODUCT_ID = ProductIds.SeasonPass
if SEASON_PASS_PRODUCT_ID then
	if ProductActionMap[SEASON_PASS_PRODUCT_ID] then
		warn(
			`[ProcessReceipt] Season Pass ProductId {SEASON_PASS_PRODUCT_ID} collides with an existing product; skipped`
		)
	else
		ProductActionMap[SEASON_PASS_PRODUCT_ID] = {
			"Brew Bonus",
			function(player, _receiptInfo, playerData)
				local seasonPassService = Knit.GetService("SeasonPassService")
				return seasonPassService:GrantPremium(player, playerData)
			end,
			function(player, _receiptInfo)
				local ok, err = pcall(function()
					Knit.GetService("AnalyticsEvents"):Custom(player, "SeasonPassPurchased")
				end)
				if not ok then
					warn(`[ProcessReceipt] SeasonPassPurchased analytics failed: {err}`)
				end
				pcall(function()
					Knit.GetService("SeasonPassService").Client.SeasonPassChanged:Fire(player)
				end)
			end,
		}
	end
end

local BOBA_PARTY_PRODUCT_ID = ProductIds.BobaParty
if BOBA_PARTY_PRODUCT_ID then
	ProductActionMap[BOBA_PARTY_PRODUCT_ID] = {
		"Boba Party",
		function(player, _receiptInfo, _playerData)
			local cafeRatingService = Knit.GetService("CafeRatingService")
			local ok, err = cafeRatingService:StartOrExtendBobaParty(player)
			if not ok then
				return false, err or "failed to start or extend boba party"
			end
			return true
		end,
		function(player, _receiptInfo)
			pcall(function()
				Knit.GetService("AnalyticsEvents"):Custom(player, "BobaPartyPurchased", 1)
			end)
		end,
	}
end

-- Rush Hour: starts the normal server Rush (RatingConfig.RUSH_SECONDS), or adds that long to a running Rush/Party.
local RUSH_HOUR_PRODUCT_ID = ProductIds.RushHour
if RUSH_HOUR_PRODUCT_ID then
	ProductActionMap[RUSH_HOUR_PRODUCT_ID] = {
		"Rush Hour",
		function(player, _receiptInfo, _playerData)
			local cafeRatingService = Knit.GetService("CafeRatingService")
			local ok, err = cafeRatingService:StartOrExtendRush(player)
			if not ok then
				return false, err or "failed to start or extend rush hour"
			end
			return true
		end,
		function(player, _receiptInfo)
			pcall(function()
				Knit.GetService("AnalyticsEvents"):Custom(player, "RushHourPurchased", 1)
			end)
		end,
	}
end

-- Roleplay Nickname change: updates the profile's Nickname from memory cache.
local CHANGE_NICKNAME_PRODUCT_ID = ProductIds.ChangeNickname
if CHANGE_NICKNAME_PRODUCT_ID then
	ProductActionMap[CHANGE_NICKNAME_PRODUCT_ID] = {
		"Change Nickname",
		function(player, _receiptInfo, playerData)
			local cosmeticsService = Knit.GetService("CosmeticsService")
			local pending = cosmeticsService:GetPendingNickname(player)
			if not pending or pending == "" then
				warn(`[ProcessReceipt] No pending nickname found for player {player.Name}`)
				return false, "no pending nickname"
			end
			playerData:SetValue({ "Nickname" }, pending)
			playerData:SetValue({ "NicknameSkipped" }, false)
			return true
		end,
		function(player, _receiptInfo)
			local cosmeticsService = Knit.GetService("CosmeticsService")
			local pending = cosmeticsService:GetPendingNickname(player)
			if pending and pending ~= "" then
				cosmeticsService:NotifyNicknameChanged(player, pending)
				cosmeticsService:ClearPendingNickname(player)
			end
			pcall(function()
				Knit.GetService("AnalyticsEvents"):Custom(player, "NicknameChangePurchased", 1)
				Knit.GetService("DialogService"):Notify(player, {
					Title = "Nickname Changed",
					Description = `Your roleplay nickname is now {pending or ""}.`,
				})
			end)
		end,
	}
end

-- Boba Buddy: Cleaner (consumable companion that cleans spills)
local BOBA_BUDDY_CLEANER_ID = ProductIds.BobaBuddy and ProductIds.BobaBuddy.Cleaner
if BOBA_BUDDY_CLEANER_ID then
	ProductActionMap[BOBA_BUDDY_CLEANER_ID] = {
		"Boba Buddy: Cleaner",
		function(player, _receiptInfo, _playerData)
			local shiftService = Knit.GetService("ShiftService")
			local isClockedIn = player:GetAttribute("ClockedIn") == true
			if shiftService and shiftService.IsClockedIn then
				isClockedIn = shiftService:IsClockedIn(player)
			end
			if not isClockedIn then
				warn(`[ProcessReceipt] Player {player.Name} is not clocked in; deferring Boba Buddy Cleaner grant`)
				return false, "not clocked in"
			end

			local buddyService = Knit.GetService("BobaBuddyService")
			if not buddyService then
				return false, "service unavailable"
			end

			local ok, err = buddyService:SpawnBuddyForPlayer(player, "Cleaner")
			return ok, err
		end,
		function(player, _receiptInfo)
			pcall(function()
				local upsellService = Knit.GetService("BobaBuddyUpsellService")
				if upsellService and upsellService.OnProductPurchased then
					upsellService:OnProductPurchased(player, "Cleaner")
				end
			end)
		end,
	}
end

-- Boba Buddy: Stocker (consumable companion that restocks stations)
local BOBA_BUDDY_STOCKER_ID = ProductIds.BobaBuddy and ProductIds.BobaBuddy.Stocker
if BOBA_BUDDY_STOCKER_ID then
	ProductActionMap[BOBA_BUDDY_STOCKER_ID] = {
		"Boba Buddy: Stocker",
		function(player, _receiptInfo, _playerData)
			local shiftService = Knit.GetService("ShiftService")
			local isClockedIn = player:GetAttribute("ClockedIn") == true
			if shiftService and shiftService.IsClockedIn then
				isClockedIn = shiftService:IsClockedIn(player)
			end
			if not isClockedIn then
				warn(`[ProcessReceipt] Player {player.Name} is not clocked in; deferring Boba Buddy Stocker grant`)
				return false, "not clocked in"
			end

			local buddyService = Knit.GetService("BobaBuddyService")
			if not buddyService then
				return false, "service unavailable"
			end

			local ok, err = buddyService:SpawnBuddyForPlayer(player, "Stocker")
			return ok, err
		end,
		function(player, _receiptInfo)
			pcall(function()
				local upsellService = Knit.GetService("BobaBuddyUpsellService")
				if upsellService and upsellService.OnProductPurchased then
					upsellService:OnProductPurchased(player, "Stocker")
				end
			end)
		end,
	}
end

-- Boba Buddy Costume (permanent wearable costume)
local BOBA_BUDDY_COSTUME_ID = ProductIds.BobaBuddyCostume
if BOBA_BUDDY_COSTUME_ID then
	ProductActionMap[BOBA_BUDDY_COSTUME_ID] = {
		"Boba Buddy Costume",
		function(player, _receiptInfo, _playerData)
			local charService = Knit.GetService("CharacterCustomizationService")
			if not charService then
				return false, "service unavailable"
			end
			local ok, err = charService:GrantCostume(player, "BobaCostume")
			return ok, err
		end,
	}
end

-- PurchaseIds currently being handled; guards against a re-entrant call for the same receipt while one yields.
local inFlight: { [string]: boolean } = {}
-- PurchaseIds granted on this server whose post-grant hook has not run yet (the save was not confirmed). The hook
-- runs on the first PurchaseGranted answer for it, so it runs at most once per grant.
local pendingOnGranted: { [string]: (Player, { [string]: any }) -> () } = {}

--- Records `purchaseId` in the profile and prunes the oldest entries beyond MAX_PROCESSED_RECEIPTS.
--- Does not yield, so the grant and the record are applied back to back with the check in processReceipt.
local function recordReceipt(playerData, purchaseId: string)
	if typeof(playerData.ProcessedReceipts) ~= "table" then
		playerData:SetValue({ "ProcessedReceipts" }, {})
	end
	playerData:SetValue({ "ProcessedReceipts", purchaseId }, os.time())

	local count = 0
	for _ in playerData.ProcessedReceipts do
		count += 1
	end

	while count > MAX_PROCESSED_RECEIPTS do
		local oldestId, oldestTime = nil, math.huge
		for id, grantedAt in playerData.ProcessedReceipts do
			if id ~= purchaseId and grantedAt < oldestTime then
				oldestId, oldestTime = id, grantedAt
			end
		end
		if not oldestId then
			break
		end
		playerData:SetValue({ "ProcessedReceipts", oldestId }, nil)
		count -= 1
	end
end

--- Appends to the purchase history. This is informational only and never decides whether a purchase was granted.
local function writePurchaseHistory(userId: number, productName: string, productId: number)
	local ok, err = pcall(function()
		ProductPurchaseDatastore:UpdateAsync(userId, function(old)
			if not old then
				old = {}
			end
			table.insert(old, {
				ProductName = productName,
				ProductId = productId,
				Timestamp = os.time(),
			})
			return old
		end)
	end)
	if not ok then
		warn(`[ProcessReceipt] Failed to write purchase history for {userId}: {err}`)
	end
end

local function handleReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local action = ProductActionMap[receiptInfo.ProductId]
	if not action then
		-- Never consume payment for something we cannot grant. Roblox retries until a mapping is added.
		warn(
			`[ProcessReceipt] NO ACTION MAPPED for ProductId {receiptInfo.ProductId} (PurchaseId {receiptInfo.PurchaseId}, player {player.Name}). Purchase NOT granted; add it to ProductActionMap.`
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	if inFlight[purchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	inFlight[purchaseId] = true

	local function finish(decision: Enum.ProductPurchaseDecision)
		inFlight[purchaseId] = nil
		local onGranted = pendingOnGranted[purchaseId]
		if onGranted and decision == Enum.ProductPurchaseDecision.PurchaseGranted then
			pendingOnGranted[purchaseId] = nil
			task.spawn(function()
				local ok, err = pcall(onGranted, player, receiptInfo)
				if not ok then
					warn(`[ProcessReceipt] Post-grant hook failed for PurchaseId {purchaseId}: {err}`)
				end
			end)
		end
		return decision
	end

	local name = action[1]
	local f = action[2]
	local dataService = Knit.GetService("DataService")

	-- Player data is always required: the receipt record that makes this idempotent lives in the profile.
	local dataOk, playerData = dataService:GetDataAsync(player):timeout(DATA_TIMEOUT_SECONDS):await()
	if not dataOk or not playerData or player.Parent ~= Players then
		return finish(Enum.ProductPurchaseDecision.NotProcessedYet)
	end

	--- PurchaseGranted is only final once the record is in the DataStore; a crash before the next autosave would
	--- otherwise lose a paid grant. If the save is not confirmed, the in-memory grant and record stay as they are, so
	--- the retry Roblox sends takes the "already granted" path below instead of granting again.
	local function saveThenDecide(): Enum.ProductPurchaseDecision
		local saved = dataService
			:SaveAsync(player, function(lastSavedData)
				return typeof(lastSavedData.ProcessedReceipts) == "table"
					and lastSavedData.ProcessedReceipts[purchaseId] ~= nil
			end)
			:expect()
		if not saved then
			warn(`[ProcessReceipt] Could not confirm save for PurchaseId {purchaseId} ({player.Name}); will retry`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Already granted (and recorded in the profile): make sure it is saved, then answer without granting again.
	if typeof(playerData.ProcessedReceipts) == "table" and playerData.ProcessedReceipts[purchaseId] then
		return finish(saveThenDecide())
	end

	local success, res, reason = pcall(f, player, receiptInfo, playerData)
	if not success then
		warn("Error processing purchase for product " .. receiptInfo.ProductId .. ": " .. tostring(res))
		return finish(Enum.ProductPurchaseDecision.NotProcessedYet)
	end

	if res ~= true then
		warn("Purchase action for product", receiptInfo.ProductId, "was not granted:", res, reason)
		return finish(Enum.ProductPurchaseDecision.NotProcessedYet)
	end

	if action[3] then
		pendingOnGranted[purchaseId] = action[3]
	end

	-- The grant is already applied to the profile; record it before answering so a retry cannot grant twice.
	local recorded, recordErr = pcall(recordReceipt, playerData, purchaseId)
	if not recorded then
		-- The grant is already in the profile, so answering NotProcessedYet here would make Roblox retry and grant
		-- a second time. PurchaseGranted is the safer answer.
		warn(`[ProcessReceipt] Granted {name} but failed to record PurchaseId {purchaseId}: {recordErr}`)
		task.spawn(writePurchaseHistory, player.UserId, name, receiptInfo.ProductId)
		return finish(Enum.ProductPurchaseDecision.PurchaseGranted)
	end

	-- History write must not delay or influence the decision. A retry skips it, so it is written once.
	task.spawn(writePurchaseHistory, player.UserId, name, receiptInfo.ProductId)

	return finish(saveThenDecide())
end

-- Knit.GetService is only valid once Knit has started; until then every receipt is answered NotProcessedYet.
Knit.OnStart()
	:andThen(function()
		processReceipt = handleReceipt
	end)
	:catch(warn)

---> GetPurchases remote function
-- Per-player cooldown prevents clients from spamming DataStore reads.
local FETCH_COOLDOWN_SECONDS = 10
local fetchLastTime: { [number]: number } = {}

Players.PlayerRemoving:Connect(function(player)
	fetchLastTime[player.UserId] = nil
end)

GetPurchases.OnServerInvoke = function(player: Player)
	local userId = player.UserId
	local now = os.clock()

	if fetchLastTime[userId] and (now - fetchLastTime[userId]) < FETCH_COOLDOWN_SECONDS then
		return nil
	end
	fetchLastTime[userId] = now

	local ok, data = pcall(function()
		return ProductPurchaseDatastore:GetAsync(userId)
	end)

	if not ok then
		warn("[GetPurchases] DataStore error for", player.Name, ":", data)
		return nil
	end

	return data or {}
end

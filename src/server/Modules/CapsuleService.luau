--!strict

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)

local CapsuleConfig = require(Shared.Configuration.CapsuleConfig)
local CapsuleUtil = require(Shared.Inventory.CapsuleUtil)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)

local HATCH_DURATION = CapsuleConfig.PET_HATCH_DURATION
local DEFAULT_CAPSULE_IMAGE = "rbxassetid://6073658218"
local STARTER_CAPSULE_REDEEMED = "StarterCapsule"
local playerTransactions: { [number]: boolean } = {}

-- Tracks the os.time() at which each player's current session began.
-- Only online players appear in this table.
local sessionStarts: { [number]: number } = {}
local hatchDebounces: { [number]: number } = {}

local CapsuleService = Knit.CreateService({
	Name = "CapsuleService",
	Client = {
		HatchCapsule = Knit.CreateSignal(),
		GetPaidRandomPolicy = function(self, player: Player)
			return self.Server:GetPaidRandomPolicy(player)
		end,
		PurchaseNametagCapsules = function(self, player: Player, packSize: number)
			return self.Server:PurchaseNametagCapsules(player, packSize)
		end,
		PurchaseDeterministicNametag = function(self, player: Player, nametagName: string)
			return self.Server:PurchaseDeterministicNametag(player, nametagName)
		end,
		TryCompleteReadyHatch = function(self, player: Player)
			return self.Server:TryCompleteReadyHatch(player)
		end,
	},
})

--------------------------------------------------------------------------------
-- Private
--------------------------------------------------------------------------------

local function getDataService()
	return Knit.GetService("DataService")
end

local function getDialogService()
	return Knit.GetService("DialogService")
end

local function withPlayerTransaction(player: Player, callback: () -> (boolean, string?)): (boolean, string?)
	if playerTransactions[player.UserId] then
		return false, "TransactionPending"
	end

	playerTransactions[player.UserId] = true
	local callOk, result, reason = pcall(callback)
	playerTransactions[player.UserId] = nil
	if not callOk then
		warn("[CapsuleService]: Player transaction failed for", player.Name, result)
		return false, "TransactionFailed"
	end
	return result, reason
end

local function consumeCapsule(player: Player, capsuleId: string): boolean
	local Inventory = require(ReplicatedStorage.Shared.Inventory)
	local inventoryOk, inventory = Inventory:GetPlayerInventoryAsync(player, "Capsules"):await()
	if not inventoryOk or not inventory then
		return false
	end

	local item = inventory:GetItemFromId(capsuleId)
	if not item then
		return false
	end

	if item.Name == "Nametag Capsule" then
		local remaining = item:GetStackCount() - 1
		if remaining > 0 then
			item:SetStackCount(remaining)
		else
			inventory:_removeItemById(capsuleId)
		end
	else
		inventory:_removeItemById(capsuleId)
	end
	return true
end

local function settlePendingBobaBucksRefund(player: Player, playerData: any, amount: number): boolean
	local obligationSaveCallOk, obligationSaved = pcall(function()
		return getDataService()
			:SaveAsync(player, function(savedData)
				return savedData.PendingBobaBucksRefund == amount
					and savedData.Currency.BobaBucks == playerData.Currency.BobaBucks
					and savedData.Statistics.BobaBucksSpent == playerData.Statistics.BobaBucksSpent
			end)
			:await()
	end)
	if not obligationSaveCallOk or not obligationSaved then
		warn("[CapsuleService]: Pending BobaBucks refund is not yet saved for", player.Name, amount)
		return false
	end

	local balance = playerData.Currency.BobaBucks
	local spent = playerData.Statistics.BobaBucksSpent
	if typeof(balance) ~= "number" or typeof(spent) ~= "number" then
		warn("[CapsuleService]: Pending BobaBucks refund cannot be settled for", player.Name, amount)
		return false
	end

	local updatedCurrency = table.clone(playerData.Currency)
	local updatedStatistics = table.clone(playerData.Statistics)
	updatedCurrency.BobaBucks = balance + amount
	updatedStatistics.BobaBucksSpent = math.max(0, spent - amount)
	local settleCallOk, settleError = pcall(function()
		playerData:SetValues({}, {
			Currency = updatedCurrency,
			Statistics = updatedStatistics,
			PendingBobaBucksRefund = 0,
		})
	end)
	if not settleCallOk then
		warn("[CapsuleService]: Failed to apply pending BobaBucks refund for", player.Name, amount, settleError)
		return false
	end

	local settleSaveCallOk, settleSaved = pcall(function()
		return getDataService()
			:SaveAsync(player, function(savedData)
				return savedData.PendingBobaBucksRefund == 0
					and savedData.Currency.BobaBucks == updatedCurrency.BobaBucks
					and savedData.Statistics.BobaBucksSpent == updatedStatistics.BobaBucksSpent
			end)
			:await()
	end)
	if not settleSaveCallOk or not settleSaved then
		warn("[CapsuleService]: Settled BobaBucks refund save is not yet confirmed for", player.Name, amount)
		return false
	end
	return true
end

local function retryPendingBobaBucksRefund(player: Player): boolean
	local callOk, dataOk, playerData = pcall(function()
		return getDataService():GetDataAsync(player):timeout(10):await()
	end)
	if not callOk or not dataOk or not playerData then
		warn("[CapsuleService]: Could not load pending BobaBucks refund for", player.Name)
		return false
	end

	local amount = playerData.PendingBobaBucksRefund or 0
	if typeof(amount) ~= "number" or amount < 0 then
		warn("[CapsuleService]: Invalid pending BobaBucks refund for", player.Name)
		return false
	end
	if amount == 0 then
		return true
	end
	return settlePendingBobaBucksRefund(player, playerData, amount)
end

local function refundBobaBucks(player: Player, amount: number): boolean
	local callOk, dataOk, playerData = pcall(function()
		return getDataService():GetDataAsync(player):timeout(10):await()
	end)
	if not callOk or not dataOk or not playerData then
		warn("[CapsuleService]: REFUND REQUIRED; failed to record", amount, "BobaBucks for", player.Name)
		return false
	end

	local currentPending = playerData.PendingBobaBucksRefund or 0
	if typeof(currentPending) ~= "number" or currentPending < 0 then
		warn("[CapsuleService]: REFUND REQUIRED; invalid pending amount for", player.Name)
		return false
	end
	local nextPending = currentPending + amount
	local recordCallOk, recordError = pcall(function()
		playerData:SetValue({ "PendingBobaBucksRefund" }, nextPending)
	end)
	if not recordCallOk then
		warn("[CapsuleService]: REFUND REQUIRED; failed to record", amount, "BobaBucks for", player.Name, recordError)
		return false
	end
	return settlePendingBobaBucksRefund(player, playerData, nextPending)
end

function CapsuleService:GetPaidRandomPolicy(player: Player): (boolean, boolean?)
	local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if not ok or typeof(policy) ~= "table" or typeof(policy.ArePaidRandomItemsRestricted) ~= "boolean" then
		return false, nil
	end
	return true, policy.ArePaidRandomItemsRestricted
end

function CapsuleService:PurchaseNametagCapsules(player: Player, packSize: number): (boolean, string?)
	if typeof(packSize) ~= "number" or packSize ~= packSize or packSize == math.huge or packSize % 1 ~= 0 then
		return false, "InvalidPack"
	end
	local packs = {
		[1] = { Cost = 150, Count = 1 },
		[10] = { Cost = 1350, Count = 10 },
		[50] = { Cost = 6000, Count = 50 },
	}
	local pack = packs[packSize]
	if not pack then
		return false, "InvalidPack"
	end
	return withPlayerTransaction(player, function()
		if not retryPendingBobaBucksRefund(player) then
			return false, "RefundPending"
		end

		local policyOk, restricted = self:GetPaidRandomPolicy(player)
		if not policyOk then
			return false, "PolicyUnavailable"
		end
		if restricted then
			return false, "Restricted"
		end

		local Inventory = require(ReplicatedStorage.Shared.Inventory)
		local inventoryOk, inventory = Inventory:GetPlayerInventoryAsync(player, "Capsules"):await()
		if not inventoryOk or not inventory then
			return false, "InventoryUnavailable"
		end
		local existingId, existing, slots = nil, nil, 0
		for id, item in inventory.Inventory do
			slots += 1
			if item.Name == "Nametag Capsule" then
				existingId, existing = id, item
			end
		end
		local limits = require(Shared.Configuration.InventoryLimits)
		if not existing and slots >= limits.Storage.Capsules then
			return false, "InventoryFull"
		end

		local spent = Knit.GetService("CurrencyService"):TrySpendAsync(player, "BobaBucks", pack.Cost)
		if not spent then
			return false, "InsufficientFunds"
		end

		local granted = false
		local current = if existingId then inventory:GetItemFromId(existingId) else nil
		if current then
			local previousCount = current:GetStackCount()
			local grantCallOk, grantError = pcall(function()
				current:SetProperty("RandomSource", "Paid")
				current:SetStackCount(previousCount + pack.Count)
			end)
			if not grantCallOk then
				warn("[CapsuleService]: Capsule stack update threw after charging", player.Name, grantError)
			end
			local updated = inventory:GetItemFromId(existingId)
			granted = updated ~= nil
				and updated:GetStackCount() == previousCount + pack.Count
				and updated:GetProperty("RandomSource") == "Paid"
		end
		if not granted then
			local grantCallOk, insertedId = pcall(function()
				return inventory:Insert({
					Name = "Nametag Capsule",
					StackCount = pack.Count,
					Properties = { RandomSource = "Paid" },
				})
			end)
			if not grantCallOk then
				warn("[CapsuleService]: Capsule fallback grant threw after charging", player.Name, insertedId)
			end
			granted = grantCallOk and insertedId ~= nil
		end
		if not granted then
			local refunded = refundBobaBucks(player, pack.Cost)
			return false, if refunded then "GrantFailed" else "RefundPending"
		end
		return true
	end)
end

function CapsuleService:PurchaseDeterministicNametag(player: Player, nametagName: string): (boolean, string?)
	if typeof(nametagName) ~= "string" then
		return false, "InvalidItem"
	end
	return withPlayerTransaction(player, function()
		if not retryPendingBobaBucksRefund(player) then
			return false, "RefundPending"
		end

		local policyOk, restricted = self:GetPaidRandomPolicy(player)
		if not policyOk then
			return false, "PolicyUnavailable"
		end
		if not restricted then
			return false, "Unavailable"
		end
		local definition = InventoryItemDefinitions.Nametags[nametagName]
		if not definition or definition.OffSale then
			return false, "InvalidItem"
		end
		local price = tonumber((definition.Price:gsub("%s", "")))
		if not price or price <= 0 or price ~= math.floor(price) then
			return false, "InvalidPrice"
		end
		local Inventory = require(ReplicatedStorage.Shared.Inventory)
		local inventoryOk, inventory = Inventory:GetPlayerInventoryAsync(player, "Nametags"):await()
		if not inventoryOk or not inventory then
			return false, "InventoryUnavailable"
		end
		local existingId, existing, slots = nil, nil, 0
		for id, item in inventory.Inventory do
			slots += 1
			if item.Name == nametagName then
				existingId, existing = id, item
			end
		end
		local limits = require(Shared.Configuration.InventoryLimits)
		if not existing and slots >= limits.Storage.Nametags then
			return false, "InventoryFull"
		end
		local spent = Knit.GetService("CurrencyService"):TrySpendAsync(player, "BobaBucks", price)
		if not spent then
			return false, "InsufficientFunds"
		end
		local granted = false
		local current = if existingId then inventory:GetItemFromId(existingId) else nil
		if current then
			local previousCount = current:GetStackCount()
			local grantCallOk, grantError = pcall(function()
				current:SetStackCount(previousCount + 1)
			end)
			if not grantCallOk then
				warn(
					"[CapsuleService]: Deterministic Nametag stack update threw after charging",
					player.Name,
					grantError
				)
			end
			local updated = inventory:GetItemFromId(existingId)
			granted = updated ~= nil and updated:GetStackCount() == previousCount + 1
		end
		if not granted then
			local grantCallOk, insertedId = pcall(function()
				return inventory:Insert({ Name = nametagName })
			end)
			if not grantCallOk then
				warn(
					"[CapsuleService]: Deterministic Nametag fallback grant threw after charging",
					player.Name,
					insertedId
				)
			end
			granted = grantCallOk and insertedId ~= nil
		end
		if granted then
			return true
		end
		local refunded = refundBobaBucks(player, price)
		return false, if refunded then "GrantFailed" else "RefundPending"
	end)
end

local function resolveCapsuleMinTier(capsuleName: string, capsuleDef: any): string?
	if capsuleDef and typeof(capsuleDef.MinTier) == "string" then
		return capsuleDef.MinTier
	end

	-- Fallback for misconfigured capsules: infer tier from the capsule's name.
	for tierNameRaw, _ in InventoryItemDefinitions.Tiers do
		local tierName = tostring(tierNameRaw)
		if string.find(string.lower(capsuleName), string.lower(tierName), 1, true) then
			return tierName
		end
	end

	return nil
end

-- Seconds this player has been online in the current session.
local function currentSessionElapsed(player: Player): number
	local start = sessionStarts[player.UserId]
	return start and (os.time() - start) or 0
end

-- Checks all pending hatches for the player and completes any whose total
-- active playtime (stored + current session) has reached HATCH_DURATION.
-- The reward is chosen here, after the waiting period.
local function completePendingHatches(player: Player, extraElapsed: number): (boolean, string?)
	return withPlayerTransaction(player, function()
		local dataOk, playerData = getDataService():GetDataAsync(player):await()
		if not dataOk or not playerData then
			warn("[CapsuleService]: Failed to get data for pending hatch", player.Name)
			return false, "DataUnavailable"
		end

		local playerDataAny: any = playerData
		local hatchData = playerDataAny.HatchingPet

		-- Legacy migration path from old keyed table format.
		if hatchData == nil or hatchData == false then
			local legacyHatching = playerDataAny.HatchingPets
			if legacyHatching then
				local _, legacyPending = next(legacyHatching)
				if legacyPending then
					hatchData = legacyPending
					playerDataAny:SetValue({ "HatchingPet" }, legacyPending)
					playerDataAny:SetValue({ "HatchingPets" }, nil)
				end
			end
		end

		if not hatchData or hatchData == false then
			return false, "NoHatchPending"
		end

		if hatchData.TimeAccumulated + extraElapsed < HATCH_DURATION then
			return false, "HatchNotReady"
		end

		-- Give legacy pending hatches a durable identity before attempting a grant.
		-- This lets a retry recognize only the pet written by this hatch.
		local hatchId = hatchData.HatchId
		if typeof(hatchId) ~= "string" or hatchId == "" then
			hatchId = HttpService:GenerateGUID(false)
			local updatedHatchData = table.clone(hatchData)
			updatedHatchData.HatchId = hatchId
			playerDataAny:SetValue({ "HatchingPet" }, updatedHatchData)
			hatchData = updatedHatchData
		end

		local Inventory = require(ReplicatedStorage.Shared.Inventory)
		local inventoryOk, petsInventory = Inventory:GetPlayerInventoryAsync(player, "Pets"):await()
		if not inventoryOk or not petsInventory then
			warn("[CapsuleService]: Failed to load pet inventory for ready hatch", player.Name)
			return false, "PetInventoryUnavailable"
		end

		local function hasHatchId(item)
			local properties = item:GetProperties()
			return typeof(properties) == "table" and properties.CapsuleHatchId == hatchId
		end

		local function findHatchPet(inventoryToCheck)
			for itemId, item in inventoryToCheck.Inventory do
				if hasHatchId(item) then
					return itemId, item
				end
			end
			return nil, nil
		end

		-- Retry recovery uses the durable hatch identity, never a pet's name/tier.
		local rewardId, rewardItem = findHatchPet(petsInventory)
		local insertError = nil
		if not rewardId then
			-- Pick the reward now, after the waiting period.
			local capsuleDef = InventoryItemDefinitions.Capsules[hatchData.CapsuleName]
			local minTier = if typeof(hatchData.MinTier) == "string"
				then hatchData.MinTier
				else resolveCapsuleMinTier(hatchData.CapsuleName, capsuleDef)

			local reward = CapsuleUtil.pickWeightedRandom("Pets", minTier)
			if not reward then
				warn("[CapsuleService]: No valid reward for capsule", hatchData.CapsuleName)
				return false, "RewardUnavailable"
			end

			local insertOk, insertedId = pcall(function()
				return petsInventory:Insert({
					Name = reward.Name,
					Tier = reward.Tier,
					Properties = { CapsuleHatchId = hatchId },
				})
			end)
			if not insertOk then
				insertError = tostring(insertedId)
			end

			if insertOk and insertedId then
				local insertedItem = petsInventory:GetItemFromId(insertedId)
				if insertedItem and hasHatchId(insertedItem) then
					rewardId = insertedId
					rewardItem = insertedItem
				end
			end

			if not rewardId then
				-- Insert may throw after writing the profile. Reload and recover only the
				-- exact item carrying this hatch's unique identity.
				local verifyOk, verifiedInventory = Inventory:GetPlayerInventoryAsync(player, "Pets"):await()
				if verifyOk and verifiedInventory then
					rewardId, rewardItem = findHatchPet(verifiedInventory)
				end
			end
			if not rewardId or not rewardItem then
				warn(
					"[CapsuleService]: Pet reward insertion failed; keeping hatch pending for",
					player.Name,
					insertError or "inventory full"
				)
				return false, "RewardInsertFailed"
			end
			if not insertOk or not insertedId then
				warn("[CapsuleService]: Pet insertion wrote hatch-tagged reward; completing pending hatch", player.Name)
			end
		end

		local capsuleDef = InventoryItemDefinitions.Capsules[hatchData.CapsuleName]
		local reward = { Name = rewardItem.Name, Tier = rewardItem.Tier }

		playerDataAny:SetValue({ "HatchingPet" }, false)
		local payload = {
			CapsuleImage = capsuleDef and capsuleDef.Image or DEFAULT_CAPSULE_IMAGE,
			Reward = reward,
			ItemType = "Pets",
			IsInstant = false,
		}

		CapsuleService.Client.HatchCapsule:Fire(player, payload)
		getDialogService():CreateDialog(player, "CapsuleOpening", { Capsule = payload }):catch(function(err)
			warn("[CapsuleService]: Failed to create capsule dialog for", player.Name, err)
		end)
		return true
	end)
end

-- Writes accumulated online time back to storage for all pending hatches.
-- Called when a player leaves so progress is not lost.
local function flushAccumulatedTime(player: Player, elapsed: number)
	getDataService()
		:GetDataAsync(player)
		:andThen(function(playerData)
			local playerDataAny: any = playerData
			local hatchData = playerDataAny.HatchingPet
			if not hatchData or hatchData == false then
				return
			end
			playerDataAny:SetValue({ "HatchingPet" }, {
				CapsuleName = hatchData.CapsuleName,
				MinTier = hatchData.MinTier,
				TimeAccumulated = hatchData.TimeAccumulated + elapsed,
				HatchId = hatchData.HatchId,
			})
		end)
		:catch(function(err)
			warn("[CapsuleService]: Failed to flush hatch time for", player.Name, err)
		end)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

-- Called by ItemActions when a pet capsule is hatched.
-- capsuleId is the server-owned inventory ID; this method consumes it after a successful grant/start.
-- capsuleName is the item definition name (e.g. "Regular Pet Capsule").
-- Returns false if the player already has a pending pet hatch (1 at a time limit).
function CapsuleService:StartHatch(
	player: Player,
	capsuleId: string,
	capsuleName: string,
	randomSource: string?
): boolean
	local ok = withPlayerTransaction(player, function()
		local capsuleDef = InventoryItemDefinitions.Capsules[capsuleName]

		if randomSource ~= "FreeEarned" then
			local policyOk, restricted = self:GetPaidRandomPolicy(player)
			if not policyOk or restricted then
				return false, "PolicyUnavailableOrRestricted"
			end
		end

		-- Non-pet capsules are always instant; CapsuleService only manages pet hatches.
		if not capsuleDef or capsuleDef.ItemType ~= "Pets" then
			local Inventory = require(ReplicatedStorage.Shared.Inventory)
			local targetType = capsuleDef and capsuleDef.ItemType or "Pets"
			local minTier = if targetType == "Pets" then resolveCapsuleMinTier(capsuleName, capsuleDef) else nil
			local reward = CapsuleUtil.pickWeightedRandom(targetType, minTier)
			if not reward then
				return false, "NoReward"
			end
			local inventoryOk, inv = Inventory:GetPlayerInventoryAsync(player, targetType):await()
			if not inventoryOk or not inv then
				return false, "RewardInventoryUnavailable"
			end
			local rewardId = inv:Insert({ Name = reward.Name, Tier = reward.Tier })
			if not rewardId then
				return false, "RewardGrantFailed"
			end
			if not consumeCapsule(player, capsuleId) then
				local rollbackOk, rollbackError = pcall(function()
					inv:_removeItemById(rewardId)
				end)
				warn(
					"[CapsuleService]: Capsule consumption failed; reward rollback result:",
					player.Name,
					rewardId,
					rollbackOk,
					rollbackError
				)
				return false, "CapsuleConsumeFailed"
			end
			local payload = {
				CapsuleImage = capsuleDef and capsuleDef.Image or DEFAULT_CAPSULE_IMAGE,
				Reward = reward,
				ItemType = targetType,
				IsInstant = true,
			}
			CapsuleService.Client.HatchCapsule:Fire(player, payload)
			getDialogService():CreateDialog(player, "CapsuleOpening", { Capsule = payload }):catch(function(err)
				warn("[CapsuleService]: Failed to create capsule dialog for", player.Name, err)
			end)
			return true
		end

		-- Enforce the one-at-a-time pet hatch limit.
		local alreadyHatching = false
		local hatchStarted = false
		getDataService()
			:GetDataAsync(player)
			:andThen(function(playerData)
				local playerDataAny: any = playerData
				local hatchData = playerDataAny.HatchingPet
				local minTier = resolveCapsuleMinTier(capsuleName, capsuleDef)

				-- Legacy migration path from old keyed table format.
				if hatchData == nil or hatchData == false then
					local legacyHatching = playerDataAny.HatchingPets
					if legacyHatching then
						local _, legacyPending = next(legacyHatching)
						if legacyPending then
							hatchData = legacyPending
							playerDataAny:SetValue({ "HatchingPet" }, legacyPending)
							playerDataAny:SetValue({ "HatchingPets" }, nil)
						end
					end
				end

				if hatchData and hatchData ~= false then
					alreadyHatching = true
					return
				end
				playerDataAny:SetValue({ "HatchingPet" }, {
					CapsuleName = capsuleName,
					MinTier = minTier,
					TimeAccumulated = 0,
					HatchId = HttpService:GenerateGUID(false),
				})
				hatchStarted = true
			end)
			:catch(function(err)
				warn("[CapsuleService]: Failed to start hatch for", player.Name, err)
			end)
			:await()

		if alreadyHatching then
			warn("[CapsuleService]: Player", player.Name, "already has a pet hatch in progress")
			return false, "HatchAlreadyPending"
		end
		if not hatchStarted then
			return false, "HatchDataUnavailable"
		end

		if not consumeCapsule(player, capsuleId) then
			local rollbackOk, rollbackError = pcall(function()
				local _, playerData = getDataService():GetDataAsync(player):await()
				if not playerData then
					error("player data unavailable")
				end
				playerData:SetValue({ "HatchingPet" }, false)
			end)
			if not rollbackOk then
				warn(
					"[CapsuleService]: Failed to roll back pending hatch after capsule consumption failure",
					player.Name,
					rollbackError
				)
			end
			return false, "CapsuleConsumeFailed"
		end
		return true
	end)
	return ok
end

-- Returns the remaining active-play seconds for a player's current pet hatch,
-- or nil if no hatch is pending.
function CapsuleService:GetHatchTimeRemaining(player: Player): number?
	local _, playerData = getDataService():GetDataAsync(player):await()
	if not playerData then
		return nil
	end
	local hatchData = playerData.HatchingPet

	-- Legacy migration path from old keyed table format.
	if hatchData == nil or hatchData == false then
		local legacyHatching = playerData.HatchingPets
		if legacyHatching then
			local _, legacyPending = next(legacyHatching)
			if legacyPending then
				hatchData = legacyPending
				playerData:SetValue({ "HatchingPet" }, legacyPending)
				playerData:SetValue({ "HatchingPets" }, nil)
			end
		end
	end

	if not hatchData or hatchData == false then
		return nil
	end
	local elapsed = currentSessionElapsed(player)
	local remaining = HATCH_DURATION - (hatchData.TimeAccumulated + elapsed)
	return math.max(0, remaining)
end

-- Client hint to complete a hatch immediately once local countdown reaches zero.
-- Rejects early calls and rate-limits rapid spamming.
function CapsuleService:TryCompleteReadyHatch(player: Player): (boolean, string?)
	local now = os.time()
	local last = hatchDebounces[player.UserId] or 0
	if now - last < 1 then
		return false, "RateLimited"
	end
	hatchDebounces[player.UserId] = now

	return completePendingHatches(player, currentSessionElapsed(player))
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function CapsuleService:PlayerAdded(player: Player)
	-- Record session start BEFORE checking, so getElapsedForPlayer is valid
	-- for any subsequent periodic checks this session.
	sessionStarts[player.UserId] = os.time()
	task.spawn(function()
		withPlayerTransaction(player, function()
			local refundSettled = retryPendingBobaBucksRefund(player)
			return refundSettled, if refundSettled then nil else "RefundPending"
		end)
		-- On join, only previously-accumulated time is checked (current session = 0).
		completePendingHatches(player, 0)
	end)
end

function CapsuleService:PlayerRemoving(player: Player)
	local elapsed = currentSessionElapsed(player)
	sessionStarts[player.UserId] = nil
	playerTransactions[player.UserId] = nil
	hatchDebounces[player.UserId] = nil
	-- Persist progress; completion will happen on the next login or server check.
	flushAccumulatedTime(player, elapsed)
end

function CapsuleService:KnitStart()
	Knit.GetService("ShiftService").ShiftEnding:Connect(function(player, summary)
		if not summary.First then
			return
		end

		task.spawn(function()
			local ok, err = pcall(function()
				if player.Parent ~= Players then
					return
				end

				local _, playerData = getDataService():GetDataAsync(player):await()
				if not playerData or player.Parent ~= Players then
					return
				end

				local inventoryModule = require(Shared.Inventory)
				local inventoryOk, capsulesInventory =
					inventoryModule:GetPlayerInventoryAsync(player, "Capsules"):await()
				if not inventoryOk or not capsulesInventory or player.Parent ~= Players then
					warn("[CapsuleService]: Could not get capsule inventory for starter reward", player.Name)
					return
				end

				local redeemed = playerData.Data.Inventory.FreeItemsRedeemed
				if typeof(redeemed) ~= "table" then
					warn("[CapsuleService]: Invalid free-item redemption data for starter reward", player.Name)
					return
				end
				if table.find(redeemed, STARTER_CAPSULE_REDEEMED) then
					return
				end

				local capsuleCount = 0
				for _ in capsulesInventory.Inventory do
					capsuleCount += 1
				end
				local inventoryLimits = require(Shared.Configuration.InventoryLimits)
				if capsuleCount >= inventoryLimits.Storage.Capsules then
					warn("[CapsuleService]: Capsule inventory is full; starter reward not claimed", player.Name)
					return
				end

				-- Mark first to guard against duplicate ShiftEnding delivery; roll back
				-- when Insert reports its known non-mutating failure cases.
				local updatedRedeemed = table.clone(redeemed)
				table.insert(updatedRedeemed, STARTER_CAPSULE_REDEEMED)
				playerData:SetValue({ "Inventory", "FreeItemsRedeemed" }, updatedRedeemed)

				local itemId = capsulesInventory:Insert({
					Name = "Regular Pet Capsule",
					Properties = { RandomSource = "FreeEarned" },
				})
				if itemId == nil then
					playerData:SetValue({ "Inventory", "FreeItemsRedeemed" }, redeemed)
					warn("[CapsuleService]: Failed to insert starter capsule", player.Name)
				end
			end)
			if not ok then
				warn("[CapsuleService]: Starter capsule grant failed", player.Name, err)
			end
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				completePendingHatches(player, currentSessionElapsed(player))
			end
		end
	end)
end

return CapsuleService

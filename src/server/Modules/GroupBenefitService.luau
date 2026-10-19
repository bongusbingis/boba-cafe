--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local Inventory = require(Shared.Inventory)

local GROUP_ID = 3174578
local GROUP_PET_REWARD = "GroupPet"
local GROUP_PET_PENDING_PREFIX = "GroupPetPending:"
local GROUP_PET_CLAIM_PROPERTY = "GroupPetClaimId"
local DATA_TIMEOUT_SECONDS = 10
local claimsInProgress: { [number]: boolean } = {}

local GroupBenefitService = Knit.CreateService({
	Name = "GroupBenefitService",
	Client = {
		GetClaimStatusAsync = function(self, player: Player)
			return self.Server:GetClaimStatusAsync(player)
		end,
		ClaimAntPetAsync = function(self, player: Player)
			return self.Server:ClaimAntPetAsync(player)
		end,
	},
})

function GroupBenefitService:GetClaimStatusAsync(player: Player): string
	local dataOk, playerData = Knit.GetService("DataService"):GetDataAsync(player):timeout(DATA_TIMEOUT_SECONDS):await()

	if not dataOk or not playerData then
		return "Retry"
	end

	if table.find(playerData.Data.Inventory.FreeItemsRedeemed, GROUP_PET_REWARD) then
		return "Claimed"
	end

	return "Available"
end

local function findPendingClaimId(redeemed: { string }): string?
	for _, rewardId in redeemed do
		if string.sub(rewardId, 1, #GROUP_PET_PENDING_PREFIX) == GROUP_PET_PENDING_PREFIX then
			return rewardId
		end
	end
	return nil
end

local function findTaggedClaimId(data: any): string?
	for _, pet in data.Inventory.Items.Pets do
		local claimId = pet.Properties and pet.Properties[GROUP_PET_CLAIM_PROPERTY]
		if
			typeof(claimId) == "string"
			and string.sub(claimId, 1, #GROUP_PET_PENDING_PREFIX) == GROUP_PET_PENDING_PREFIX
		then
			return claimId
		end
	end
	return nil
end

local function hasPendingClaim(data: any, claimId: string): boolean
	local redeemed = data.Inventory.FreeItemsRedeemed
	return table.find(redeemed, claimId) ~= nil
end

local function hasClaimedMarker(data: any): boolean
	return table.find(data.Inventory.FreeItemsRedeemed, GROUP_PET_REWARD) ~= nil
end

local function hasPendingPet(data: any, claimId: string): boolean
	for _, pet in data.Inventory.Items.Pets do
		if pet.Properties and pet.Properties[GROUP_PET_CLAIM_PROPERTY] == claimId then
			return true
		end
	end
	return false
end

local function findPendingPet(petsInventory: any, claimId: string): any?
	for _, pet in petsInventory.Inventory do
		if pet:GetProperty(GROUP_PET_CLAIM_PROPERTY) == claimId then
			return pet
		end
	end
	return nil
end

local function saveConfirmed(player: Player, predicate: (any) -> boolean): boolean
	local saveCallOk, saved = Knit.GetService("DataService"):SaveAsync(player, predicate):await()
	return saveCallOk and saved == true
end

function GroupBenefitService:ClaimAntPetAsync(player: Player): string
	if claimsInProgress[player.UserId] then
		return "Retry"
	end
	claimsInProgress[player.UserId] = true

	local callOk, result = pcall(function(): string
		local dataOk, playerData =
			Knit.GetService("DataService"):GetDataAsync(player):timeout(DATA_TIMEOUT_SECONDS):await()

		if not dataOk or not playerData then
			return "Retry"
		end

		if table.find(playerData.Data.Inventory.FreeItemsRedeemed, GROUP_PET_REWARD) then
			return "Claimed"
		end

		local membershipOk, isMember = pcall(player.IsInGroupAsync, player, GROUP_ID)
		if not membershipOk or not isMember then
			return "NotMember"
		end

		local currentRedeemed = playerData.Data.Inventory.FreeItemsRedeemed
		if table.find(currentRedeemed, GROUP_PET_REWARD) then
			return "Claimed"
		end

		local claimId = findPendingClaimId(currentRedeemed) or findTaggedClaimId(playerData.Data)
		if not claimId then
			claimId = GROUP_PET_PENDING_PREFIX .. HttpService:GenerateGUID(false)
		end

		-- Compose against the live profile immediately before this synchronous
		-- write; other services also update FreeItemsRedeemed across yields.
		currentRedeemed = playerData.Data.Inventory.FreeItemsRedeemed
		if not table.find(currentRedeemed, claimId) then
			local withPending = table.clone(currentRedeemed)
			table.insert(withPending, claimId)
			playerData:SetValue({ "Inventory", "FreeItemsRedeemed" }, withPending)
		end

		local intentSaved = saveConfirmed(player, function(savedData)
			return hasPendingClaim(savedData, claimId)
		end)
		if not intentSaved then
			return "Retry"
		end

		local inventoryOk, petsInventory =
			Inventory:GetPlayerInventoryAsync(player, "Pets"):timeout(DATA_TIMEOUT_SECONDS):await()
		if not inventoryOk or not petsInventory then
			return "Retry"
		end

		local pet = findPendingPet(petsInventory, claimId)
		if not pet then
			local itemId = petsInventory:Insert({
				Name = "Ant Pet",
				Tier = "Basic",
				Equipped = false,
				Properties = { [GROUP_PET_CLAIM_PROPERTY] = claimId },
			})
			if not itemId then
				return "Retry"
			end
		end

		-- Persist the tagged pet while its durable pending intent still exists. If
		-- this save is interrupted, a retry can find the same claim ID and resume.
		local petAndIntentSaved = saveConfirmed(player, function(savedData)
			return hasPendingClaim(savedData, claimId) and hasPendingPet(savedData, claimId)
		end)
		if not petAndIntentSaved then
			return "Retry"
		end

		-- Read the live list after the preceding save yield so unrelated markers
		-- (for example StarterCapsule) are retained in this update.
		local updatedRedeemed = table.clone(playerData.Data.Inventory.FreeItemsRedeemed)
		local pendingIndex = table.find(updatedRedeemed, claimId)
		if pendingIndex then
			table.remove(updatedRedeemed, pendingIndex)
		end
		local addedGroupPetMarker = not table.find(updatedRedeemed, GROUP_PET_REWARD)
		if addedGroupPetMarker then
			table.insert(updatedRedeemed, GROUP_PET_REWARD)
		end
		playerData:SetValue({ "Inventory", "FreeItemsRedeemed" }, updatedRedeemed)

		local finalized = saveConfirmed(player, function(savedData)
			return hasClaimedMarker(savedData)
				and not hasPendingClaim(savedData, claimId)
				and hasPendingPet(savedData, claimId)
		end)
		if not finalized then
			-- Return to the last confirmed durable state so a subsequent request
			-- resumes from the pending intent instead of treating an unconfirmed
			-- marker as complete.
			-- Roll back only our finalization against the current list. Do not put
			-- back an older snapshot that could erase another service's marker.
			local rollbackRedeemed = table.clone(playerData.Data.Inventory.FreeItemsRedeemed)
			if addedGroupPetMarker then
				local groupPetIndex = table.find(rollbackRedeemed, GROUP_PET_REWARD)
				if groupPetIndex then
					table.remove(rollbackRedeemed, groupPetIndex)
				end
			end
			if not table.find(rollbackRedeemed, claimId) then
				table.insert(rollbackRedeemed, claimId)
			end
			playerData:SetValue({ "Inventory", "FreeItemsRedeemed" }, rollbackRedeemed)
			return "Retry"
		end

		return "Claimed"
	end)

	claimsInProgress[player.UserId] = nil
	if not callOk then
		warn("[GroupBenefitService] Ant Pet claim failed:", result)
		return "Retry"
	end

	return result
end

function GroupBenefitService:PlayerRemoving(player: Player)
	claimsInProgress[player.UserId] = nil
end

return GroupBenefitService

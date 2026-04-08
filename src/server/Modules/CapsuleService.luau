--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)

local CapsuleConfig = require(Shared.Configuration.CapsuleConfig)
local CapsuleUtil = require(Shared.Inventory.CapsuleUtil)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)

local HATCH_DURATION = CapsuleConfig.PET_HATCH_DURATION
local DEFAULT_CAPSULE_IMAGE = "rbxassetid://6073658218"

-- Tracks the os.time() at which each player's current session began.
-- Only online players appear in this table.
local sessionStarts: { [number]: number } = {}

local CapsuleService = Knit.CreateService {
	Name = "CapsuleService",
	Client = {
		HatchCapsule = Knit.CreateSignal(),
		TryCompleteReadyHatch = function(self, player: Player)
			return self.Server:TryCompleteReadyHatch(player)
		end,
	},
}

--------------------------------------------------------------------------------
-- Private
--------------------------------------------------------------------------------

local function getDataService()
	return Knit.GetService("DataService")
end

local function getDialogService()
	return Knit.GetService("DialogService")
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
local function completePendingHatches(player: Player, extraElapsed: number)
	getDataService():GetDataAsync(player)
		:andThen(function(playerData)
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
				return
			end

			if hatchData.TimeAccumulated + extraElapsed < HATCH_DURATION then
				return
			end

			local Inventory = require(ReplicatedStorage.Shared.Inventory)
			Inventory:GetPlayerInventoryAsync(player, "Pets")
				:andThen(function(petsInventory)
					-- Pick the reward now, after the waiting period.
					local capsuleDef = InventoryItemDefinitions.Capsules[hatchData.CapsuleName]
					local minTier = if typeof(hatchData.MinTier) == "string"
						then hatchData.MinTier
						else resolveCapsuleMinTier(hatchData.CapsuleName, capsuleDef)

					local reward = CapsuleUtil.pickWeightedRandom("Pets", minTier)
					if not reward then
						warn("[CapsuleService]: No valid reward for capsule", hatchData.CapsuleName)
						playerDataAny:SetValue({ "HatchingPet" }, false)
						return
					end

					petsInventory:Insert({ Name = reward.Name, Tier = reward.Tier })
					playerDataAny:SetValue({ "HatchingPet" }, false)
					local payload = {
						CapsuleImage = capsuleDef and capsuleDef.Image or DEFAULT_CAPSULE_IMAGE,
						Reward = reward,
						ItemType = "Pets",
						IsInstant = false,
					}

					CapsuleService.Client.HatchCapsule:Fire(player, payload)
					getDialogService()
						:CreateDialog(player, "CapsuleOpening", { Capsule = payload })
						:catch(function(err)
							warn("[CapsuleService]: Failed to create capsule dialog for", player.Name, err)
						end)
				end)
				:catch(function(err)
					warn("[CapsuleService]: Failed to complete hatches for", player.Name, err)
				end)
		end)
		:catch(function(err)
			warn("[CapsuleService]: Failed to get data for", player.Name, err)
		end)
end

-- Writes accumulated online time back to storage for all pending hatches.
-- Called when a player leaves so progress is not lost.
local function flushAccumulatedTime(player: Player, elapsed: number)
	getDataService():GetDataAsync(player)
		:andThen(function(playerData)
			local playerDataAny: any = playerData
			local hatchData = playerDataAny.HatchingPet
			if not hatchData or hatchData == false then
				return
			end
			playerDataAny:SetValue({ "HatchingPet" }, {
				CapsuleName = hatchData.CapsuleName,
				TimeAccumulated = hatchData.TimeAccumulated + elapsed,
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
-- capsuleId is the inventory ID of the consumed capsule (used as the hatch key).
-- capsuleName is the item definition name (e.g. "Regular Pet Capsule").
-- Returns false if the player already has a pending pet hatch (1 at a time limit).
function CapsuleService:StartHatch(player: Player, capsuleId: string, capsuleName: string): boolean
	local _capsuleId = capsuleId
	local capsuleDef = InventoryItemDefinitions.Capsules[capsuleName]

	-- Non-pet capsules are always instant; CapsuleService only manages pet hatches.
	if not capsuleDef or capsuleDef.ItemType ~= "Pets" then
		local Inventory = require(ReplicatedStorage.Shared.Inventory)
		local targetType = capsuleDef and capsuleDef.ItemType or "Pets"
		local minTier = if targetType == "Pets" then resolveCapsuleMinTier(capsuleName, capsuleDef) else nil
		local reward = CapsuleUtil.pickWeightedRandom(targetType, minTier)
		if reward then
			Inventory:GetPlayerInventoryAsync(player, targetType)
				:andThen(function(inv)
					inv:Insert({ Name = reward.Name, Tier = reward.Tier })
					local payload = {
						CapsuleImage = capsuleDef and capsuleDef.Image or DEFAULT_CAPSULE_IMAGE,
						Reward = reward,
						ItemType = targetType,
						IsInstant = true,
					}

					CapsuleService.Client.HatchCapsule:Fire(player, payload)
					getDialogService()
						:CreateDialog(player, "CapsuleOpening", { Capsule = payload })
						:catch(function(err)
							warn("[CapsuleService]: Failed to create capsule dialog for", player.Name, err)
						end)
				end)
				:catch(warn)
		end
		return true
	end

	-- Enforce the one-at-a-time pet hatch limit.
	local alreadyHatching = false
	getDataService():GetDataAsync(player)
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
			})
		end)
		:catch(function(err)
			warn("[CapsuleService]: Failed to start hatch for", player.Name, err)
		end)
		:await()

	if alreadyHatching then
		warn("[CapsuleService]: Player", player.Name, "already has a pet hatch in progress")
		return false
	end

	return true
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
-- Safe to call repeatedly; completion only happens when ready.
function CapsuleService:TryCompleteReadyHatch(player: Player)
	completePendingHatches(player, currentSessionElapsed(player))
	return true
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function CapsuleService:PlayerAdded(player: Player)
	-- Record session start BEFORE checking, so getElapsedForPlayer is valid
	-- for any subsequent periodic checks this session.
	sessionStarts[player.UserId] = os.time()
	-- On join, only previously-accumulated time is checked (current session = 0).
	completePendingHatches(player, 0)
end

function CapsuleService:PlayerRemoving(player: Player)
	local elapsed = currentSessionElapsed(player)
	sessionStarts[player.UserId] = nil
	-- Persist progress; completion will happen on the next login or server check.
	flushAccumulatedTime(player, elapsed)
end

function CapsuleService:KnitStart()
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

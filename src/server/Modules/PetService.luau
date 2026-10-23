--!strict

local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local InventoryServer = require(Shared.Inventory.InventoryServer)
local PetConfig = require(Shared.Configuration.PetConfig)
local PerkConfig = require(Shared.Configuration.Perks)
local PetShared = require(Shared.Pets.PetShared)

type EquippedPetSnapshot = PetShared.EquippedPetSnapshot

local equippedPetsByUserId: { [number]: { EquippedPetSnapshot } } = {}
local inventoryConnections: { [number]: any } = {}

local PetService = Knit.CreateService({
	Name = "PetService",
	_equipped = equippedPetsByUserId, -- same table; test seam for GetBestTipBonus
	Client = {
		EquippedPetsChanged = Knit.CreateSignal(),

		GetAllEquippedPetsAsync = function(_self, _player: Player): { [number]: { EquippedPetSnapshot } }
			local snapshot = {}
			for userId, equippedPets in equippedPetsByUserId do
				snapshot[userId] = table.clone(equippedPets)
			end
			return snapshot
		end,
	},
})

local function buildEquippedSnapshot(proxy: any): { EquippedPetSnapshot }
	local equipped = {}
	local items = proxy and proxy.Inventory and proxy.Inventory.Items and proxy.Inventory.Items.Pets
	if not items then
		return equipped
	end

	for itemId, itemData in items do
		if itemData.Equipped == true then
			table.insert(equipped, {
				ItemId = itemId,
				Name = itemData.Name,
				DisplayName = PetShared.ResolveDisplayName(itemData.Name, itemData.Properties),
				Tier = itemData.Tier,
			})
		end
	end

	table.sort(equipped, function(a, b)
		return a.ItemId < b.ItemId
	end)

	if #equipped > 1 then
		return { equipped[1] }
	end

	return equipped
end

local function publishForPlayer(player: Player, proxy: any)
	local equippedSnapshot = buildEquippedSnapshot(proxy)
	equippedPetsByUserId[player.UserId] = equippedSnapshot
	PetService.Client.EquippedPetsChanged:FireAll(player.UserId, equippedSnapshot)
end

local function filterPetName(player: Player, rawName: string): (boolean, string?, string?)
	local trimmed = PetShared.TrimName(rawName)
	if trimmed == "" then
		return true, nil, nil
	end

	if #trimmed > PetConfig.MAX_RENAME_LENGTH then
		return false, nil, string.format("Pet name must be %d characters or less.", PetConfig.MAX_RENAME_LENGTH)
	end

	local okFilter, filterResult = pcall(function()
		return TextService:FilterStringAsync(trimmed, player.UserId)
	end)
	if not okFilter or not filterResult then
		return false, nil, "Failed to validate pet name."
	end

	local okBroadcast, broadcastText = pcall(function()
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if not okBroadcast or typeof(broadcastText) ~= "string" then
		return false, nil, "Failed to validate pet name."
	end

	broadcastText = PetShared.TrimName(broadcastText)
	if broadcastText == "" or broadcastText ~= trimmed then
		return false, nil, "Pet name contains filtered content."
	end

	return true, broadcastText, nil
end

function PetService:SetupPlayerPets(player: Player, proxy: any)
	local existingConnection = inventoryConnections[player.UserId]
	if existingConnection then
		existingConnection:Disconnect()
		inventoryConnections[player.UserId] = nil
	end

	publishForPlayer(player, proxy)

	local signal = InventoryServer:GetPlayerChangeSignal(player)
	if signal then
		inventoryConnections[player.UserId] = signal:Connect(function(changeData)
			if not changeData or changeData.itemsType ~= "Pets" then
				return
			end

			publishForPlayer(player, proxy)
		end)
	end
end

function PetService:RenamePet(player: Player, item: any, requestedName: string): (boolean, string?)
	if typeof(requestedName) ~= "string" then
		return false, "Invalid pet name."
	end

	if typeof(item) ~= "table" or typeof(item.GetType) ~= "function" or item:GetType() ~= "Pets" then
		return false, "Invalid pet item."
	end

	local ok, filteredName, reason = filterPetName(player, requestedName)
	if not ok then
		return false, reason
	end

	if filteredName == nil then
		item:ClearProperty(PetConfig.RENAME_PROPERTY_KEY)
		return true, nil
	end

	item:SetProperty(PetConfig.RENAME_PROPERTY_KEY, filteredName)
	return true, nil
end

-- Highest tip bonus among the player's equipped pets (DEC-028 E21); unknown tier = 0.
function PetService:GetBestTipBonus(player: Player): number
	local best = 0
	for _, pet in equippedPetsByUserId[player.UserId] or {} do
		local bonus = PerkConfig.PetTipBonus[pet.Tier]
		if bonus ~= nil and bonus > best then
			best = bonus
		end
	end
	return best
end

-- Moderation: clears custom pet names on the owner's pets. When `petIdentifier`
-- is nil every renamed pet is reset; otherwise only the pet whose ItemId or
-- current display name matches (case-insensitive). Returns (resetCount, oldNames).
-- The inventory change signal updates equipped overheads live.
function PetService:ResetPetNames(owner: Player, petIdentifier: any): (number, { string })
	if typeof(owner) ~= "Instance" or not owner:IsA("Player") then
		return 0, {}
	end
	local ok, inventory = pcall(function()
		return InventoryServer:GetPlayerInventoryAsync(owner, "Pets"):await()
	end)
	if not ok or inventory == nil then
		return 0, {}
	end
	local want = if typeof(petIdentifier) == "string" and petIdentifier ~= "" then string.lower(petIdentifier) else nil
	local resetNames = {}
	for _, item in inventory.Inventory do
		if item:GetType() == "Pets" then
			local current = item:GetProperty(PetConfig.RENAME_PROPERTY_KEY)
			if typeof(current) == "string" and PetShared.TrimName(current) ~= "" then
				local display = item:GetDisplayName()
				local matches = want == nil or string.lower(item:GetId()) == want or string.lower(display) == want
				if matches then
					item:ClearProperty(PetConfig.RENAME_PROPERTY_KEY)
					table.insert(resetNames, display)
				end
			end
		end
	end
	return #resetNames, resetNames
end

function PetService:PlayerRemoving(player: Player)
	local existingConnection = inventoryConnections[player.UserId]
	if existingConnection then
		existingConnection:Disconnect()
		inventoryConnections[player.UserId] = nil
	end

	equippedPetsByUserId[player.UserId] = nil
	PetService.Client.EquippedPetsChanged:FireAll(player.UserId, {})
end

return PetService

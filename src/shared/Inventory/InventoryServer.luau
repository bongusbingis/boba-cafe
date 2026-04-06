--!strict
local InventoryServer = { Prototype = {} }

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Networking = ReplicatedStorage:WaitForChild("Networking")
local Components = script.Parent
local InventoryEvent = Networking:WaitForChild("InventoryEvent") :: RemoteEvent

local DataService = require(Server.Modules.DataService)
local Promise = require(Packages.Promise)
local GoodSignal = require(Packages.GoodSignal)
local Janitor = require(Packages.Janitor)

local Utility = require(Components.Utility)
local ItemsMap = require(Components.ItemsMap)
local InventoryItem = require(Components.InventoryItem)
local InventoryShared = require(Components.InventoryShared)
local Types = require(Components.Types)

type InventoryItemRoot = Types.InventoryItemRoot
type OnChangeData = Types.OnChangeData
type ItemType = Types.ItemType
export type InventoryItem = InventoryItem.InventoryItem
export type InventoryTypeRoot = Types.InventoryTypeRoot
export type InventoryItemsRoot = Types.InventoryItemsRoot

export type PlayerInventory = typeof(setmetatable(
	{} :: {
		OnChange: any,
		Inventory: { [string]: InventoryItem },
		Metadata: {
			_player: Player,
			_type: ItemType,
			_item_type_shared_data: { [string]: any },
			_raw_data: InventoryTypeRoot,
			_janitor: any,
		},
	},
	{ __index = InventoryServer.Prototype }
))

local OnChangeSignals: { [number]: any } = {}

local function dispatchChange(player: Player, data: OnChangeData)
	InventoryEvent:FireClient(player, {
		packet = "onChange",
		data = data,
	})
	local signal = OnChangeSignals[player.UserId]
	if signal then
		signal:Fire(data)
	end
end

function InventoryServer.Prototype:_getRawItem(itemId: string): InventoryItemRoot?
	return self.Metadata._raw_data[itemId]
end

function InventoryServer.Prototype:_writeRawItem(itemId: string, itemRoot: InventoryItemRoot?)
	local _, playerData = DataService:GetDataAsync(self.Metadata._player):await()
	playerData:SetValue({ "Inventory", "Items", self.Metadata._type, itemId }, itemRoot)

	if itemRoot == nil then
		self.Metadata._raw_data[itemId] = nil
	else
		self.Metadata._raw_data[itemId] = itemRoot
	end
end

function InventoryServer.Prototype:_rebuildItem(itemId: string)
	local rawItem = self:_getRawItem(itemId)
	if rawItem == nil then
		self.Inventory[itemId] = nil
		return
	end

	self.Inventory[itemId] = InventoryItem(self.Metadata._player, itemId, self.Metadata._type, rawItem, self)
end

function InventoryServer.Prototype:_fireChanged(action: Types.ChangeAction, itemId: string)
	dispatchChange(self.Metadata._player, {
		action = action,
		itemId = itemId,
		itemsType = self.Metadata._type,
	})
end

function InventoryServer.Prototype:_removeItemById(itemId: string)
	if self.Inventory[itemId] == nil then
		return
	end

	self:_writeRawItem(itemId, nil)
	self.Inventory[itemId] = nil
	self:_fireChanged("removed", itemId)
end

function InventoryServer.Prototype:_setItemProperty(itemId: string, key: string, value: any)
	local rawItem = self:_getRawItem(itemId)
	if rawItem == nil then
		return
	end

	rawItem.Properties = rawItem.Properties or {}
	rawItem.Properties[key] = value
	self:_writeRawItem(itemId, rawItem)
	self:_rebuildItem(itemId)
	self:_fireChanged("updated", itemId)
end

function InventoryServer.Prototype:_setStackCount(itemId: string, amount: number)
	assert(amount >= 1, "Stack count must be at least 1")
	local rawItem = self:_getRawItem(itemId)
	if rawItem == nil then
		return
	end

	rawItem.StackCount = amount
	self:_writeRawItem(itemId, rawItem)
	self:_rebuildItem(itemId)
	self:_fireChanged("updated", itemId)
end

function InventoryServer.Prototype:_setEquipped(itemId: string, equipped: boolean)
	local rawItem = self:_getRawItem(itemId)
	if rawItem == nil then
		return
	end

	if equipped then
		local equippedItems, equippedCount = self:GetEquippedItems()
		local maxEquipped = Utility.GetInventoryLimit("Equipped", self.Metadata._type)
		if equippedCount >= maxEquipped then
			local _, firstEquipped = next(equippedItems)
			if firstEquipped then
				firstEquipped:Unequip()
			end
		end
	end

	rawItem.Equipped = equipped
	self:_writeRawItem(itemId, rawItem)
	self:_rebuildItem(itemId)
	self:_fireChanged("equipped", itemId)
end

function InventoryServer.Prototype:Filter(predicate)
	return InventoryShared.Filter(self, predicate)
end

function InventoryServer.Prototype:GetItems(itemIds, predicate)
	return InventoryShared.GetItems(self, itemIds, predicate)
end

function InventoryServer.Prototype:GetItemFromId(itemId: string)
	return InventoryShared.GetItemFromId(self, itemId)
end

function InventoryServer.Prototype:GetFirstEquippedItem()
	return InventoryShared.GetFirstEquippedItem(self)
end

function InventoryServer.Prototype:GetEquippedItems()
	return InventoryShared.GetEquippedItems(self)
end

function InventoryServer.Prototype:TotalItemsEquipped(): number
	return InventoryShared.TotalItemsEquipped(self)
end

function InventoryServer.Prototype:RemoveItems(itemIds: { string })
	for _, itemId in itemIds do
		self:_removeItemById(itemId)
	end
end

function InventoryServer.Prototype:ListenToChange(callbackFn: (OnChangeData) -> ())
	return self.OnChange:Connect(callbackFn)
end

function InventoryServer.Prototype:Destroy(): ()
	self.Metadata._janitor:Destroy()
	table.clear(self.Inventory)
	table.clear(self)
end

function InventoryServer.Prototype:Insert(itemRootData: InventoryItemRoot): string?
	local success, reason = Utility.ValidateItem("pending-id", self.Metadata._type, itemRootData)
	if not success then
		warn("[InventoryServer]: Failed to insert item because", reason)
		return nil
	end

	local currentStorage = 0
	for _ in self.Metadata._raw_data do
		currentStorage += 1
	end

	if currentStorage >= Utility.GetInventoryLimit("Storage", self.Metadata._type) then
		warn(("[InventoryServer]: %s inventory is full for %s"):format(self.Metadata._player.Name, self.Metadata._type))
		return nil
	end

	local itemId = string.format("%s-%s", itemRootData.Name:lower(), HttpService:GenerateGUID(false))
	local newItem: InventoryItemRoot = {
		Name = itemRootData.Name,
		Tier = itemRootData.Tier,
		Equipped = itemRootData.Equipped == true,
		StackCount = itemRootData.StackCount,
		Properties = Utility.Clone(itemRootData.Properties or {}),
	}

	self:_writeRawItem(itemId, newItem)
	self:_rebuildItem(itemId)
	self:_fireChanged("added", itemId)
	return itemId
end

function InventoryServer:GetPlayerInventoryAsync(player: Player, itemTypeToReturn: ItemType)
	Utility.AssertValidItemType(itemTypeToReturn)

	return Promise.new(function(resolve, reject)
		DataService:GetDataAsync(player)
			:andThen(function(playerData)
				local playerInventoryRoot: InventoryItemsRoot = playerData.Inventory.Items
				local rawTypeRoot = playerInventoryRoot[itemTypeToReturn]
				if rawTypeRoot == nil then
					reject(("Invalid item type %s provided; missing inventory table"):format(itemTypeToReturn))
					return
				end

				local wrapped = {}
				local selfObject: PlayerInventory = setmetatable({
					OnChange = OnChangeSignals[player.UserId],
					Inventory = wrapped,
					Metadata = {
						_player = player,
						_type = itemTypeToReturn,
						_item_type_shared_data = ItemsMap[itemTypeToReturn],
						_raw_data = rawTypeRoot,
						_janitor = Janitor.new(),
					},
				}, { __index = InventoryServer.Prototype })

				for itemId, itemData in rawTypeRoot do
					wrapped[itemId] = InventoryItem(player, itemId, itemTypeToReturn, itemData, selfObject)
				end

				resolve(selfObject)
			end)
			:catch(reject)
	end)
end

if RunService:IsRunning() then
	Players.PlayerAdded:Connect(function(player)
		OnChangeSignals[player.UserId] = GoodSignal.new()
	end)

	Players.PlayerRemoving:Connect(function(player)
		local signal = OnChangeSignals[player.UserId]
		if signal then
			signal:DisconnectAll()
			OnChangeSignals[player.UserId] = nil
		end
	end)

	InventoryEvent.OnServerEvent:Connect(function(player: Player, wireData: any)
		if typeof(wireData) ~= "table" then
			warn("[InventoryServer]: Invalid inventory event payload")
			return
		end

		local packet = wireData.packet
		local data = wireData.data

		if packet == "removeItems" then
			if typeof(data) ~= "table" or typeof(data.itemsType) ~= "string" or typeof(data.items) ~= "table" then
				warn("[InventoryServer]: Invalid removeItems packet")
				return
			end
			if data.itemsType ~= "Nametags" and data.itemsType ~= "Pets" then
				warn("[InventoryServer]: Invalid removeItems item type", data.itemsType)
				return
			end

			local itemType: ItemType = data.itemsType

			InventoryServer:GetPlayerInventoryAsync(player, itemType):andThen(function(inventory)
				inventory:RemoveItems(data.items)
			end)
			return
		end

		if packet == "setItemEquipped" then
			if typeof(data) ~= "table"
				or typeof(data.itemType) ~= "string"
				or typeof(data.itemId) ~= "string"
				or typeof(data.equipped) ~= "boolean"
			then
				warn("[InventoryServer]: Invalid setItemEquipped packet")
				return
			end
			if data.itemType ~= "Nametags" and data.itemType ~= "Pets" then
				warn("[InventoryServer]: Invalid setItemEquipped item type", data.itemType)
				return
			end

			local itemType: ItemType = data.itemType

			InventoryServer:GetPlayerInventoryAsync(player, itemType):andThen(function(inventory)
				local item = inventory:GetItemFromId(data.itemId)
				if item == nil then
					warn("[InventoryServer]: Item not found for equip request", data.itemId)
					return
				end

				if data.equipped then
					item:Equip()
				else
					item:Unequip()
				end
			end)
			return
		end

		if packet == "useItem" then
			if typeof(data) ~= "table"
				or typeof(data.itemType) ~= "string"
				or typeof(data.itemId) ~= "string"
				or typeof(data.actionName) ~= "string"
			then
				warn("[InventoryServer]: Invalid useItem packet")
				return
			end
			if data.itemType ~= "Nametags" and data.itemType ~= "Pets" then
				warn("[InventoryServer]: Invalid useItem item type", data.itemType)
				return
			end

			local itemType: ItemType = data.itemType

			InventoryServer:GetPlayerInventoryAsync(player, itemType):andThen(function(inventory)
				local item = inventory:GetItemFromId(data.itemId)
				if item == nil then
					warn("[InventoryServer]: Item not found for use request", data.itemId)
					return
				end
				item:Use(data.actionName)
			end)
			return
		end

		if packet == "sellItem" then
			if typeof(data) ~= "table"
				or typeof(data.itemType) ~= "string"
				or typeof(data.itemId) ~= "string"
			then
				warn("[InventoryServer]: Invalid sellItem packet")
				return
			end
			if data.itemType ~= "Nametags" and data.itemType ~= "Pets" then
				warn("[InventoryServer]: Invalid sellItem item type", data.itemType)
				return
			end

			local itemType: ItemType = data.itemType

			InventoryServer:GetPlayerInventoryAsync(player, itemType):andThen(function(inventory)
				local item = inventory:GetItemFromId(data.itemId)
				if item == nil then
					warn("[InventoryServer]: Item not found for sell request", data.itemId)
					return
				end
				item:Sell()
			end)
			return
		end
	end)
end

return InventoryServer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local PetConfig = require(Shared.Configuration.PetConfig)
local PetShared = require(Shared.Pets.PetShared)

---> item prototype

local MockItem = {}
MockItem.__index = MockItem

function MockItem:GetId(): string
	return self._id
end

function MockItem:GetType(): string
	return self._type
end

function MockItem:GetDefinition()
	return self._definition
end

function MockItem:GetProperties(): { [string]: any }
	return self._properties
end

function MockItem:GetProperty(key: string): any
	return self._properties[key]
end

function MockItem:IsEquipped(): boolean
	return self._equipped
end

function MockItem:GetStackCount(): number
	return self._stackCount
end

function MockItem:GetDisplayName(): string
	if self._type ~= "Pets" then
		return self.Name
	end

	return PetShared.ResolveDisplayName(self.Name, self._properties)
end

function MockItem:Equip()
	self._equipped = true
end

function MockItem:Unequip()
	self._equipped = false
end

function MockItem:ToggleEquipped()
	self._equipped = not self._equipped
end

function MockItem:Remove()
	-- no-op in studio mock
end

function MockItem:Use()
	-- no-op in studio mock
end

function MockItem:Rename(newName: string)
	if self._type ~= "Pets" then
		return
	end

	local trimmed = PetShared.TrimName(newName)
	if trimmed == "" then
		self._properties[PetConfig.RENAME_PROPERTY_KEY] = nil
	else
		self._properties[PetConfig.RENAME_PROPERTY_KEY] = trimmed
	end
end

---> inventory prototype

local MockInventory = {}
MockInventory.__index = MockInventory

function MockInventory:Filter(predicate)
	local result = {}
	local count = 0
	for id, item in self.Inventory do
		if predicate(item) then
			result[id] = item
			count += 1
		end
	end
	return result, count
end

function MockInventory:GetItems(itemIds, predicate)
	if itemIds == nil then
		if predicate == nil then
			return self.Inventory
		end
		local result = {}
		for id, item in self.Inventory do
			if predicate(item) then
				result[id] = item
			end
		end
		return result
	end

	local result = {}
	for _, id in itemIds do
		local item = self.Inventory[id]
		if item and (predicate == nil or predicate(item)) then
			result[id] = item
		end
	end
	return result
end

function MockInventory:GetItemFromId(itemId: string)
	return self.Inventory[itemId]
end

function MockInventory:GetFirstEquippedItem()
	for _, item in self.Inventory do
		if item:IsEquipped() then
			return item
		end
	end
	return nil
end

function MockInventory:GetEquippedItems()
	return self:Filter(function(item)
		return item:IsEquipped()
	end)
end

function MockInventory:TotalItemsEquipped(): number
	local _, count = self:GetEquippedItems()
	return count
end

function MockInventory:RemoveItems()
	-- no-op in studio mock
end

function MockInventory:Destroy()
	-- no-op in studio mock
end

---> builder

local function mapItemDefinitionsToInventory(itemType: string, items: { string }?)
	local definitions = InventoryItemDefinitions[itemType]
	assert(definitions, ("mapItemDefinitionsToInventory: no definitions for item type '%s'"):format(itemType))

	local inventory = {}

	if items then
		for _, name in items do
			local definition = definitions[name]
			if not definition then
				continue
			end
			local id = HttpService:GenerateGUID(false)
			inventory[id] = setmetatable({
				Name = name,
				Tier = definition.Tier,
				_id = id,
				_type = itemType,
				_definition = definition,
				_equipped = false,
				_stackCount = 1,
				_properties = {},
			}, MockItem)
		end
	else
		for name, definition in definitions do
			local id = HttpService:GenerateGUID(false)
			inventory[id] = setmetatable({
				Name = name,
				Tier = definition.Tier,
				_id = id,
				_type = itemType,
				_definition = definition,
				_equipped = false,
				_stackCount = 1,
				_properties = {},
			}, MockItem)
		end
	end

	-- mock OnChange signal
	local listeners = {}
	local OnChange = {
		Connect = function(_, fn)
			local conn = { fn = fn, Connected = true }
			table.insert(listeners, conn)
			conn.Disconnect = function()
				conn.Connected = false
			end
			return conn
		end,
		Fire = function(_, ...)
			for _, conn in listeners do
				if conn.Connected then
					conn.fn(...)
				end
			end
		end,
		DisconnectAll = function()
			table.clear(listeners)
		end,
	}

	return setmetatable({
		Inventory = inventory,
		OnChange = OnChange,
		Metadata = {
			_type = itemType,
			_item_type_shared_data = InventoryItemDefinitions[itemType],
			_raw_data = {},
		},
	}, MockInventory)
end

return mapItemDefinitionsToInventory

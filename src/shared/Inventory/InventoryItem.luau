--!strict
local InventoryItem = { Prototype = {} }

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Networking = ReplicatedStorage:WaitForChild("Networking")
local InventoryEvent = Networking:WaitForChild("InventoryEvent") :: RemoteEvent

local Knit = require(Packages.Knit)

local IS_SERVER = RunService:IsServer()

local Utility = require(script.Parent.Utility)
local ItemActions = require(script.Parent.ItemActions)
local ITEM_DATA_MAP = require(script.Parent.ItemsMap)
local Types = require(script.Parent.Types)

type InventoryItemRoot = Types.InventoryItemRoot
type ItemType = Types.ItemType

type ItemProperties = Types.ItemProperties

export type InventoryItem = typeof(setmetatable(
	{} :: {
		Name: string,
		Rarity: string?,
		_player: Player,
		_inventory: any,
		_type: ItemType,
		_id: string,
	},
	{ __index = InventoryItem.Prototype }
))

local function getRawRoot(self: InventoryItem): InventoryItemRoot?
	return self._inventory:_getRawItem(self._id)
end

local function getItemDefinition(self: InventoryItem)
	local itemTypeDefinitions = ITEM_DATA_MAP[self._type]
	if itemTypeDefinitions then
		return itemTypeDefinitions[self.Name]
	end
	return nil
end

function InventoryItem.Prototype:GetId(): string
	return self._id
end

function InventoryItem.Prototype:GetType(): string
	return self._type
end

function InventoryItem.Prototype:GetDefinition()
	return getItemDefinition(self)
end

function InventoryItem.Prototype:GetProperties(): ItemProperties
	local root = getRawRoot(self)
	if not root then
		return {}
	end
	return root.Properties or {}
end

function InventoryItem.Prototype:GetProperty(key: string): any
	return self:GetProperties()[key]
end

function InventoryItem.Prototype:IsEquipped(): boolean
	local root = getRawRoot(self)
	return root ~= nil and root.Equipped == true
end

function InventoryItem.Prototype:GetStackCount(): number
	local root = getRawRoot(self)
	if root and typeof(root.StackCount) == "number" then
		return root.StackCount
	end
	return 1
end

function InventoryItem.Prototype:Remove(): ()
	if IS_SERVER then
		self._inventory:_removeItemById(self._id)
	else
		InventoryEvent:FireServer({
			packet = "removeItems",
			data = {
				itemsType = self._type,
				items = { self._id },
			},
		})
	end
end

function InventoryItem.Prototype:Equip(): ()
	if self:IsEquipped() then
		return
	end

	if IS_SERVER then
		self._inventory:_setEquipped(self._id, true)
	else
		InventoryEvent:FireServer({
			packet = "setItemEquipped",
			data = {
				itemId = self._id,
				itemType = self._type,
				equipped = true,
			},
		})
	end
end

function InventoryItem.Prototype:Unequip(): ()
	if not self:IsEquipped() then
		return
	end

	if IS_SERVER then
		self._inventory:_setEquipped(self._id, false)
	else
		InventoryEvent:FireServer({
			packet = "setItemEquipped",
			data = {
				itemId = self._id,
				itemType = self._type,
				equipped = false,
			},
		})
	end
end

function InventoryItem.Prototype:ToggleEquipped(): ()
	if self:IsEquipped() then
		self:Unequip()
	else
		self:Equip()
	end
end

function InventoryItem.Prototype:Use(actionName: string?): ()
	local resolvedActionName = actionName or "Default"

	if IS_SERVER then
		local actionByType = ItemActions[self._type]
		local action = actionByType and actionByType[self.Name]
		if not action then
			warn(("[InventoryItem]: No action registered for %s/%s"):format(self._type, self.Name))
			return
		end

		action({
			player = self._player,
			item = self,
			inventory = self._inventory,
			services = Knit.Services,
			actionName = resolvedActionName,
		})
	else
		InventoryEvent:FireServer({
			packet = "useItem",
			data = {
				itemId = self._id,
				itemType = self._type,
				actionName = resolvedActionName,
			},
		})
	end
end

if IS_SERVER then
	function InventoryItem.Prototype:SetProperty(key: string, value: any): ()
		self._inventory:_setItemProperty(self._id, key, value)
	end

	function InventoryItem.Prototype:SetProperties(properties: ItemProperties): ()
		for key, value in properties do
			self._inventory:_setItemProperty(self._id, key, value)
		end
	end

	function InventoryItem.Prototype:ClearProperty(key: string): ()
		self._inventory:_setItemProperty(self._id, key, nil)
	end

	function InventoryItem.Prototype:SetStackCount(amount: number): ()
		self._inventory:_setStackCount(self._id, amount)
	end
end

return function(player: Player, itemId: string, itemType: ItemType, itemData: InventoryItemRoot, inventoryObject: any): InventoryItem
	local success, reason = Utility.ValidateItem(itemId, itemType, itemData)
	if not success then
		error(("[InventoryItem]: Invalid item %s/%s: %s"):format(itemType, itemId, tostring(reason)))
	end

	local self = {
		Name = itemData.Name,
		Rarity = itemData.Rarity,
		_player = player,
		_id = itemId,
		_type = itemType,
		_inventory = inventoryObject,
	}

	return setmetatable(self, { __index = InventoryItem.Prototype })
end

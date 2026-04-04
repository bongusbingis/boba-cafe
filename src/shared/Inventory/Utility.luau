--!strict
local Utility = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Configuration = Shared:WaitForChild("Configuration")

local ItemDefinitions = require(Configuration:WaitForChild("InventoryItemDefinitions"))
local InventoryLimits = require(Configuration:WaitForChild("InventoryLimits"))
local ITEM_DATA_MAP = require(script.Parent.ItemsMap)
local Types = require(script.Parent.Types)

type InventoryItemRoot = Types.InventoryItemRoot
type ItemType = Types.ItemType

function Utility.AssertValidItemType(itemType: ItemType)
	assert(ITEM_DATA_MAP[itemType] or  ItemDefinitions[itemType], (`Invalid inventory item type: {itemType}`))
end

function Utility.ValidateItem(itemId: string, itemType: ItemType, itemData: InventoryItemRoot): (boolean, string?)
	if typeof(itemId) ~= "string" or itemId == "" then
		return false, "itemId must be a non-empty string"
	end

	if typeof(itemType) ~= "string" then
		return false, "itemType must be a string"
	end

	local itemTypeDefinitions = ITEM_DATA_MAP[itemType]
	if not itemTypeDefinitions then
		return false, (`Unknown itemType {itemType}`)
	end

	if typeof(itemData) ~= "table" then
		return false, "itemData must be a table"
	end

	if typeof(itemData.Name) ~= "string" or itemData.Name == "" then
		return false, "itemData.Name must be a non-empty string"
	end

	if itemTypeDefinitions[itemData.Name] == nil then
		return false, (`{itemData.Name} is not a valid item in {itemType}`)
	end

	if itemData.Equipped ~= nil and typeof(itemData.Equipped) ~= "boolean" then
		return false, "itemData.Equipped must be a boolean when provided"
	end

	if itemData.StackCount ~= nil then
		if typeof(itemData.StackCount) ~= "number" or itemData.StackCount < 1 then
			return false, "itemData.StackCount must be a positive number when provided"
		end
	end

	if itemData.Properties ~= nil and typeof(itemData.Properties) ~= "table" then
		return false, "itemData.Properties must be a table when provided"
	end

	return true
end

function Utility.GetInventoryLimit(limitType: "Equipped" | "Storage", itemType: ItemType): number
	local limitData = InventoryLimits[limitType]
	assert(limitData ~= nil, (`Missing inventory limit group {limitType}`))

	local itemLimitForType = limitData[itemType]
	assert(typeof(itemLimitForType) == "number", (`Missing inventory limit for {limitType}.{itemType}`))

	return itemLimitForType
end

function Utility.Clone(value: any): any
	if typeof(value) ~= "table" then
		return value
	end

	local result = table.clone(value :: any)
	for key, nestedValue in result do
		if typeof(nestedValue) == "table" then
			result[key] = Utility.Clone(nestedValue)
		end
	end
	return result
end

return Utility

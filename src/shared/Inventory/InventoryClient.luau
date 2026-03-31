--!strict
local InventoryClient = { Prototype = {} }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Components = script.Parent

local Loader = require(Packages.Loader)
local Promise = require(Packages.Promise)
local GoodSignal = require(Packages.GoodSignal)
local Janitor = require(Packages.Janitor)

local Packets = require(Components.Packets)
local ItemsMap = require(Components.ItemsMap)
local InventoryItem = require(Components.InventoryItem)
local InventoryShared = require(Components.InventoryShared)
local Utility = require(Components.Utility)
local Types = require(Components.Types)

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
			_type: ItemType,
			_item_type_shared_data: { [string]: any },
			_raw_data: InventoryTypeRoot,
		},
		_janitor: Janitor.Janitor,
	},
	{ __index = InventoryClient.Prototype }
))

function InventoryClient.Prototype:_getRawItem(itemId: string)
	return self.Metadata._raw_data[itemId]
end

function InventoryClient.Prototype:_rebuildItem(itemId: string)
	local rawItem = self:_getRawItem(itemId)
	if rawItem == nil then
		self.Inventory[itemId] = nil
		return
	end
	self.Inventory[itemId] = InventoryItem(Players.LocalPlayer, itemId, self.Metadata._type, rawItem, self)
end

function InventoryClient.Prototype:Filter(predicate)
	return InventoryShared.Filter(self, predicate)
end

function InventoryClient.Prototype:GetItems(itemIds, predicate)
	return InventoryShared.GetItems(self, itemIds, predicate)
end

function InventoryClient.Prototype:GetItemFromId(itemId: string)
	return InventoryShared.GetItemFromId(self, itemId)
end

function InventoryClient.Prototype:GetFirstEquippedItem()
	return InventoryShared.GetFirstEquippedItem(self)
end

function InventoryClient.Prototype:GetEquippedItems()
	return InventoryShared.GetEquippedItems(self)
end

function InventoryClient.Prototype:TotalItemsEquipped(): number
	return InventoryShared.TotalItemsEquipped(self)
end

function InventoryClient.Prototype:RemoveItems(itemIds: { string })
	Packets.removeItems.send({
		itemsType = self.Metadata._type,
		items = itemIds,
	})
end

function InventoryClient.Prototype:Destroy(): ()
	self._janitor:Destroy()
	self.OnChange:DisconnectAll()
	table.clear(self.Inventory)
	table.clear(self)
end

function InventoryClient:GetPlayerInventoryAsync(itemTypeToReturn: ItemType)
	Utility.AssertValidItemType(itemTypeToReturn)

	return Promise.new(function(resolve, reject)
		Loader.Controllers.DataController:GetDataAsync()
			:andThen(function(playerData)
				local playerInventoryRoot: InventoryItemsRoot = playerData.Inventory.Items
				local rawTypeRoot = playerInventoryRoot[itemTypeToReturn]
				if rawTypeRoot == nil then
					reject(("Invalid item type %s provided; missing inventory table"):format(itemTypeToReturn))
					return
				end

				local wrapped = {}
				local selfObject: PlayerInventory = setmetatable({
					Inventory = wrapped,
					OnChange = GoodSignal.new(),
					Metadata = {
						_type = itemTypeToReturn,
						_item_type_shared_data = ItemsMap[itemTypeToReturn],
						_raw_data = rawTypeRoot,
					},
					_janitor = Janitor.new(),
				}, { __index = InventoryClient.Prototype })

				for itemId, itemData in rawTypeRoot do
					wrapped[itemId] = InventoryItem(Players.LocalPlayer, itemId, itemTypeToReturn, itemData, selfObject)
				end

				local connection = Packets.onChange.listen(function(data: OnChangeData)
					if data.itemsType ~= itemTypeToReturn then
						return
					end

					local currentPlayerData = Loader.Controllers.DataController.LocalPlayerData
					if currentPlayerData and currentPlayerData.Inventory and currentPlayerData.Inventory.Items then
						local latestRaw = currentPlayerData.Inventory.Items[itemTypeToReturn]
						if latestRaw then
							selfObject.Metadata._raw_data = latestRaw
						end
					end

					selfObject:_rebuildItem(data.itemId)
					selfObject.OnChange:Fire(data)
				end)

				selfObject._janitor:Add(function()
					Packets.onChange.disconnect(connection)
				end)

				resolve(selfObject)
			end)
			:catch(reject)
	end)
end

return InventoryClient

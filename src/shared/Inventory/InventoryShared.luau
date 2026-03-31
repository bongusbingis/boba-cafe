--!strict
local Shared = {}

export type PredicateFn<T> = (item: T) -> boolean

function Shared.Filter(self, predicate)
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

function Shared.GetItems(self, itemIds, predicate)
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

function Shared.GetItemFromId(self, itemId)
	return self.Inventory[itemId]
end

function Shared.GetFirstEquippedItem(self)
	for _, item in self.Inventory do
		if item:IsEquipped() then
			return item
		end
	end
	return nil
end

function Shared.GetEquippedItems(self)
	return Shared.Filter(self, function(item)
		return item:IsEquipped()
	end)
end

function Shared.TotalItemsEquipped(self)
	local _, count = Shared.GetEquippedItems(self)
	return count
end

return Shared

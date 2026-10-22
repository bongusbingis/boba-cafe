--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Inventory = require(Shared.Inventory)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)

return function(_context: any, targets: { Player }, itemType: string, itemName: string)
	local categoryDefs = (InventoryItemDefinitions :: any)[itemType]
	local def = categoryDefs and categoryDefs[itemName]
	local tier = (typeof(def) == "table" and def.Tier) or 1

	for _, target in targets do
		pcall(function()
			Inventory:GetPlayerInventoryAsync(target, itemType :: any):andThen(function(inv: any)
				inv:Insert({
					Name = itemName,
					Tier = tier,
				})
			end)
		end)
	end

	return string.format("Given %s (%s) to %d player(s).", itemName, itemType, #targets)
end

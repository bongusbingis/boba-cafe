--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Inventory = require(Shared.Inventory)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)

local ITEM_TYPES = { "Capsules", "Nametags", "Particles", "Pets" }

return function(_context: any, targets: { Player })
	for _, target in targets do
		for _, itemType in ITEM_TYPES do
			local categoryDefs = (InventoryItemDefinitions :: any)[itemType]
			if categoryDefs then
				pcall(function()
					Inventory:GetPlayerInventoryAsync(target, itemType :: any):andThen(function(inv: any)
						for itemName, def in categoryDefs do
							if typeof(def) == "table" then
								inv:Insert({
									Name = itemName,
									Tier = def.Tier or 1,
								})
							end
						end
					end)
				end)
			end
		end
	end

	return string.format("Granted all items to %d player(s).", #targets)
end

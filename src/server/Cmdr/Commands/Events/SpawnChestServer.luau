--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(_context)
	local TreasureHuntService = Knit.GetService("TreasureHuntService")
	local ok, chest = pcall(function()
		return TreasureHuntService:SpawnNextChest()
	end)

	if not ok then
		return "Error spawning treasure chest: " .. tostring(chest)
	end

	if chest then
		return "Treasure chest spawned!"
	else
		return "Warning: Could not spawn treasure chest (max chests reached or no available nodes)."
	end
end

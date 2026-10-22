--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(_context, spillType: string?)
	local SpillService = Knit.GetService("SpillService")
	local ok, success, err = pcall(function()
		local spillsFolder = (
			Workspace:FindFirstChild("Assets") and (Workspace:FindFirstChild("Assets") :: any):FindFirstChild("Spills")
		) or SpillService.SpillsFolder
		local regions = SpillService:_GetRegions(spillsFolder)
		if not regions or #regions == 0 then
			return false, "No valid spill regions found."
		end

		local chosenType = spillType or "Water"
		if not SpillService.Spills[chosenType] then
			SpillService.Spills[chosenType] = {}
		end

		local region = regions[math.random(1, #regions)]
		local created = SpillService:CreateSpill(chosenType, chosenType, region, false)
		if not created then
			return false, "Spill could not be created (spills disabled or region full)."
		end

		return true, nil
	end)

	if not ok then
		return "Error spawning spill: " .. tostring(success)
	end

	if not success then
		return err or "Failed to spawn spill."
	end

	return "Spill spawned!"
end

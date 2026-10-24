--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(_context, template: string?)
	local SpillService = Knit.GetService("SpillService")
	if not SpillService.Enabled then
		return "SpillService is disabled or required world assets are missing."
	end

	local ok, success, err = pcall(function()
		local spillsFolder = (
			Workspace:FindFirstChild("Assets") and (Workspace:FindFirstChild("Assets") :: any):FindFirstChild("Spills")
		) or SpillService.SpillsFolder
		local regions = SpillService:_GetRegions(spillsFolder)
		if not regions or #regions == 0 then
			return false, "No valid spill regions found."
		end

		local storageSpills = SpillService.Storage and SpillService.Storage:FindFirstChild("Spills")
		local chosenTemplate = template
		if not chosenTemplate then
			if storageSpills then
				local candidates = {}
				for _, child in storageSpills:GetChildren() do
					if child:IsA("Model") then
						table.insert(candidates, child.Name)
					end
				end
				if #candidates > 0 then
					chosenTemplate = candidates[math.random(1, #candidates)]
				end
			end
			chosenTemplate = chosenTemplate or "Boba"
		end

		if not storageSpills or not storageSpills:FindFirstChild(chosenTemplate) then
			return false, string.format("Spill template '%s' not found in CleanlinessStorage.Spills.", chosenTemplate)
		end

		local region = regions[math.random(1, #regions)]
		local created = SpillService:CreateSpill("Mopping", chosenTemplate, region, false)
		if not created then
			return false, "Spill could not be created (spill cap reached or no free spot found)."
		end

		return true, chosenTemplate
	end)

	if not ok then
		return "Error spawning spill: " .. tostring(success)
	end

	if not success then
		return err or "Failed to spawn spill."
	end

	return string.format("Spill spawned (%s)!", tostring(err))
end

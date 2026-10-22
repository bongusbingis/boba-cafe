--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage:WaitForChild("Packages").Knit)
local ProgressionConfig = require(ReplicatedStorage.Shared.Configuration.Progression)

return function(_context: any, targets: { Player }, level: number): string
	local ProgressionService = Knit.GetService("ProgressionService")
	local DataService = Knit.GetService("DataService")
	local clampedLevel = math.clamp(level, 1, ProgressionConfig.MAX_LEVEL)

	for _, target in targets do
		pcall(function()
			DataService:GetDataAsync(target)
				:andThen(function(proxy)
					proxy:SetValue({ "Level" }, clampedLevel)
					proxy:SetValue({ "XP" }, 0)
					target:SetAttribute("Level", clampedLevel)
					target:SetAttribute("LevelTitle", ProgressionConfig.TitleFor(clampedLevel))
					local serviceState = (ProgressionService :: any)._state
					if serviceState and serviceState[target] then
						serviceState[target].Level = clampedLevel
						serviceState[target].XP = 0
					end
					if (ProgressionService :: any)._ensureTitles then
						(ProgressionService :: any):_ensureTitles(target, proxy)
					end
				end)
				:catch(function(err)
					warn(string.format("[Cmdr] SetLevel failed for %s: %s", target.Name, tostring(err)))
				end)
		end)
	end

	return string.format("Set level to %d for %d player(s).", clampedLevel, #targets)
end

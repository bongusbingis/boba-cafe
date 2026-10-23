--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(_context: any, target: string)
	local userId: number? = tonumber(target)
	local targetName = target

	if not userId then
		local okId, res = pcall(function()
			return Players:GetUserIdFromNameAsync(target)
		end)
		if okId and typeof(res) == "number" then
			userId = res
		else
			return string.format("Could not find a Roblox user with username '%s'.", target)
		end
	else
		pcall(function()
			targetName = Players:GetNameFromUserIdAsync(userId)
		end)
	end

	local ModerationService = Knit.GetService("ModerationService")
	local success, msg = ModerationService:UnbanAsync(userId)

	if success then
		return string.format("Successfully unbanned %s (%d).", targetName, userId)
	else
		return string.format("Could not unban %s (%d): %s", targetName, userId, msg)
	end
end

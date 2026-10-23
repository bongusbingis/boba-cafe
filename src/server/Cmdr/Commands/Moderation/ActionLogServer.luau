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
	local logs = ModerationService:GetActionLogAsync(userId)

	if not logs or #logs == 0 then
		return string.format("No moderation actions on record for %s (%d).", targetName, userId)
	end

	local lines = {
		string.format("=== Moderation History for %s (%d) ===", targetName, userId),
	}

	for i, action in ipairs(logs) do
		local timeStr = ModerationService:_getFormattedTimeInEST(action.Timestamp or os.time())
		table.insert(
			lines,
			string.format(
				"[%d] %s | %s\n    Issued By: %s\n    Reason: %s",
				i,
				timeStr,
				tostring(action.Type or "Action"),
				tostring(action.IssuedBy or "Unknown"),
				tostring(action.Reason or "No reason provided")
			)
		)
	end

	return table.concat(lines, "\n")
end

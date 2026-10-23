--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local RankUtil = require(Shared.Utility.RankUtil)

local BOBA_GROUP_ID = 3174578

return function(context: any, target: string, durationHours: number, reason: string)
	local executor = context.Executor :: Player?
	if not executor then
		return "This command can only be executed by a player."
	end

	if durationHours <= 0 then
		return "Duration must be at least 1 hour."
	end

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

	if userId == executor.UserId then
		return "You cannot ban yourself."
	end

	local executorRank = 0
	if RunService:IsStudio() or executor:GetAttribute("IsAdmin") == true then
		executorRank = 255
	else
		local ok, rank = pcall(function()
			return RankUtil:GetRankAsync(executor)
		end)
		if ok then
			executorRank = rank
		end
	end

	local targetRank = 0
	local inGameTarget = Players:GetPlayerByUserId(userId)
	if inGameTarget then
		local okTarget, rTarget = pcall(function()
			return RankUtil:GetRankAsync(inGameTarget)
		end)
		if okTarget then
			targetRank = rTarget
		end
	else
		pcall(function()
			targetRank = Players:GetPlayerByUserId(userId):GetRankInGroup(BOBA_GROUP_ID)
		end)
	end

	if targetRank >= executorRank and executorRank < 255 then
		return string.format("You cannot ban %s because they are the same or higher rank than you.", targetName)
	end

	local filteredReason = "Temporarily banned by staff."
	if reason and reason ~= "" then
		local ok, result = pcall(function()
			local filterResult = TextService:FilterStringAsync(reason, executor.UserId)
			return filterResult:GetNonChatStringForBroadcastAsync()
		end)
		if ok and typeof(result) == "string" and result ~= "" then
			filteredReason = result
		end
	end

	local ModerationService = Knit.GetService("ModerationService")
	local durationSeconds = durationHours * 3600
	local success, msg = ModerationService:BanAsync(userId, filteredReason, executor.Name, durationSeconds, false)

	if success then
		return string.format(
			"Successfully temporarily banned %s (%d) for %d hour(s). Reason: %s",
			targetName,
			userId,
			durationHours,
			filteredReason
		)
	else
		return string.format("Failed to ban %s: %s", targetName, msg)
	end
end

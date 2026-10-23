--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local RankUtil = require(Shared.Utility.RankUtil)

return function(context: any, target: Player, reason: string)
	local executor = context.Executor :: Player?
	if not executor then
		return "This command can only be executed by a player."
	end

	if executor == target then
		return "You cannot warn yourself."
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
	local okTarget, rTarget = pcall(function()
		return RankUtil:GetRankAsync(target)
	end)
	if okTarget then
		targetRank = rTarget
	end

	if targetRank >= executorRank and executorRank < 255 then
		return string.format("You cannot warn %s because they are the same or higher rank than you.", target.Name)
	end

	local defaultReason = "Warning from staff."
	local filteredReason = defaultReason
	if reason and reason ~= "" then
		local filterOk, result = pcall(function()
			local filterResult = TextService:FilterStringAsync(reason, executor.UserId)
			return filterResult:GetNonChatStringForUserAsync(target.UserId)
		end)
		if filterOk and typeof(result) == "string" and result ~= "" then
			filteredReason = result
		else
			warn("[Cmdr/Warn] Failed to filter warning reason, using default.")
		end
	end

	local ModerationService = Knit.GetService("ModerationService")
	ModerationService:TrackModeration(target, filteredReason, executor.Name, "Warning")

	local DialogService = Knit.GetService("DialogService")
	pcall(function()
		DialogService:CreateDialog(target, "ButtonPrompt", {
			Title = "Staff Warning",
			Text = string.format("You were warned by %s for: %s", executor.DisplayName, filteredReason),
			Buttons = { { Text = "Acknowledge" } },
		})
	end)
	pcall(function()
		DialogService:Notify(target, "Warning: " .. filteredReason)
	end)

	return string.format("Successfully warned %s for: '%s'.", target.Name, filteredReason)
end

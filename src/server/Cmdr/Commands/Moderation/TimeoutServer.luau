local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

return function(context, target, minutes, reason)
	local executorPlayer = context.Executor
	if executorPlayer == nil then
		return "You must be in the game to time someone out."
	end

	if target.UserId == executorPlayer.UserId then
		return "You cannot time yourself out."
	end

	local success, response = pcall(function()
		return context:GetService("ModerationService"):CanModerate(executorPlayer, target)
	end)

	if success and response == false then
		return "You cannot moderate this player."
	end

	if not RunService:IsStudio() and executorPlayer:GetAttribute("IsAdmin") ~= true then
		if not success or not response then
			return "You do not have permission to time out players."
		end
	end

	local durationMinutes = if typeof(minutes) == "number" then minutes else 15
	local defaultReason = "Disrupting other players."
	local finalReason = defaultReason
	if typeof(reason) == "string" and reason ~= "" then
		local ok, filteredText = pcall(function()
			return TextService:FilterStringAsync(reason, executorPlayer.UserId, Enum.TextFilterContext.PublicChat)
				:GetNonChatStringForBroadcastAsync()
		end)
		if ok and typeof(filteredText) == "string" and filteredText ~= "" then
			finalReason = filteredText
		end
	end

	local ok, message = pcall(function()
		return context
			:GetService("ModerationService")
			:TimeoutAsync(target.UserId, durationMinutes, finalReason, executorPlayer.Name)
	end)
	if not ok then
		return `Failed to time out {target.DisplayName} (@{target.Name}).`
	end
	return message
end

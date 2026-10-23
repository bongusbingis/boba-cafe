local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

return function(context, target, pet, reason)
	local executorPlayer = context.Executor
	if executorPlayer == nil then
		return "You must be in the game to reset pet names."
	end

	if target.UserId == executorPlayer.UserId then
		return "You cannot reset your own pet names with this command."
	end

	local success, response = pcall(function()
		return context:GetService("ModerationService"):CanModerate(executorPlayer, target)
	end)

	if success and response == false then
		return "You cannot moderate this player."
	end

	if not RunService:IsStudio() and executorPlayer:GetAttribute("IsAdmin") ~= true then
		if not success or not response then
			return "You do not have permission to reset pet names."
		end
	end

	local defaultReason = "Inappropriate pet name."
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

	local petService = context:GetService("PetService")
	local ok, count, resetNames = pcall(function()
		return petService:ResetPetNames(target, pet)
	end)
	if not ok then
		return `Failed to reset pet names for {target.DisplayName} (@{target.Name}).`
	end
	if count == 0 then
		return `{target.DisplayName} has no renamed pets to reset.`
	end
	pcall(function()
		context
			:GetService("ModerationService")
			:TrackModeration(target, finalReason, executorPlayer.Name, "Pet Name Reset")
	end)
	return string.format("Reset %d pet name(s) for %s: %s.", count, target.DisplayName, table.concat(resetNames, ", "))
end

local RunService = game:GetService("RunService")

return function(context, target)
	local executorPlayer = context.Executor
	if executorPlayer == nil then
		return "You must be in the game to lift a timeout."
	end

	if target.UserId == executorPlayer.UserId then
		return "You cannot untimeout yourself."
	end

	local success, response = pcall(function()
		return context:GetService("ModerationService"):CanModerate(executorPlayer, target)
	end)

	if success and response == false then
		return "You cannot moderate this player."
	end

	if not RunService:IsStudio() and executorPlayer:GetAttribute("IsAdmin") ~= true then
		if not success or not response then
			return "You do not have permission to lift timeouts."
		end
	end

	local ok, message = pcall(function()
		return context:GetService("ModerationService"):LiftTimeout(target.UserId, executorPlayer.Name)
	end)
	if not ok then
		return `Failed to untimeout {target.DisplayName} (@{target.Name}).`
	end
	return message
end

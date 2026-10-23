--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(context: any, tab: string?)
	local executor = context.Executor :: Player?
	if not executor then
		return "This command can only be executed by a player."
	end

	local LogService = Knit.GetService("LogService")
	local targetTab = tab or "Admin"
	LogService:OpenLogsForPlayer(executor, targetTab)

	return string.format("Opened Server Logs (%s tab).", targetTab)
end

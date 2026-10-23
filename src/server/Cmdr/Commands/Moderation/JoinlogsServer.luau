--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(context: any)
	local executor = context.Executor :: Player?
	if not executor then
		return "This command can only be executed by a player."
	end

	local LogService = Knit.GetService("LogService")
	LogService:OpenLogsForPlayer(executor, "Join")

	return "Opened Server Join Logs."
end

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(context: any)
	local ModerationService = Knit.GetService("ModerationService")
	if not ModerationService:IsServerLocked() then
		return "The server was already unlocked."
	end

	ModerationService:SetServerLocked(false)

	local LogService = Knit.GetService("LogService")
	LogService:AddAdminLog(context.Executor or "Server", "Server Unlock", "Server was unlocked")

	return "The server has been unlocked."
end

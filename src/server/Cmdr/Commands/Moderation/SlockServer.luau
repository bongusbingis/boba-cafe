--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(context: any)
	local ModerationService = Knit.GetService("ModerationService")
	if ModerationService:IsServerLocked() then
		return "The server was already locked."
	end

	ModerationService:SetServerLocked(true)

	local LogService = Knit.GetService("LogService")
	LogService:AddAdminLog(context.Executor or "Server", "Server Lock", "Server was locked")

	return "The server has been locked (MR+ only)."
end

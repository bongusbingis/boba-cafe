--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local RankUtil = require(Shared.Utility.RankUtil)

return function(context: any, reason: string?)
	local executor = context.Executor :: Player?
	if executor and not RunService:IsStudio() and executor:GetAttribute("IsAdmin") ~= true then
		local ok, isHR = pcall(function()
			return RankUtil.IsHR(executor)
		end)
		if not ok or not isHR then
			return "You do not have permission to shut down the server (HR+ required)."
		end
	end

	local shutdownMsg = reason or "This server is shutting down..\nTry joining a different server!"

	local LogService = Knit.GetService("LogService")
	LogService:AddAdminLog(executor or "Server", "Shutdown", shutdownMsg)

	task.spawn(function()
		local DialogService = Knit.GetService("DialogService")
		for _, player in Players:GetPlayers() do
			pcall(function()
				DialogService:Notify(player, "Server is shutting down...")
			end)
		end

		task.wait(1.5)

		for _, player in Players:GetPlayers() do
			pcall(function()
				player:Kick(shutdownMsg)
			end)
		end
	end)

	return "Initiated server shutdown."
end

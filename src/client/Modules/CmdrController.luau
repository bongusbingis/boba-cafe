--!strict
--[[
	CmdrController.luau
	Knit controller managing the Cmdr developer / admin console (client side).
	Binds activation keys (F2 and Backquote/Tilde ~) and configures the client console.
]]

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local RankUtil = require(Shared.Utility.RankUtil)

---> controller declaration
local CmdrController = Knit.CreateController({
	Name = "CmdrController",
})

---> lifecycle
function CmdrController:KnitStart()
	-- Wait for CmdrClient to be replicated by the server
	local cmdrClient = ReplicatedStorage:WaitForChild("CmdrClient", 15)
	if not cmdrClient then
		warn("[CmdrController] Timed out waiting for CmdrClient in ReplicatedStorage.")
		return
	end

	local Cmdr = require(cmdrClient)
	-- Key binds: F2 and Backquote (~)
	Cmdr:SetActivationKeys({ Enum.KeyCode.Quote })
	Cmdr:SetPlaceName("Boba Cafe Dev Console")

	-- In live servers, disable the console for players without MR+ rank or admin attribute
	if not RunService:IsStudio() then
		local localPlayer = Players.LocalPlayer
		task.spawn(function()
			local isAllowed = false
			local ok, rank = pcall(function()
				return RankUtil:GetRankAsync(localPlayer)
			end)
			if (ok and rank >= 11) or localPlayer:GetAttribute("IsAdmin") == true then
				isAllowed = true
			end

			if not isAllowed then
				Cmdr:SetEnabled(false)
			end
		end)
	end
end

return CmdrController

--!strict
--[[
	CmdrController.luau
	Knit controller managing the Cmdr developer / admin console (client side).
	Binds activation keys (F2 and Backquote/Tilde ~), configures the client console,
	and provides an interface to toggle the console for authorized moderators.
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
	_cmdr = nil :: any,
})

---> public methods
function CmdrController:Toggle()
	if self._cmdr then
		self._cmdr:Toggle()
	else
		task.spawn(function()
			local cmdrClient = ReplicatedStorage:WaitForChild("CmdrClient", 5)
			if cmdrClient then
				local Cmdr = require(cmdrClient)
				self._cmdr = Cmdr
				Cmdr:Toggle()
			end
		end)
	end
end

---> lifecycle
function CmdrController:KnitStart()
	-- Wait for CmdrClient to be replicated by the server
	local cmdrClient = ReplicatedStorage:WaitForChild("CmdrClient", 15)
	if not cmdrClient then
		warn("[CmdrController] Timed out waiting for CmdrClient in ReplicatedStorage.")
		return
	end

	local Cmdr = require(cmdrClient)
	self._cmdr = Cmdr
	-- Key binds: Backquote/Tilde (Quote) and F2
	Cmdr:SetActivationKeys({ Enum.KeyCode.Quote, Enum.KeyCode.F2 })
	Cmdr:SetPlaceName("Boba Cafe Dev Console")

	local localPlayer = Players.LocalPlayer
	task.spawn(function()
		local isAllowed = false

		if RunService:IsStudio() then
			isAllowed = true
		else
			local ok, rank = pcall(function()
				return RankUtil:GetRankAsync(localPlayer)
			end)
			if (ok and rank >= 11) or localPlayer:GetAttribute("IsAdmin") == true then
				isAllowed = true
			end
		end

		if not isAllowed then
			Cmdr:SetEnabled(false)
		end
	end)
end

return CmdrController

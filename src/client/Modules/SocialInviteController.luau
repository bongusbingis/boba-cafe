--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

local SocialInviteController = Knit.CreateController({
	Name = "SocialInviteController",
})

function SocialInviteController:PromptInvite(): boolean
	local player = Players.LocalPlayer
	local okCheck, canInvite = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if okCheck and canInvite == false then
		return false
	end

	local okPrompt = pcall(function()
		SocialService:PromptGameInvite(player)
	end)
	return okPrompt
end

function SocialInviteController:KnitStart()
	local socialInviteService = Knit.GetService("SocialInviteService")
	socialInviteService.InvitePromptRequested:Connect(function()
		self:PromptInvite()
	end)
end

return SocialInviteController

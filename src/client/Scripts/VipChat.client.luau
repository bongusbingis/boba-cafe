--!strict
--[[
	VipChat
	VIP pass owners' chat message text uses the main UI green (REVIVAL-001 PASS-PORT
	lane A). Ownership comes from the `VipTag` player attribute published by
	CosmeticPerkService. Only the message body is recoloured, like the live game.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PassCosmetics = require(Shared.Configuration.PassCosmetics)

TextChatService.OnIncomingMessage = function(message: TextChatMessage): TextChatMessageProperties?
	local source = message.TextSource
	if source == nil then
		return nil
	end
	local sender = Players:GetPlayerByUserId(source.UserId)
	if sender == nil or sender:GetAttribute(PassCosmetics.VIP_ATTRIBUTE) ~= true then
		return nil
	end

	local properties = Instance.new("TextChatMessageProperties")
	properties.Text = PassCosmetics.ColorizeChatText(message.Text, PassCosmetics.VIP_CHAT_COLOR)
	return properties
end

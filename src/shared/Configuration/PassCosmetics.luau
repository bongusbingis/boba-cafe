--!strict
--[[
	PassCosmetics
	Shared tuning for the cosmetic pass perks (REVIVAL-001 PASS-PORT lane A):
	VIP chat colour and the Rainbow Pack nametag + trail. Ownership is published by
	CosmeticPerkService as player attributes (`VipTag`, `RainbowPack`).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Styles = require(Shared.UI.Styles)

export type AnimFrame = { Color: Color3, Hold: number, Transition: number? }

local PassCosmetics = {}

---> attribute names
PassCosmetics.VIP_ATTRIBUTE = "VipTag"
PassCosmetics.RAINBOW_ATTRIBUTE = "RainbowPack"

---> VIP
PassCosmetics.VIP_STAR = "⭐"
PassCosmetics.VIP_CHAT_COLOR = Styles.GREEN

---> Rainbow (same stops as the live game's Rainbow nametag and trail)
local RAINBOW_STOPS: { { Position: number, Color: Color3 } } = {
	{ Position = 0, Color = Color3.fromRGB(255, 0, 0) },
	{ Position = 0.2, Color = Color3.fromRGB(255, 115, 0) },
	{ Position = 0.4, Color = Color3.fromRGB(255, 221, 0) },
	{ Position = 0.6, Color = Color3.fromRGB(43, 255, 0) },
	{ Position = 0.8, Color = Color3.fromRGB(0, 183, 255) },
	{ Position = 1, Color = Color3.fromRGB(137, 47, 255) },
}

PassCosmetics.RAINBOW_TRAIL_COLOR = ColorSequence.new((function()
	local keypoints = {}
	for _, stop in RAINBOW_STOPS do
		table.insert(keypoints, ColorSequenceKeypoint.new(stop.Position, stop.Color))
	end
	return keypoints
end)())

-- Nametag colour cycle, in the shape of Nametags[...].Animation.
PassCosmetics.RAINBOW_ANIMATION = {
	Frames = (function()
		local frames: { AnimFrame } = {}
		for _, stop in RAINBOW_STOPS do
			table.insert(frames, { Color = stop.Color, Hold = 0, Transition = 0.6 })
		end
		return frames
	end)(),
}

---> helpers

function PassCosmetics.ToHex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.round(color.R * 255),
		math.round(color.G * 255),
		math.round(color.B * 255)
	)
end

-- Rich-text wrap for a VIP chat message body (text only, like the live game).
function PassCosmetics.ColorizeChatText(text: string, color: Color3): string
	return `<font color="{PassCosmetics.ToHex(color)}">{text}</font>`
end

return PassCosmetics

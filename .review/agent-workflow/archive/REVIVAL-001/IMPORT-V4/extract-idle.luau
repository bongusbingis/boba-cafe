local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local argOffset = process.args[1] == "--" and 1 or 0
local game = roblox.deserializePlace(fs.readFile(process.args[1 + argOffset]))
local outDir = process.args[2 + argOffset]

local node = game:FindFirstChild("ReplicatedStorage")
for _, name in { "SharedStorage", "AnimationStorage", "NPC", "Idle" } do
	if not node then
		error("Missing path at: " .. name)
	end
	node = node:FindFirstChild(name)
end
if not node then
	error("Missing path: game.ReplicatedStorage.SharedStorage.AnimationStorage.NPC.Idle")
end
if not node:IsA("Animation") then
	error("Idle is " .. node.ClassName .. ", expected Animation")
end

local idOk, animId = pcall(function() return node.AnimationId end)
print("AnimationId=" .. (idOk and tostring(animId) or "unreadable in lune: " .. tostring(animId)))
local clone = node:Clone()
clone:SetAttribute("BuiltBy", "REVIVAL-001-import-v4")
local data = roblox.serializeModel({ clone })
fs.writeFile(outDir .. "/NPCStorage-Idle.rbxm", data)
print("wrote NPCStorage-Idle.rbxm")

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local argOffset = process.args[1] == "--" and 1 or 0
local game = roblox.deserializePlace(fs.readFile(process.args[1 + argOffset]))
local outDir = process.args[2 + argOffset]

local function find(root, names)
	local cur = root
	local parts = { "game" }
	for _, name in names do
		table.insert(parts, name)
		local child = cur:FindFirstChild(name)
		if not child then
			error("Missing path: " .. table.concat(parts, "."))
		end
		cur = child
	end
	return cur
end

local targets = {
	{
		names = { "ReplicatedStorage", "SharedStorage", "CleanlinessStorage" },
		file = "CleanlinessStorage.rbxm",
	},
	{
		names = { "ReplicatedStorage", "SharedStorage", "NPCStorage", "Karen" },
		file = "NPCStorage-Karen.rbxm",
	},
	{
		names = { "ReplicatedStorage", "SharedStorage", "NPCStorage", "Animations" },
		file = "NPCStorage-Animations.rbxm",
	},
	{
		names = { "ReplicatedStorage", "SharedStorage", "KitchenStorage", "Assets", "S_DefaultUniform" },
		file = "S_DefaultUniform.rbxm",
	},
	{
		names = { "ReplicatedStorage", "SharedStorage", "KitchenStorage", "Assets", "P_DefaultUniform" },
		file = "P_DefaultUniform.rbxm",
	},
}

for _, target in targets do
	local inst = find(game, target.names)
	local clone = inst:Clone()
	clone:SetAttribute("BuiltBy", "REVIVAL-001-import-v4")
	local ok, data = pcall(function()
		return roblox.serializeModel({ clone })
	end)
	if ok then
		print(target.file .. ": serializeModel({ clone }) worked")
	else
		print(target.file .. ": serializeModel({ clone }) failed (" .. tostring(data) .. "); using Folder parent")
		local folder = roblox.Instance.new("Folder")
		folder.Name = string.gsub(target.file, "%.rbxm$", "")
		clone.Parent = folder
		data = roblox.serializeModel({ folder })
	end
	fs.writeFile(outDir .. "/" .. target.file, data)
	print("wrote " .. target.file)
end

local customerConfig
local ok = pcall(function()
	customerConfig = find(game, { "ReplicatedStorage", "Shared", "Configuration", "CustomerConfig" })
end)
if not ok or not customerConfig then
	for _, desc in game:GetDescendants() do
		if desc.Name == "CustomerConfig" then
			customerConfig = desc
			break
		end
	end
end
if not customerConfig then
	error("Missing path: game.ReplicatedStorage.Shared.Configuration.CustomerConfig (also searched all descendants for CustomerConfig)")
end
fs.writeFile(outDir .. "/CustomerConfig.v4.txt", customerConfig.Source)
print("wrote CustomerConfig.v4.txt")

-- read-only inspection of a place file
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local path = process.args[1]
local maxDepth = tonumber(process.args[2]) or 3

local game = roblox.deserializePlace(fs.readFile(path))

local out = {}
local function walk(inst, depth, prefix)
	if depth > maxDepth then
		return
	end
	for _, c in inst:GetChildren() do
		local n = #c:GetChildren()
		table.insert(out, string.format("%s%s [%s]%s", prefix, c.Name, c.ClassName, n > 0 and (" {" .. n .. "}") or ""))
		walk(c, depth + 1, prefix .. "  ")
	end
end

for _, svc in
	{
		"Workspace",
		"ReplicatedStorage",
		"ServerScriptService",
		"ServerStorage",
		"StarterGui",
		"StarterPlayer",
		"Lighting",
		"SoundService",
		"Teams",
		"ReplicatedFirst",
		"StarterPack",
		"Chat",
		"TextChatService",
		"MaterialService",
	}
do
	local ok, s = pcall(function()
		return game:GetService(svc)
	end)
	if ok and s then
		table.insert(out, "\n=== " .. svc .. " ===")
		walk(s, 1, "")
	end
end

print(table.concat(out, "\n"))

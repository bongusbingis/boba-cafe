-- Extract all script sources from a place file into a mirrored directory tree.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local placePath = process.args[1]
local outDir = process.args[2]

local game = roblox.deserializePlace(fs.readFile(placePath))

if fs.isDir(outDir) then
	fs.removeDir(outDir)
end
fs.writeDir(outDir)

local function sanitize(s)
	return (string.gsub(s, "[^%w%-%._ ]", "_"))
end

local count, bytes = 0, 0
local manifest = {}

local function fullName(inst)
	local parts = {}
	local cur = inst
	while cur and cur.Parent do
		table.insert(parts, 1, cur.Name)
		cur = cur.Parent
	end
	return table.concat(parts, "/")
end

local function walk(inst, dir)
	for _, c in inst:GetChildren() do
		local cls = c.ClassName
		local isScript = cls == "Script" or cls == "LocalScript" or cls == "ModuleScript"
		local childDir = dir
		if isScript then
			local ok, src = pcall(function()
				return c.Source
			end)
			if ok and type(src) == "string" then
				if not fs.isDir(dir) then
					fs.writeDir(dir)
				end
				local ext = cls == "ModuleScript" and ".module.luau"
					or (cls == "LocalScript" and ".client.luau" or ".server.luau")
				local p = dir .. "/" .. sanitize(c.Name) .. ext
				local n = 1
				while fs.isFile(p) do
					n += 1
					p = dir .. "/" .. sanitize(c.Name) .. "_" .. n .. ext
				end
				fs.writeFile(p, src)
				count += 1
				bytes += #src
				table.insert(manifest, string.format("%7d  %-14s %s", #src, cls, fullName(c)))
			end
			childDir = dir .. "/" .. sanitize(c.Name) .. "_children"
		else
			childDir = dir .. "/" .. sanitize(c.Name)
		end
		walk(c, childDir)
	end
end

for _, svc in
	{
		"ReplicatedStorage",
		"ServerScriptService",
		"ServerStorage",
		"StarterGui",
		"StarterPlayer",
		"Workspace",
		"ReplicatedFirst",
		"StarterPack",
		"Lighting",
		"SoundService",
		"Chat",
		"TextChatService",
	}
do
	local ok, s = pcall(function()
		return game:GetService(svc)
	end)
	if ok and s then
		walk(s, outDir .. "/" .. svc)
	end
end

table.sort(manifest, function(a, b)
	return a > b
end)
fs.writeFile(outDir .. "/_MANIFEST.txt", table.concat(manifest, "\n"))
print(string.format("extracted %d scripts, %d bytes", count, bytes))

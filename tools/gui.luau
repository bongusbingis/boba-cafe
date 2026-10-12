local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local rootPath = process.args[2] -- e.g. StarterGui/MainUI
local maxDepth = tonumber(process.args[3]) or 3

local parts = {}
for p in string.gmatch(rootPath, "[^/]+") do
	table.insert(parts, p)
end

local node = game:GetService(parts[1])
for i = 2, #parts do
	node = node:FindFirstChild(parts[i])
	if not node then
		error("not found: " .. parts[i])
	end
end

local PROPS = {
	"Size",
	"Position",
	"BackgroundColor3",
	"BackgroundTransparency",
	"Text",
	"TextColor3",
	"TextSize",
	"Font",
	"FontFace",
	"Image",
	"ImageColor3",
	"ScaleType",
	"Visible",
	"AnchorPoint",
	"BorderSizePixel",
	"ZIndex",
	"CornerRadius",
	"Color",
	"Thickness",
	"PaddingLeft",
	"PaddingTop",
	"CellSize",
	"FillDirection",
	"SortOrder",
	"Padding",
	"AspectRatio",
	"MaxTextSize",
	"Transparency",
	"Rotation",
}

local out = {}
local function fmt(v)
	local t = typeof(v)
	if t == "string" then
		return '"' .. (#v > 60 and string.sub(v, 1, 60) .. "..." or v) .. '"'
	end
	return tostring(v)
end

local function walk(inst, depth, prefix)
	if depth > maxDepth then
		return
	end
	for _, c in inst:GetChildren() do
		local props = {}
		for _, p in PROPS do
			local ok, v = pcall(function()
				return (c :: any)[p]
			end)
			if ok and v ~= nil then
				table.insert(props, p .. "=" .. fmt(v))
			end
		end
		table.insert(out, string.format("%s%s [%s] %s", prefix, c.Name, c.ClassName, table.concat(props, " ")))
		walk(c, depth + 1, prefix .. "  ")
	end
end

table.insert(out, rootPath .. " [" .. node.ClassName .. "]")
walk(node, 1, "  ")
print(table.concat(out, "\n"))

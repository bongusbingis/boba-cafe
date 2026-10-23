--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local function collectTools(parent: Instance?, results: { [string]: boolean })
	if not parent then
		return
	end
	for _, desc in parent:GetDescendants() do
		if desc:IsA("Tool") or desc:IsA("HopperBin") then
			results[desc.Name] = true
		end
	end
end

return function(_context: any)
	local toolMap: { [string]: boolean } = {}
	collectTools(ServerStorage, toolMap)
	collectTools(ReplicatedStorage:FindFirstChild("ToolsStorage"), toolMap)

	local toolNames = {}
	for name in toolMap do
		table.insert(toolNames, name)
	end
	table.sort(toolNames)

	if #toolNames == 0 then
		return "No tools found in ServerStorage or ToolsStorage."
	end

	local lines = {
		string.format("=== Available Tools (%d) ===", #toolNames),
	}
	for _, name in toolNames do
		table.insert(lines, string.format("• %s", name))
	end

	return table.concat(lines, "\n")
end

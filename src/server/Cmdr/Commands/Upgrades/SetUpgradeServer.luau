--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local CafeUpgradeConfig = require(Shared.Configuration.CafeUpgradeConfig)

local function getService(name: string): any
	local ok, s = pcall(function()
		return Knit.GetService(name)
	end)
	if ok and s then
		return s
	end
	local server = ServerScriptService:FindFirstChild("Server")
	local modules = server and server:FindFirstChild("Modules")
	if modules and modules:FindFirstChild(name) then
		return require(modules[name])
	end
	error("Cannot resolve service: " .. name)
end

return function(_context, upgrade: string, level: number)
	local upgradeDef = CafeUpgradeConfig.GetUpgrade(upgrade)
	if not upgradeDef then
		return string.format("Unknown upgrade: %s.", tostring(upgrade))
	end

	if level < 0 or level > #upgradeDef.Levels then
		return string.format("Invalid level %d for %s. Must be between 0 and %d.", level, upgrade, #upgradeDef.Levels)
	end

	local ok, err = pcall(function()
		local CafeUpgradeService = getService("CafeUpgradeService")
		CafeUpgradeService._levels[upgrade] = level

		if upgrade == "TipJar" then
			Workspace:SetAttribute(CafeUpgradeConfig.TIP_JAR_LEVEL_ATTRIBUTE, level)
		end

		if typeof(CafeUpgradeService._renderAll) == "function" then
			CafeUpgradeService:_renderAll()
		elseif typeof(CafeUpgradeService._buildVisuals) == "function" then
			CafeUpgradeService:_buildVisuals(upgrade)
		end

		if typeof(CafeUpgradeService._refreshPlaque) == "function" then
			CafeUpgradeService:_refreshPlaque()
		end
	end)

	if not ok then
		return string.format("Failed to set upgrade %s: %s", upgrade, tostring(err))
	end

	return string.format("Set upgrade %s to level %d.", upgrade, level)
end

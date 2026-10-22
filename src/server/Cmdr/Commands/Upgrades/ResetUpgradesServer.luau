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

return function(_context)
	local ok, err = pcall(function()
		local CafeUpgradeService = getService("CafeUpgradeService")

		for _, upgrade in CafeUpgradeConfig.UPGRADES do
			CafeUpgradeService._levels[upgrade.Id] = 0
		end

		Workspace:SetAttribute(CafeUpgradeConfig.TIP_JAR_LEVEL_ATTRIBUTE, 0)

		if typeof(CafeUpgradeService._renderAll) == "function" then
			CafeUpgradeService:_renderAll()
		elseif typeof(CafeUpgradeService._buildVisuals) == "function" then
			for _, upgrade in CafeUpgradeConfig.UPGRADES do
				CafeUpgradeService:_buildVisuals(upgrade.Id)
			end
		end

		if typeof(CafeUpgradeService._refreshPlaque) == "function" then
			CafeUpgradeService:_refreshPlaque()
		end
	end)

	if not ok then
		return string.format("Failed to reset upgrades: %s", tostring(err))
	end

	return "All cafe upgrades reset to level 0."
end

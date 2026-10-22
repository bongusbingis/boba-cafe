--!strict
--[[
	CmdrService.luau
	Knit service managing the Cmdr developer / admin console (server side).
	Provides dev tools for testing in Studio, event triggering, economy grants,
	progression testing, world manipulation, and moderation.
]]

---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local Cmdr = require(Packages.Cmdr)
local RankUtil = require(Shared.Utility.RankUtil)

---> service declaration
local CmdrService = Knit.CreateService({
	Name = "CmdrService",
	Client = {},
})

---> lifecycle
function CmdrService:KnitInit()
	-- Register built-in default commands (teleport, respawn, kick, help, etc.)
	--Cmdr:RegisterDefaultCommands()

	-- Look for custom Cmdr folder under ServerScriptService.Server.Cmdr
	local serverScriptRoot = script.Parent.Parent
	local cmdrFolder = serverScriptRoot:FindFirstChild("Cmdr")
	if cmdrFolder then
		local typesFolder = cmdrFolder:FindFirstChild("Types")
		if typesFolder then
			Cmdr:RegisterTypesIn(typesFolder)
		end

		local commandsFolder = cmdrFolder:FindFirstChild("Commands")
		if commandsFolder then
			Cmdr:RegisterCommandsIn(commandsFolder)
		end
	else
		warn("[CmdrService] Custom Cmdr folder not found under ServerScriptService.Server")
	end

	-- Security / Permissions Hook
	Cmdr.Registry:RegisterHook("BeforeRun", function(context)
		-- In Studio, allow all commands unconditionally for testing
		if RunService:IsStudio() then
			return nil
		end

		local player = context.Executor
		if not player then
			return nil -- Server console execution
		end

		if player:GetAttribute("IsAdmin") == true then
			return nil
		end

		local ok, isMR = pcall(function()
			return RankUtil.IsMR(player)
		end)
		if ok and isMR then
			return nil
		end

		return "You do not have permission to execute this command."
	end)
end

function CmdrService:KnitStart()
	print("[CmdrService] Cmdr developer console successfully initialized.")
end

return CmdrService

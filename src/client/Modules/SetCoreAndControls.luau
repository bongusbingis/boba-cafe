--[[
    Module: SetCoreAndControls
    Description: Central place for disabling player movement and for driving
    StarterGui:SetCore / SetCoreGuiEnabled.

    Combines V3's ClientSetCoreController and PlayerControlsController.

    Controls are reference-counted by reason rather than a single boolean. Several
    systems disable movement independently — tripping on a spill and cleaning one can
    overlap — and with a plain boolean whichever finishes first re-enables movement
    while the other still wants it off. Controls come back only when every reason has
    released.
--]]

---> services
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

---> dependencies
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

---> module declaration
local SetCoreAndControls = Knit.CreateController({
	Name = "SetCoreAndControls",
})

---> constants

--- Reason used when a caller does not name one, preserving the old boolean behaviour.
local DEFAULT_REASON = "Default"

--- SetCore topics are not all registered the moment the client starts, so retry briefly.
local SET_CORE_RETRIES = 10
local SET_CORE_RETRY_DELAY = 0.5

---> state

local LocalPlayer = Players.LocalPlayer

-- Reasons currently holding movement disabled.
local disableReasons: { [string]: boolean } = {}
local controlsCached: any = nil

---> private

local function getControls()
	if controlsCached then
		return controlsCached
	end

	local playerScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	if not playerScripts then
		return nil
	end

	local playerModule = playerScripts:FindFirstChild("PlayerModule")
	if not playerModule then
		return nil
	end

	local ok, controls = pcall(function()
		return require(playerModule):GetControls()
	end)

	if not ok then
		warn("[SetCoreAndControls] Could not acquire PlayerModule controls:", controls)
		return nil
	end

	controlsCached = controls
	return controlsCached
end

--- Applies the state implied by the current set of reasons.
local function apply()
	local controls = getControls()
	if not controls then
		return
	end

	local shouldDisable = next(disableReasons) ~= nil

	if shouldDisable then
		controls:Disable()
	else
		controls:Enable()
	end
end

---> public

--[=[
	Enables or disables player movement.

	`reason` lets independent systems hold the lock without fighting each other. Callers
	that omit it share a single default slot, which matches the old behaviour.
]=]
function SetCoreAndControls:SetPlayerControlsEnabled(enabled: boolean, reason: string?)
	local key = reason or DEFAULT_REASON

	if enabled then
		disableReasons[key] = nil
	else
		disableReasons[key] = true
	end

	apply()
end

--- True when anything is currently holding movement disabled.
function SetCoreAndControls:AreControlsDisabled(): boolean
	return next(disableReasons) ~= nil
end

--- Clears every hold. For respawns, where stale locks would otherwise strand the player.
function SetCoreAndControls:ReleaseAll()
	table.clear(disableReasons)
	apply()
end

--- StarterGui:SetCore with retries, since some topics register late.
function SetCoreAndControls:SetCore(...)
	local args = table.pack(...)

	task.spawn(function()
		for attempt = 1, SET_CORE_RETRIES do
			if pcall(StarterGui.SetCore, StarterGui, table.unpack(args, 1, args.n)) then
				return
			end
			if attempt < SET_CORE_RETRIES then
				task.wait(SET_CORE_RETRY_DELAY)
			end
		end

		warn("[SetCoreAndControls] SetCore failed:", args[1])
	end)
end

--- StarterGui:SetCoreGuiEnabled, same retry behaviour.
function SetCoreAndControls:SetCoreGuiEnabled(coreGuiType: Enum.CoreGuiType, enabled: boolean)
	task.spawn(function()
		for attempt = 1, SET_CORE_RETRIES do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreGuiType, enabled) then
				return
			end
			if attempt < SET_CORE_RETRIES then
				task.wait(SET_CORE_RETRY_DELAY)
			end
		end

		warn("[SetCoreAndControls] SetCoreGuiEnabled failed:", coreGuiType)
	end)
end

---> lifecycle

function SetCoreAndControls:KnitStart()
	-- The PlayerModule is rebuilt on respawn, so drop the cache and clear any holds
	-- left over from a death mid-interaction.
	LocalPlayer.CharacterAdded:Connect(function()
		controlsCached = nil
		table.clear(disableReasons)
	end)
end

return SetCoreAndControls

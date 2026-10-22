--!nonstrict
--[[
	UiSfx
	Client sound cues (REVIVAL-001 SOUNDS). Looks up SoundService.SFX.UI.<Name> (else
	SoundService.UISounds.<Name>), plays a clone so cues overlap, and skips silently
	(one warn per name) when the sound is not authored. Never creates sound assets.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local WorldPath = require(ReplicatedStorage:WaitForChild("Shared").Utility.WorldPath)

---> constants
local SPEED_BASE = 1.0
local SPEED_STEP = 0.05
local SPEED_MAX = 1.25
local COMBO_STEPS_MAX = 5
local MIN_REPEAT_SECONDS = 0.05
local MIN_GAP_SECONDS = 0.15
local DEBRIS_SECONDS = 5
local COMBO_MILESTONES = { [3] = true, [5] = true, [10] = true }
-- multipliers on the authored Sound.Volume
local VOLUME = {
	Serve = 1.0,
	StepDone = 0.6,
	StepDone_Pour = 0.6,
	StepDone_Scoop = 0.6,
	StepDone_Machine = 0.6,
	StepDone_Blender = 0.6,
	StepDone_Grab = 0.6,
	Rush = 1.0,
	SuperSuccess = 1.0,
	LevelUp = 1.0,
	Success = 1.0,
	Pop1 = 0.8,
}

local UiSfx = {}

local warned: { [string]: boolean } = {}
local lastByName: { [string]: number } = {}
local lastAny = -math.huge

function UiSfx.Find(name: string): Sound?
	local sound = WorldPath.find(SoundService, { "SFX", "UI", name })
		or WorldPath.find(SoundService, { "UISounds", name })
	if sound and sound:IsA("Sound") then
		return sound
	end
	return nil
end

function UiSfx.ServeSpeed(comboN: number?): number
	return math.min(SPEED_BASE + SPEED_STEP * math.clamp((comboN or 1) - 1, 0, COMBO_STEPS_MAX), SPEED_MAX)
end

function UiSfx.IsComboMilestone(n: number): boolean
	return COMBO_MILESTONES[n] == true
end

-- Plays the first found name. Returns true when a sound was started.
function UiSfx.Play(names: string | { string }, options: { Speed: number?, Volume: number? }?): boolean
	local list = if typeof(names) == "table" then names else { names }
	for _, name in list do
		local sound = UiSfx.Find(name)
		if sound == nil then
			if not warned[name] then
				warned[name] = true
				warn(string.format("[UiSfx] SoundService.SFX.UI.%s not found; cue skipped.", name))
			end
			continue
		end

		local now = os.clock()
		if lastByName[name] ~= nil and now - lastByName[name] < MIN_REPEAT_SECONDS then
			return false
		end
		if name ~= "Serve" and now - lastAny < MIN_GAP_SECONDS then
			return false
		end
		lastByName[name] = now
		lastAny = now

		local ok = pcall(function()
			local clone = sound:Clone()
			clone.Volume = sound.Volume * (VOLUME[name] or 1) * ((options and options.Volume) or 1)
			if options and options.Speed then
				clone.PlaybackSpeed = options.Speed
			end
			if clone.SoundGroup == nil and SoundService:FindFirstChild("UISounds") then
				local group = SoundService.UISounds
				if group:IsA("SoundGroup") then
					clone.SoundGroup = group
				end
			end
			clone.Parent = SoundService
			clone.Ended:Once(function()
				clone:Destroy()
			end)
			Debris:AddItem(clone, DEBRIS_SECONDS)
			clone:Play()
		end)
		return ok
	end
	return false
end

return UiSfx

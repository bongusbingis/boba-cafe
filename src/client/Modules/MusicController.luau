--!strict
--[[
	MusicController
	Manages background cafe music and Rush Hour soundtrack transitions.
	- Plays ambient cafe music during regular hours.
	- When Rush Hour begins, plays the Rush sound cue and smoothly transitions to the Rush Hour theme.
	- When Rush Hour ends, transitions smoothly back to ambient cafe music.
]]

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local WorldPath = require(Shared.Utility.WorldPath)
local UiSfx = require(Shared.UI.Utility.UiSfx)

---> Constants

local CAFE_MUSIC_PATH = { "SFX", "Music", "CafeMusic" }
local RUSH_THEME_PATH = { "SFX", "Music", "RushTheme" }
local DEFAULT_VOLUME = 0.5
local FADE_DURATION = 0.8
local FADE_TWEEN = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

---> Controller

local MusicController = Knit.CreateController({
	Name = "MusicController",
})

local cafeMusic: Sound? = nil
local rushTheme: Sound? = nil
local activeTweenCafe: Tween? = nil
local activeTweenRush: Tween? = nil

local function fade(sound: Sound?, toVolume: number, stopOnZero: boolean?): Tween?
	if not sound then
		return nil
	end
	if toVolume > 0 and not sound.IsPlaying then
		sound.Volume = 0
		sound:Play()
	end
	local tween = TweenService:Create(sound, FADE_TWEEN, { Volume = toVolume })
	tween:Play()
	if stopOnZero then
		task.delay(FADE_DURATION, function()
			if sound.Volume <= 0.01 and sound.IsPlaying then
				sound:Stop()
			end
		end)
	end
	return tween
end

local function applyMusicState(isRush: boolean, playCue: boolean)
	if activeTweenCafe then
		activeTweenCafe:Cancel()
	end
	if activeTweenRush then
		activeTweenRush:Cancel()
	end

	if isRush then
		if playCue then
			UiSfx.Play("Rush")
		end
		activeTweenCafe = fade(cafeMusic, 0, true)
		activeTweenRush = fade(rushTheme, DEFAULT_VOLUME)
	else
		activeTweenRush = fade(rushTheme, 0, true)
		activeTweenCafe = fade(cafeMusic, DEFAULT_VOLUME)
	end
end

function MusicController:KnitStart()
	-- Audio instances are authored in the place under SoundService.SFX.Music.
	cafeMusic = WorldPath.find(SoundService, CAFE_MUSIC_PATH) :: Sound?
	rushTheme = WorldPath.find(SoundService, RUSH_THEME_PATH) :: Sound?

	if not cafeMusic and not rushTheme then
		task.spawn(function()
			cafeMusic = WorldPath.waitFor(SoundService, CAFE_MUSIC_PATH, 5) :: Sound?
			rushTheme = WorldPath.waitFor(SoundService, RUSH_THEME_PATH, 5) :: Sound?
			if cafeMusic or rushTheme then
				local isRush = Workspace:GetAttribute("RushHour") == true
				applyMusicState(isRush, false)
			end
		end)
	else
		local isRush = Workspace:GetAttribute("RushHour") == true
		applyMusicState(isRush, false)
	end

	local lastRush = Workspace:GetAttribute("RushHour") == true
	Workspace:GetAttributeChangedSignal("RushHour"):Connect(function()
		local currentRush = Workspace:GetAttribute("RushHour") == true
		if currentRush ~= lastRush then
			lastRush = currentRush
			applyMusicState(currentRush, currentRush)
		end
	end)
end

return MusicController

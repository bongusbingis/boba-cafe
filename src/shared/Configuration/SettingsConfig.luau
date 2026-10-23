local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
export type Setting = {
	Key: string,
	Label: string,
	--- Discriminates between a boolean toggle and a one-shot action button.
	--- Defaults to "Toggle" when omitted for backwards compatibility.
	Type: ("Toggle" | "Action")?,
	--- Toggle settings: the default on/off value.
	Default: boolean?,
	--- Action settings: called on the client when the button is pressed.
	--- Networking is the caller's responsibility.
	ClientCallback: (() -> ())?,
	--- Text shown inside the action button pill (e.g. "OPEN", "CLAIM").
	ButtonLabel: string?,
	--- Optional rank gate enforced by SettingsService. No current setting uses it (DEC-002).
	MinRank: number?,
	--- When set, this setting is only shown to players who own the specified game pass.
	--- The "Game Passes" category is hidden entirely if the player owns none of its passes.
	GamepassId: number?,
	--- Like GamepassId, for catalog-only passes the client cannot resolve: the row shows when
	--- the server set the player attribute with this name (PassSettingsService).
	PerkAttribute: string?,
	--- Game pass id offered on the locked row (needed for PerkAttribute rows; a GamepassId
	--- row uses GamepassId). Non-owners see the row locked with a "Get pass" button.
	PassId: number?,
}

export type Category = {
	Category: string,
	Settings: { Setting },
}

-- Audio groups are authored in the place: SoundService.Music (SFX.Music sounds) and
-- SoundService.UISounds (every other SFX and UI sound). A missing group skips the toggle
-- with a single warning.
local warnedAudioGroups: { [string]: boolean } = {}
local function setGroupVolume(name: string, isEnabled: boolean)
	local group = SoundService:FindFirstChild(name)
	if group and group:IsA("SoundGroup") then
		group.Volume = if isEnabled then 1 else 0
	elseif not warnedAudioGroups[name] then
		warnedAudioGroups[name] = true
		warn(`[Settings] SoundService.{name} is missing or not a SoundGroup; its volume toggle is skipped.`)
	end
end

local config: { Category } = {
	{
		Category = "Game Passes",
		Settings = {
			{
				Key = "HeadlessHead",
				Label = "Headless Head",
				Default = false,
				PerkAttribute = "PerkHeadlessHead",
				PassId = 14067340,
			},
			{
				Key = "FasterWalkSpeed",
				Label = "Faster Walk Speed",
				Default = false,
				PerkAttribute = "PerkWalkSpeed",
				PassId = 12385742,
			},
			{
				Key = "UniformRemoverEnabled",
				Label = "Keep My Outfit",
				Default = true,
				PerkAttribute = "PerkUniformRemover",
				PassId = 219651224,
			},
		},
	},
	{
		Category = "Game Audio",
		Settings = {
			{
				Key = "MusicEnabled",
				Label = "Music",
				Default = true,
				ClientCallback = function(isEnabled)
					setGroupVolume("Music", isEnabled)
				end,
			},
			{
				Key = "SFXEnabled",
				Label = "SFX",
				Default = true,
				ClientCallback = function(isEnabled)
					setGroupVolume("UISounds", isEnabled)
				end,
			},
		},
	},
	{
		Category = "Roleplay",
		Settings = {
			{
				Key = "ChangeNickname",
				Label = "Roleplay Nickname",
				Type = "Action",
				ButtonLabel = "CHANGE",
				ClientCallback = function()
					local Shared = ReplicatedStorage:WaitForChild("Shared")
					local NicknamePrompt = require(Shared.UI.Utility.NicknamePrompt)
					NicknamePrompt.Open()
				end,
			},
		},
	},
	{
		Category = "Staff",
		Settings = {
			-- Key kept so saved profiles need no migration; it now drives the kitchen station
			-- Highlight and guidance beam (M1.5c). No MinRank: hints are for every player (D8).
			{ Key = "SyrupHighlighting", Label = "Station hints", Default = true },
			{ Key = "ShiftTimerEnabled", Label = "Shift Timer", Default = true },
		},
	},
}

return config

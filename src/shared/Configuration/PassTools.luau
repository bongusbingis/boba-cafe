--!strict
--[[
	PassTools (REVIVAL-001 PASS-PORT lane D)
	Config for the fun-pass tools and the Emote Pack, ported from the live game
	(place 718328620). Pass ids and perks live in PassCatalog; this holds only
	behaviour constants and the emote list.
--]]

local PassTools = {}

PassTools.BuiltBy = "Claude"
PassTools.PassToolAttribute = "PassTool"

-- Perks (PassCatalog) that grant each tool.
PassTools.MopWhackPerk = "MopWhack"
PassTools.FlyingMopPerk = "FlyingMop"
PassTools.EmotePackPerk = "EmotePack"
PassTools.PumpkinLauncherPerk = "PumpkinLauncher"

PassTools.PumpkinLauncher = {
	ToolName = "Pumpkin Launcher",
}

PassTools.MopWhack = {
	ToolName = "Mop Whack",
	-- Live: 15s cooldown after a successful whack, 3.2s ragdoll.
	HitCooldownSeconds = 15,
	MissCooldownSeconds = 1.5,
	RagdollSeconds = 3.2,
	-- The swing connects this long after Activated (the wind-up).
	ImpactDelaySeconds = 0.3,
	RangeStuds = 10,
	-- Minimum dot product between the swinger's look vector and the direction to the victim.
	MinFacingDot = 0.25,
	LaunchHorizontal = 110,
	LaunchUp = 45,
}

PassTools.FlyingMop = {
	ToolName = "Flying Mop",
	-- ReplicatedStorage.SharedStorage.CharacterStorage.* (live-only assets, see report).
	StoragePath = { "SharedStorage", "CharacterStorage" },
	MopModelName = "FlyingMop",
	AnimationName = "FM_Animation",
	MopCharacterName = "FlyingMop",
	MopC0 = CFrame.new(0, -1.35, -0.75) * CFrame.Angles(math.rad(-90), 0, 0),
	FadeInDelaySeconds = 0.65,
	FadeInSeconds = 1,
	SwirlSeconds = 0.5,
	-- Client flight.
	MoveReach = 10,
	LerpAlpha = 0.2,
	BobDivisor = 1.5,
	HoverHeight = 5,
	RayDown = -100,
}

-- Ordered: the Roblox emote menu shows up to 8 equipped emotes in this order.
-- Ids are the live game's Emote Pack animations (SharedStorage.AnimationStorage.Emotes).
PassTools.Emotes = {
	{ Name = "Happy", AnimationId = 16829264228 },
	{ Name = "Baby", AnimationId = 14352340648 },
	{ Name = "Side to Side", AnimationId = 10714366910 },
	{ Name = "Cheer", AnimationId = 10714016223 },
	{ Name = "Twirl", AnimationId = 10714293450 },
	{ Name = "Shrug", AnimationId = 10714374484 },
	{ Name = "Check my Angles", AnimationId = 15392752812 },
	{ Name = "What is Love", AnimationId = 13327655243 },
}

return PassTools

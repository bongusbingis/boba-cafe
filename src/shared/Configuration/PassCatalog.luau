--!strict
--[[
	PassCatalog
	The single source of truth for game passes: pass id -> perks, shop/board
	display data, and sale bookkeeping (revival-plan 6.3, DEC-028 E20). This
	merges the old PassCatalog (perks), Gamepasses (Name/Description/Icon/Rank)
	and GamepassConfig (group-rank ids, which duplicated Rank) so a pass is
	defined in exactly one place. Owners get the perks whether the pass is
	Listed or not. Listed only says whether the shop shows it; real sale state
	is set on the Roblox dashboard. Deferred (DEC-028): x2/x4 Multiplier, Unlock All
	Pets, Unlimited Stock. Perk effects live in Perks.luau.

	Display fields are optional: entries without Description/Icon (legacy passes,
	Mop Whack) render through the shop and board fallbacks. Rank is the legacy
	group-rank association and is currently informational only. Perks may be
	empty for display-only passes that grant nothing yet.
]]

export type PassEntry = {
	Name: string,
	Description: string?,
	Icon: string?,
	Rank: number?,
	Perks: { string },
	Listed: boolean,
	Legacy: boolean,
}

local PassCatalog: { [number]: PassEntry } = {
	[6202153] = {
		Name = "Barista",
		Description = "Become a Barista immediately without having to train for it!",
		Icon = "rbxassetid://16709481934",
		Rank = 8,
		Perks = { "TipBoost25", "XpBoost25" },
		Listed = true,
		Legacy = false,
	},
	[6202144] = {
		Name = "Senior Barista",
		Perks = { "TipBoost25", "XpBoost25" },
		Listed = false,
		Legacy = true,
	},
	[15243046] = {
		Name = "Kitchen Leader",
		Description = "Become a Kitchen Leader immediately without having to earn it!",
		Icon = "rbxassetid://16728123715",
		Rank = 10,
		Perks = { "TipBoost50", "XpBoost50" },
		Listed = true,
		Legacy = false,
	},
	[6202139] = {
		Name = "Staff Assistant",
		Perks = { "TipBoost50", "XpBoost50" },
		Listed = false,
		Legacy = true,
	},
	[12385781] = {
		Name = "VIP",
		Description = "Unlock exclusive VIP features including special patio access, 2x rewards, and a specialized chat color!",
		Icon = "rbxassetid://16728139086",
		Perks = { "DailyReward2x", "VipLounge", "VipTag" },
		Listed = true,
		Legacy = false,
	},
	[2126368] = { Name = "Premium Lounge", Perks = { "VipLounge" }, Listed = false, Legacy = true },
	[219650999] = {
		Name = "Star Employee",
		Description = "Unlock an exclusive benefits package to make your job easier!",
		Icon = "rbxassetid://16728123956",
		Perks = { "QuestSlot", "QuestReroll" },
		Listed = true,
		Legacy = false,
	},
	[12385834] = {
		Name = "More Quests",
		Description = "Get +1 daily quest slot!",
		Perks = { "QuestSlot" },
		Listed = false,
		Legacy = true,
	},
	[12385760] = {
		Name = "Instant Brewing",
		Description = "Create drinks 2x faster!",
		Icon = "rbxassetid://16728132011",
		Perks = { "StationHold50" },
		Listed = true,
		Legacy = false,
	},
	[12385742] = {
		Name = "Faster Walk Speed",
		Description = "Increase your walk speed by 90%!",
		Icon = "rbxassetid://16728131311",
		Perks = { "WalkSpeed" },
		Listed = true,
		Legacy = false,
	},
	[14067346] = {
		Name = "Double Storage",
		Perks = { "InventoryX2" },
		Listed = false,
		Legacy = true,
	},
	-- PASS-PORT (2026-10-21): ported from the live place 718328620.
	[12385796] = {
		Name = "Rainbow Pack",
		Description = "Stand out with a rainbow nametag, emoji, and trail!",
		Perks = { "RainbowPack" },
		Listed = true,
		Legacy = false,
	},
	[219651224] = {
		Name = "Uniform Remover",
		Description = "Remove your uniform and wear your own style in the cafe!",
		Icon = "rbxassetid://16728123822",
		Perks = { "UniformRemover" },
		Listed = true,
		Legacy = false,
	},
	[219651061] = {
		Name = "Emote Pack",
		Description = "Enjoy a set of popular dances that make you stand out from the crowd!",
		Icon = "rbxassetid://16728123417",
		Perks = { "EmotePack" },
		Listed = true,
		Legacy = false,
	},
	[40973940] = { Name = "Mop Whack", Perks = { "MopWhack" }, Listed = true, Legacy = false },
	[219651106] = {
		Name = "Flying Mop",
		Description = "Stand out from the crowd with your own flying mop to get around the cafe faster!",
		Icon = "rbxassetid://16728123822",
		Perks = { "FlyingMop" },
		Listed = true,
		Legacy = false,
	},
	[14067340] = {
		Name = "Headless Head",
		Description = "Toggle your character's head to be invisible anytime from Settings!",
		Icon = "rbxassetid://16728123607",
		Perks = { "HeadlessHead" },
		Listed = true,
		Legacy = false,
	},
	-- Display-only passes: sold in the shop before, but wired to no perks yet.
	-- Delisted until they grant something (Jack).
	[29083693] = {
		Name = "Nametag Customizer",
		Description = "Customize your nametag with a variety of colors!",
		Icon = "rbxassetid://16728123607",
		Perks = {},
		Listed = false,
		Legacy = false,
	},
	[219651161] = {
		Name = "Water Pack",
		Description = "Buckle up and unleash the thrill as you conquer the waves!",
		Icon = "rbxassetid://16709440324",
		Perks = {},
		Listed = false,
		Legacy = false,
	},
}

return PassCatalog

--!strict
--[[
	PassCatalog
	Pass id -> perks (revival-plan 6.3, DEC-028 E20). Owners get the perks whether the
	pass is Listed or not. Listed only says whether the shop shows it; real sale state
	is set on the Roblox dashboard. Deferred (DEC-028): x2/x4 Multiplier, Unlock All
	Pets, Unlimited Stock. Perk effects live in Perks.luau.
--]]

export type PassEntry = {
	Name: string,
	Perks: { string },
	Listed: boolean,
	Legacy: boolean,
}

local PassCatalog: { [number]: PassEntry } = {
	[6202153] = { Name = "Barista", Perks = { "TipBoost25", "XpBoost25" }, Listed = true, Legacy = false },
	[6202144] = { Name = "Senior Barista", Perks = { "TipBoost25", "XpBoost25" }, Listed = false, Legacy = true },
	[15243046] = { Name = "Kitchen Leader", Perks = { "TipBoost50", "XpBoost50" }, Listed = true, Legacy = false },
	[6202139] = { Name = "Staff Assistant", Perks = { "TipBoost50", "XpBoost50" }, Listed = false, Legacy = true },
	[12385781] = {
		Name = "VIP",
		Perks = { "DailyReward2x", "VipLounge", "VipTag" },
		Listed = true,
		Legacy = false,
	},
	[2126368] = { Name = "Premium Lounge", Perks = { "VipLounge" }, Listed = false, Legacy = true },
	[219650999] = { Name = "Star Employee", Perks = { "QuestSlot", "QuestReroll" }, Listed = true, Legacy = false },
	[12385834] = { Name = "More Quests", Perks = { "QuestSlot" }, Listed = false, Legacy = true },
	[12385760] = { Name = "Instant Brewing", Perks = { "StationHold50" }, Listed = true, Legacy = false },
	[12385742] = { Name = "Faster Walk Speed", Perks = { "WalkSpeed" }, Listed = true, Legacy = false },
	[14067346] = { Name = "Double Storage", Perks = { "InventoryX2" }, Listed = false, Legacy = true },
	-- PASS-PORT (2026-10-21): ported from the live place 718328620.
	[12385796] = { Name = "Rainbow Pack", Perks = { "RainbowPack" }, Listed = true, Legacy = false },
	[219651224] = { Name = "Uniform Remover", Perks = { "UniformRemover" }, Listed = true, Legacy = false },
	[219651061] = { Name = "Emote Pack", Perks = { "EmotePack" }, Listed = true, Legacy = false },
	[40973940] = { Name = "Mop Whack", Perks = { "MopWhack" }, Listed = true, Legacy = false },
	[219651106] = { Name = "Flying Mop", Perks = { "FlyingMop" }, Listed = true, Legacy = false },
}

return PassCatalog

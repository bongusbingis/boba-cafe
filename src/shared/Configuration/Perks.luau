--!strict
--[[
	Perks
	Boost values (revival-plan 6.3, DEC-028 E20/E21, DEC-036 B3). Within a Family the
	highest value wins; values never add. Perks not listed here (DailyReward2x,
	QuestSlot, StationHold50, ...) are flags still read by their own systems.
--]]

export type Boost = {
	Family: string,
	Value: number,
}

local Perks: { [string]: Boost } = {
	TipBoost25 = { Family = "Tip", Value = 0.25 },
	TipBoost50 = { Family = "Tip", Value = 0.50 },
	XpBoost25 = { Family = "Xp", Value = 0.25 },
	XpBoost50 = { Family = "Xp", Value = 0.50 },
}

-- Equipped-pet tip bonus by tier (DEC-028 E21). Unknown tiers give 0.
local PetTipBonus: { [string]: number } = {
	Basic = 0.02,
	Rare = 0.04,
	Epic = 0.07,
	Legendary = 0.10,
}

return {
	Perks = Perks,
	PetTipBonus = PetTipBonus,
	-- Double Storage (InventoryX2) doubles Storage limits, DEC-028 E20 / revival-plan 6.3.
	StorageMultiplier = 2,
}

--!strict
--[[
	Progression
	XP curve, level gates, ticket slots, titles and cosmetic rewards
	(REVIVAL-001 M2-PROGRESS, design 5.3-5.4). Pure data and functions.
	Every number is a placeholder until Jack approves it (DEC-017/018).
--]]

export type CosmeticReward = { ItemType: string, Name: string, Tier: string }

local Progression = {}

Progression.XP_PER_ITEM = 10 -- PROPOSED (Jack)
Progression.XP_PERFECT = 5 -- PROPOSED (Jack)
Progression.XP_FAST = 5 -- PROPOSED (Jack)
Progression.MAX_LEVEL = 50 -- PROPOSED (Jack)

-- Level at which each item or option opens for NPC orders (design 5.3). PROPOSED (Jack)
Progression.MIN_LEVEL_BY_ITEM = {
	["Classic Milk Tea Boba"] = 1,
	["Regular Coffee"] = 1,
	["Fudge Brownie"] = 1,
	["Taro Syrup"] = 2,
	["Strawberry Syrup"] = 2,
	["Hot Cocoa Classic"] = 3,
	["Macarons"] = 4,
	["Strawberry Tapioca"] = 4,
	["Two-Item Orders"] = 5,
	["Iced Coffee Option"] = 6,
	["Espresso"] = 7,
	["Cappuccino"] = 7,
	["Sugar Option"] = 7,
	["Mango Syrup"] = 8,
	["Matcha Syrup"] = 8,
	["Mochis"] = 8,
	["Caramel Hot Cocoa"] = 9,
	["Vanilla Hot Cocoa"] = 9,
	["Mystic Burst Tapioca"] = 10,
	["Banana Blast Tapioca"] = 10,
	["Americano"] = 12,
	["Ice Creams"] = 12,
	["Brown Sugar Syrup"] = 15,
	["Chocolate Syrup"] = 15,
	["Passion Fruit Syrup"] = 15,
	["Three-Item Orders"] = 15,
} :: { [string]: number }

-- Ticket slots a barista may hold from each level. PROPOSED (Jack)
Progression.TICKET_SLOTS = { [1] = 1, [5] = 2 } :: { [number]: number }

-- Title text from each level up (every 5 levels). Names PROPOSED (Jack).
Progression.TITLES = {
	[1] = "Trainee",
	[5] = "Barista",
	[10] = "Senior Barista",
	[15] = "Head Barista",
	[20] = "Boba Expert",
	[25] = "Boba Specialist",
	[30] = "Boba Master",
	[35] = "Boba Maestro",
	[40] = "Boba Champion",
	[45] = "Boba Hero",
	[50] = "Boba Legend",
} :: { [number]: string }

-- Nametags in Nametags.luau file order (first ten entries). PROPOSED (Jack)
Progression.COSMETIC_REWARDS = {
	[5] = { ItemType = "Nametags", Name = "Crimson", Tier = "Basic" },
	[10] = { ItemType = "Nametags", Name = "Blue", Tier = "Basic" },
	[15] = { ItemType = "Nametags", Name = "Turquoise", Tier = "Basic" },
	[20] = { ItemType = "Nametags", Name = "Emerald", Tier = "Basic" },
	[25] = { ItemType = "Nametags", Name = "Violet", Tier = "Basic" },
	[30] = { ItemType = "Nametags", Name = "Orange", Tier = "Basic" },
	[35] = { ItemType = "Nametags", Name = "Slate", Tier = "Basic" },
	[40] = { ItemType = "Nametags", Name = "Gold", Tier = "Uncommon" },
	[45] = { ItemType = "Nametags", Name = "Rose", Tier = "Uncommon" },
	[50] = { ItemType = "Nametags", Name = "Bubblegum", Tier = "Uncommon" },
} :: { [number]: CosmeticReward }

-- XP needed to go from `level` to `level + 1`.
function Progression.XpToNext(level: number): number
	return 60 + 25 * level + 2 * level ^ 2
end

-- Level for a total XP amount, walking the curve; capped at MAX_LEVEL.
function Progression.LevelForXp(totalXp: number): number
	local level = 1
	local remaining = totalXp
	while level < Progression.MAX_LEVEL do
		local need = Progression.XpToNext(level)
		if remaining < need then
			break
		end
		remaining -= need
		level += 1
	end
	return level
end

-- Ticket slots at `level`: the value of the highest TICKET_SLOTS key at or below it.
function Progression.SlotsFor(level: number): number
	local best, slots = 0, 1
	for from, count in Progression.TICKET_SLOTS do
		if from <= level and from > best then
			best, slots = from, count
		end
	end
	return slots
end

-- Title at `level`: the highest TITLES key at or below it.
function Progression.TitleFor(level: number): string
	local best, title = 0, ""
	for from, text in Progression.TITLES do
		if from <= level and from > best then
			best, title = from, text
		end
	end
	return title
end

return Progression

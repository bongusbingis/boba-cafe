--!strict
--[[
	CustomerConfig
	Plain data for NPC customers (REVIVAL-001 M1.4b). Read by CustomerService and
	its Rules. Source: M1.2 design sections 4.2 (pacing), 4.4 (orders), 4.5
	(patience) and 7 (slice menu).

	Every value is TUNING. There are no BobaBucks or XP numbers in this file: the
	pay table holds dev placeholders marked -- PROPOSED (Jack) until Jack approves the economy.
--]]

export type OrderItem = { Category: string, Item: string, CustomInfo: { [string]: any } }
export type PoolEntry = {
	Key: string,
	Label: string,
	Weight: number,
	MinLevel: number,
	Sized: boolean,
	OrderItem: OrderItem,
}
export type SizeWeight = { Size: string, Weight: number }

local Progression = require(script.Parent.Progression)

local CustomerConfig = {
	ASSIGNMENT_MODE = "Dedicated", -- the only mode: the barista who takes the order at the register serves it (auto-assign removed, TAKEOVER-FIX 2)

	---> pacing (design 4.2)
	-- NPCs present = min(SERVER_CAP, slots + line), where
	--   slots = clocked-in baristas * SLOTS_PER_BARISTA
	--   line  = LINE_BASE + floor(baristas / LINE_BARISTAS_PER_EXTRA)
	SERVER_CAP = 16, -- TUNING: most NPCs present at once (M5 measures performance)
	SLOTS_PER_BARISTA = 1, -- TUNING: ticket slots per clocked-in barista (a second slot comes from L5 in M2)
	LINE_BASE = 1, -- TUNING: NPCs always waiting visibly in line
	LINE_BARISTAS_PER_EXTRA = 4, -- TUNING: one more waiting NPC per this many baristas
	SPAWN_GAP_SECONDS = 3, -- TUNING: minimum time between two spawns

	---> patience (design 4.5)
	-- patience = PATIENCE_BASE_SECONDS + one bonus per order item, looked up by the item's Menu category.
	PATIENCE_BASE_SECONDS = 45, -- TUNING
	PATIENCE_BONUS_SECONDS = {
		["Boba Teas"] = 25, -- TUNING
		["Hot Cocoas"] = 25, -- TUNING
		["Coffees"] = 15, -- TUNING
		["Teas"] = 15, -- TUNING
	} :: { [string]: number },
	PATIENCE_GRAB_BONUS_SECONDS = 10, -- TUNING: any category not listed above (food you grab)
	PATIENCE_YELLOW_FRACTION = 0.5, -- TUNING: the bar turns yellow at or below this fraction left
	PATIENCE_RED_FRACTION = 0.25, -- TUNING: the bar turns red at or below this fraction left
	PATIENCE_RAMP_FIRST_SHIFT = 3, -- PROPOSED (REVIVAL-001 C6, DEC-053): first session shift that is trimmed
	PATIENCE_RAMP_TRIM_PER_SHIFT = 0.05, -- PROPOSED (REVIVAL-001 C6, DEC-053): extra trim per shift from the first trimmed one
	PATIENCE_RAMP_MAX_TRIM = 0.10, -- PROPOSED (REVIVAL-001 C6, DEC-053): the trim never exceeds this
	-- Register patience (TAKEOVER-FIX 2): an NPC at the register whose order nobody takes walks out
	-- unhappy (a walkout: rating drops). Same seconds and ramp as pickup patience, times this mult.
	REGISTER_PATIENCE_MULT = 1, -- DEC-058 agent-set, Jack to tune
	REGISTER_TAKE_ORDER_GRACE_SECONDS = 30, -- DEC-058 agent-set, Jack to tune: "Take Order" leaves at least this long to enter it
	-- An NPC still in line after this long gives up quietly (no walkout, no rating change): clears a Rush backlog.
	QUEUE_PATIENCE_SECONDS = 120, -- DEC-058 agent-set, Jack to tune
	-- TAKEOVER-REVIEW-FIX P2-3: with nobody clocked in, patience is paused; after this long the waiting NPCs go
	-- home quietly (no walkout, no rating change) so a crowd never stays forever.
	EMPTY_CAFE_DISMISS_SECONDS = 60, -- DEC-058 agent-set, Jack to tune

	---> order pool: the M1 slice (design 4.4 and 7)
	-- PENDING JACK Q3: whether boba keeps 3 sizes. If not, this is a config-only change.
	SIZE_WEIGHTS = {
		{ Size = "Small", Weight = 30 }, -- TUNING
		{ Size = "Medium", Weight = 40 }, -- TUNING
		{ Size = "Large", Weight = 30 }, -- TUNING
	} :: { SizeWeight },
	-- Each entry is a Menu order item for OrderSpec.FromOrderItem ({ Category, Item, CustomInfo }).
	-- Sized entries get CustomInfo.Size from SIZE_WEIGHTS when an order is picked.
	ORDER_POOL = {
		{
			Key = "Classic Milk Tea Boba",
			Label = "Classic Milk Tea Boba",
			Weight = 55, -- TUNING: Classic Milk Tea Boba
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Classic Milk Tea Boba"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Classic Milk Tea", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Regular Coffee",
			Label = "Regular Coffee",
			Weight = 30, -- TUNING: Regular coffee, hot, no sugar (Iced and Sugar are off in the slice)
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Regular Coffee"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Coffees",
				Item = "Regular",
				CustomInfo = { Iced = false, Sugar = false },
			},
		},
		{
			Key = "Fudge Brownie",
			Label = "Fudge Brownie",
			Weight = 15, -- TUNING: Fudge Brownie
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Fudge Brownie"], -- PROPOSED (Jack) via Progression
			Sized = false,
			OrderItem = {
				Category = "Pastries",
				Item = "Fudge Brownie",
				CustomInfo = {},
			},
		},
		{
			Key = "Taro Syrup",
			Label = "Taro Boba",
			Weight = 10, -- PROPOSED (Jack): Taro Boba
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Taro Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Taro", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Strawberry Syrup",
			Label = "Strawberry Boba",
			Weight = 10, -- PROPOSED (Jack): Strawberry Boba
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Strawberry Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Strawberry", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Espresso",
			Label = "Espresso",
			Weight = 8, -- PROPOSED (Jack): Espresso
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Espresso"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Coffees",
				Item = "Espresso",
				CustomInfo = { Iced = false, Sugar = false },
			},
		},
		{
			Key = "Mango Syrup",
			Label = "Mango Boba",
			Weight = 8, -- PROPOSED (Jack): Mango Boba
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Mango Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Mango", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Matcha Syrup",
			Label = "Matcha Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Matcha Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Matcha", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Coconut Syrup",
			Label = "Coconut Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Coconut Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Coconut", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Green Tea Syrup",
			Label = "Green Tea Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Green Tea Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Green Tea", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Strawberry Banana Syrup",
			Label = "Strawberry Banana Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Strawberry Banana Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Strawberry Banana", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Lychee Syrup",
			Label = "Lychee Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Lychee Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Lychee", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Strawberry Tapioca",
			Label = "Strawberry Tapioca Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Strawberry Tapioca"], -- via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Classic Milk Tea", ["Tapioca Flavor"] = "Strawberry" },
			},
		},
		{
			Key = "Chocolate Banana Syrup",
			Label = "Chocolate Banana Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Chocolate Banana Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Chocolate Banana", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Thai Milk Tea Syrup",
			Label = "Thai Milk Tea Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Thai Milk Tea Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Thai Milk Tea", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Watermelon Syrup",
			Label = "Watermelon Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Watermelon Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Watermelon", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Raspberry Syrup",
			Label = "Raspberry Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Raspberry Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Raspberry", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Mystic Burst Tapioca",
			Label = "Mystic Burst Tapioca Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Mystic Burst Tapioca"], -- via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Classic Milk Tea", ["Tapioca Flavor"] = "Mystic Burst" },
			},
		},
		{
			Key = "Banana Blast Tapioca",
			Label = "Banana Blast Tapioca Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Banana Blast Tapioca"], -- via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Classic Milk Tea", ["Tapioca Flavor"] = "Banana Blast" },
			},
		},
		{
			Key = "Cherry Syrup",
			Label = "Cherry Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Cherry Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Cherry", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Guava Syrup",
			Label = "Guava Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Guava Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Guava", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Dragon Fruit Syrup",
			Label = "Dragon Fruit Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Dragon Fruit Syrup"], -- PROPOSED (Jack) via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Dragon Fruit", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Brown Sugar Syrup",
			Label = "Brown Sugar Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Brown Sugar Syrup"], -- via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Brown Sugar", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Chocolate Syrup",
			Label = "Chocolate Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Chocolate Syrup"], -- via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Chocolate", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Key = "Passion Fruit Syrup",
			Label = "Passion Fruit Boba",
			Weight = 1, -- PROPOSED (Jack): newcomer headroom for CLASSIC_MIN_SHARE
			MinLevel = Progression.MIN_LEVEL_BY_ITEM["Passion Fruit Syrup"], -- via Progression
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Passion Fruit", ["Tapioca Flavor"] = "Normal" },
			},
		},
	} :: { PoolEntry },
	CLASSIC_MIN_SHARE = 0.6, -- TUNING: classics keep at least this share of the eligible weight at every level
	NEW_ENTRY_MAX_WEIGHT = 10, -- TUNING: no level-2+ entry may weigh more than this

	-- Items per NPC order by level: the value of the highest key at or below the level.
	ITEM_COUNT_BY_LEVEL = { [1] = 1, [5] = 2, [15] = 3 } :: { [number]: number }, -- PROPOSED (Jack)

	---> pay (design 3.5, 5.8)
	-- Keys are the Category strings the ORDER_POOL entries use. The packet
	-- spellings ("Coffee", "Hot Cocoa", "Tea", "Grab") alias the same values
	-- so both spellings pay the same.
	PAY_TABLE = {
		["Boba Teas"] = 3, -- DEC-024 (E1)
		["Coffees"] = 2, -- DEC-024 (E1)
		["Coffee"] = 2, -- DEC-024 (E1)
		["Hot Cocoas"] = 2, -- DEC-024 (E1)
		["Hot Cocoa"] = 2, -- DEC-024 (E1)
		["Teas"] = 2, -- DEC-024 (E1)
		["Tea"] = 2, -- DEC-024 (E1)
		["Pastries"] = 1, -- DEC-024 (E1)
		["Grab"] = 1, -- DEC-024 (E1)
	} :: { [string]: number },
	GRADE_MULT = { Perfect = 1.0, Close = 0.5 }, -- DEC-024
	FAST_MULT = 1.5, -- DEC-024
	FAST_FRACTION = 0.5, -- DEC-024
	COMBO_STEP = 0.1, -- DEC-024
	COMBO_CAP = 0.5, -- DEC-024
	RESCUE_MULT = 1.5, -- DEC-024
	RESCUE_FRACTION = 0.3, -- DEC-024
	MIN_PAY = 1, -- DEC-024

	---> variants (design 4.10, DEC-011, DEC-015)
	-- Rules.PickVariant rolls once: Karen first, then VIP in the next band. The level is the highest
	-- among clocked-in baristas. Scripted first-session NPCs are always normal.
	VARIANTS = {
		VIP = { MinLevel = 6, Chance = 0.10, PatienceMult = 0.75, PayMult = 2 }, -- PROPOSED (Jack)
		Karen = { -- PROPOSED (Jack)
			MinLevel = 10, -- PROPOSED (Jack)
			Chance = 0.10, -- PROPOSED (Jack): v4 value
			PatienceMult = 0.5, -- PROPOSED (Jack)
			PayMult = 3, -- PROPOSED (Jack)
			PayMultGrade = "Perfect", -- PROPOSED (Jack): the multiplier only applies to this grade
			StompOnClose = true, -- PROPOSED (Jack): leaves angry after a Close serve
		},
	} :: {
		[string]: {
			MinLevel: number,
			Chance: number,
			PatienceMult: number,
			PayMult: number,
			PayMultGrade: string?,
			StompOnClose: boolean?,
		},
	},

	---> first session (design 4.4)
	-- While the assigned barista's Statistics.CustomersServed is below
	-- FIRST_SESSION_COUNT, the NPC order is FIRST_SESSION_ORDERS[served + 1]
	-- and the NPC is Scripted (its patience does not tick).
	FIRST_SESSION_COUNT = 3, -- TUNING
	-- Field names copied from the ORDER_POOL entries above (Size lives in
	-- CustomInfo, as Rules.PickOrder writes it).
	FIRST_SESSION_ORDERS = { -- TUNING
		{
			Category = "Boba Teas",
			Item = "Custom Boba",
			CustomInfo = { ["Syrup Flavor"] = "Classic Milk Tea", ["Tapioca Flavor"] = "Normal", Size = "Medium" },
		},
		{
			Category = "Pastries",
			Item = "Fudge Brownie",
			CustomInfo = {},
		},
		{
			Category = "Coffees",
			Item = "Regular",
			CustomInfo = { Iced = false, Sugar = false, Size = "Small" },
		},
	} :: { OrderItem },
}

return CustomerConfig

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
export type PoolEntry = { Weight: number, MinLevel: number, Sized: boolean, OrderItem: OrderItem }
export type SizeWeight = { Size: string, Weight: number }

local CustomerConfig = {
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
			Weight = 55, -- TUNING: Classic Milk Tea Boba
			MinLevel = 1, -- PROPOSED (Jack): see Progression.MIN_LEVEL_BY_ITEM
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Classic Milk Tea", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Weight = 30, -- TUNING: Regular coffee, hot, no sugar (Iced and Sugar are off in the slice)
			MinLevel = 1, -- PROPOSED (Jack): see Progression.MIN_LEVEL_BY_ITEM
			Sized = true,
			OrderItem = {
				Category = "Coffees",
				Item = "Regular",
				CustomInfo = { Iced = false, Sugar = false },
			},
		},
		{
			Weight = 15, -- TUNING: Fudge Brownie
			MinLevel = 1, -- PROPOSED (Jack): see Progression.MIN_LEVEL_BY_ITEM
			Sized = false,
			OrderItem = {
				Category = "Pastries",
				Item = "Fudge Brownie",
				CustomInfo = {},
			},
		},
	} :: { PoolEntry },

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

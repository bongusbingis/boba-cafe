--!strict
--[[
	CustomerConfig
	Plain data for NPC customers (REVIVAL-001 M1.4b). Read by CustomerService and
	its Rules. Source: M1.2 design sections 4.2 (pacing), 4.4 (orders), 4.5
	(patience) and 7 (slice menu).

	Every value is TUNING. There are no BobaBucks or XP numbers in this file: the
	pay table is empty until Jack answers Q5/Q6.
--]]

export type OrderItem = { Category: string, Item: string, CustomInfo: { [string]: any } }
export type PoolEntry = { Weight: number, Sized: boolean, OrderItem: OrderItem }
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
			Sized = true,
			OrderItem = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Classic Milk Tea", ["Tapioca Flavor"] = "Normal" },
			},
		},
		{
			Weight = 30, -- TUNING: Regular coffee, hot, no sugar (Iced and Sugar are off in the slice)
			Sized = true,
			OrderItem = {
				Category = "Coffees",
				Item = "Regular",
				CustomInfo = { Iced = false, Sugar = false },
			},
		},
		{
			Weight = 15, -- TUNING: Fudge Brownie
			Sized = false,
			OrderItem = {
				Category = "Pastries",
				Item = "Fudge Brownie",
				CustomInfo = {},
			},
		},
	} :: { PoolEntry },

	---> pay
	-- PENDING JACK Q5/Q6 (economy gate)
	PAY_TABLE = {} :: { [string]: number },
}

return CustomerConfig

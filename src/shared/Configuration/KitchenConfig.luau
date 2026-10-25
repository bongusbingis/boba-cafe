--[[
    Module: KitchenConfig
    Description: Configuration constants for the kitchen interaction system.
--]]

---> Constants

local KitchenConfig = {}

KitchenConfig.PROMPT_DISTANCE = 6
KitchenConfig.INTERACTION_COOLDOWN = 0.5
KitchenConfig.ANIMATION_MARKER_NAME = "NextAction"
KitchenConfig.MAX_INTERACTION_DISTANCE = 10
KitchenConfig.MAX_HELD_TOOLS = 10 -- TUNING: GiveTool refuses at this many Tools (backpack + equipped)

-- Station skill moment (BIG-B7). After a pour station (recipes with SkillMoment = true)
-- an optional meter appears; a tap in the zone marks the drink for a flat tip at serve.
-- Skipping or missing is the normal result. Set false to turn the whole feature off.
KitchenConfig.SKILL_MOMENTS_ENABLED = true
KitchenConfig.POUR_METER = {
	PERIOD_SECONDS = 1.6, -- DEC-058 Opus-set, Jack to tune: one 0 -> 1 -> 0 sweep
	DURATION_SECONDS = 3.2, -- DEC-058 Opus-set, Jack to tune: two sweeps, then it closes
	ZONE_WIDTH = 0.28, -- TUNING (was 0.24): Outer / Good zone width, slightly wider
	PERFECT_WIDTH = 0.18, -- TUNING (was 0.10): Inner / Perfect sweet spot width, significantly wider
	ZONE_CENTER_MIN = 0.45, -- DEC-058 Opus-set, Jack to tune
	ZONE_CENTER_MAX = 0.8, -- DEC-058 Opus-set, Jack to tune
	LATENCY_ALLOWANCE_SECONDS = 0.1, -- TUNING (was 0.3): tightened so latency allowance does not exceed sweet spot width
	TIP_PER_PERFECT = 5, -- TUNING (was 2): BB per perfect pour, paid at NPC serve (was 1; AUDIT-FIX D2.1)
	MAX_PERFECT_PER_DRINK = 2, -- DEC-058 Opus-set, Jack to tune
	MIN_CUSTOMERS_SERVED = 1, -- DEC-058 Opus-set, Jack to tune: hidden until the first serve
}

-- Restocking System Configuration (legacy port)
KitchenConfig.RESTOCK_HOLD_DURATION = 3
KitchenConfig.RESTOCK_XP_AWARD = 25
KitchenConfig.RESTOCK_BOX_ANIMATION_ID = "rbxassetid://75777393079152"
KitchenConfig.RESTOCK_BOX_MESH_ID = "rbxassetid://15518122178"
KitchenConfig.RESTOCK_BOX_TEXTURE_ID = "rbxassetid://15518180983"
KitchenConfig.UNLIMITED_STOCK_PASS_ID = 43707849

-- Default stock capacity per station name or pattern
KitchenConfig.DEFAULT_STOCKS = {
	["Food Display"] = 20,
	["Fruits Freezer"] = 20,
	["Ice Cream Freezer"] = 20,
	["Cup"] = 16,
	["Clear Cup"] = 16,
	["Mug"] = 10,
	["Lids"] = 10,
	["Milk"] = 10,
	["Sugar"] = 10,
	["Ice Machine"] = 10,
	["Blender"] = 6,
	["Coffee Machine"] = 6,
	["Syrups"] = 8, -- default for all syrups
	["Tapioca"] = 10, -- default for all tapioca jars
	["Powder"] = 10, -- default for all tea / hot chocolate powders
	["Default"] = 10,
}

--- Resolves default stock for a given station name
function KitchenConfig.GetDefaultStock(stationName: string): number
	local direct = KitchenConfig.DEFAULT_STOCKS[stationName]
	if direct ~= nil then
		return direct
	end
	if string.find(stationName, "Syrup") then
		return KitchenConfig.DEFAULT_STOCKS["Syrups"]
	end
	if string.find(stationName, "Tapioca") then
		return KitchenConfig.DEFAULT_STOCKS["Tapioca"]
	end
	if
		string.find(stationName, "Powder")
		or string.find(stationName, "Tea")
		or string.find(stationName, "Chocolate")
	then
		return KitchenConfig.DEFAULT_STOCKS["Powder"]
	end
	return KitchenConfig.DEFAULT_STOCKS["Default"]
end

return KitchenConfig

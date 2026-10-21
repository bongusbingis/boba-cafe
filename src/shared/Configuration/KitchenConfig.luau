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

-- Station skill moment (BIG-B7). After a pour station (recipes with SkillMoment = true)
-- an optional meter appears; a tap in the zone marks the drink for a flat tip at serve.
-- Skipping or missing is the normal result. Set false to turn the whole feature off.
KitchenConfig.SKILL_MOMENTS_ENABLED = true
KitchenConfig.POUR_METER = {
	PERIOD_SECONDS = 1.6, -- DEC-058 Opus-set, Jack to tune: one 0 -> 1 -> 0 sweep
	DURATION_SECONDS = 3.2, -- DEC-058 Opus-set, Jack to tune: two sweeps, then it closes
	ZONE_WIDTH = 0.24, -- Outer / Good zone width
	PERFECT_WIDTH = 0.10, -- Inner / Perfect sweet spot width
	ZONE_CENTER_MIN = 0.45, -- DEC-058 Opus-set, Jack to tune
	ZONE_CENTER_MAX = 0.8, -- DEC-058 Opus-set, Jack to tune
	LATENCY_ALLOWANCE_SECONDS = 0.3, -- DEC-058 Opus-set, Jack to tune: max ping credit
	TIP_PER_PERFECT = 1, -- DEC-058 Opus-set, Jack to tune: BB per perfect pour, paid at NPC serve
	MAX_PERFECT_PER_DRINK = 2, -- DEC-058 Opus-set, Jack to tune
	MIN_CUSTOMERS_SERVED = 1, -- DEC-058 Opus-set, Jack to tune: hidden until the first serve
}

return KitchenConfig

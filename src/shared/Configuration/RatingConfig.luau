--!strict
--[[
    RatingConfig: Cafe Rating and Rush Hour tuning (REVIVAL-001 M2-RATING, design 5.6, DEC-021).
    Deltas are divided by N = max(1, clocked-in baristas).
--]]

return {
	START = 50, -- PROPOSED (Jack)
	PERFECT = 4, -- PROPOSED (Jack)
	CLOSE = 1, -- PROPOSED (Jack)
	FAST = 1, -- PROPOSED (Jack): extra on a fast serve (DEC-021)
	WALKOUT = -2, -- PROPOSED (Jack): DEC-021 override of design -8
	SPILL_CLEANED = 3, -- PROPOSED (Jack)
	SPILL_DRAIN = -0.5, -- PROPOSED (Jack): per drain tick while any spill is present
	DRAIN_SECONDS = 5, -- TUNING
	SPILL_XP = 5, -- PROPOSED (Jack): XP to the player who cleans a spill
	RUSH_SECONDS = 120, -- DEC-024 (E8)
	RUSH_NPC_MULT = 1.5, -- PROPOSED (Jack)
	RUSH_CAP_BONUS = 4, -- PROPOSED (Jack)
	RUSH_PAY_MULT = 2, -- DEC-024 (E8)
	AFTER_RUSH = 60, -- PROPOSED (Jack)
	MIN_GAP_SECONDS = 360, -- TUNING
	BOBA_PARTY_SECONDS = 600, -- DEC-029 E18: 10-minute server-wide rush hour
	BOBA_PARTY_COOLDOWN = 600, -- DEC-029 E18: 10-minute cooldown after party ends
	BOBA_PARTY_EXTENSION_SECONDS = 600, -- DEC-029 E18: 10-minute extension per purchase during active party
	PARTY_SECONDS = 600, -- Alias for BOBA_PARTY_SECONDS
	PARTY_COOLDOWN = 600, -- Alias for BOBA_PARTY_COOLDOWN
	PARTY_EXTENSION_SECONDS = 600, -- Alias for BOBA_PARTY_EXTENSION_SECONDS
}

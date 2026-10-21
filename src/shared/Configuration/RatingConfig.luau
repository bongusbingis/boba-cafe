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
	RUSH_NPC_MULT = 5.0, -- PROPOSED (Jack)
	RUSH_CAP_BONUS = 34, -- PROPOSED (Jack): max 50 concurrent NPCs (16 SERVER_CAP + 34)
	RUSH_MIN_TARGET = 25, -- Rush floor ceiling: the floor is min(this, RUSH_MIN_PER_BARISTA x baristas)
	RUSH_MIN_PER_BARISTA = 8, -- DEC-058 agent-set, Jack to tune: rush floor per clocked-in barista (0 baristas = no rush crowd)
	RUSH_SPAWN_GAP_SECONDS = 0.2, -- Rapid spawning during rush hour instead of 3.0s
	RUSH_SPAWN_BURST = 3, -- Spawn up to 3 customers per pacing tick
	RUSH_QUEUE_CAP = 35, -- Allow line to hold up to 35 customers during rush hour (up from 6)
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

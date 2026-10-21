--!strict
--[[
    ShiftConfig: count-based shift tuning (REVIVAL-001 M2-SHIFT, DEC-011 Q11).
    Approved values: DEC-024 (E7, E13).
--]]

return {
	SHIFT_SIZE = 10,
	FIRST_SHIFT_SIZE = 5,
	CARD_SECONDS_FIRST = 8,
	CARD_SECONDS_LATER = 6,
	SHIFT_BONUS_PER_STAR = 5, -- DEC-024 (E7)
	SHIFT_XP = 10, -- DEC-024 (E13)
	SHIFT_XP_PER_STAR = 5, -- DEC-024 (E13)
	STREAK_LENGTH = 3, -- PROPOSED (H6-STREAK, Jack-approved 2026-10-21)
	STREAK_BONUS_BB = 30, -- PROPOSED (H6-STREAK): average-chest BB fallback (mean of TreasureHuntConfig MIN/MAX_BOBABUCKS 20/40)
}

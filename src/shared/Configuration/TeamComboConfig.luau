--!strict
--[[
    TeamComboConfig: server-wide Team Combo tuning (REVIVAL-001 M3-REM-C, DEC-028 E23, DEC-036 C1-C5).
    A chain of CHAIN_TARGET consecutive successful serves (NPC and real-player) pays everyone
    PAY_BONUS extra for DURATION_SECONDS. A customer walkout resets the chain.
--]]

return {
	CHAIN_TARGET = 10, -- DEC-028 E23
	PAY_BONUS = 0.10, -- DEC-028 E23: +10% pay
	DURATION_SECONDS = 60, -- DEC-028 E23
}

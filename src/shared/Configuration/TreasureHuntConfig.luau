--!strict
--[[
	TreasureHuntConfig.luau
	Hidden Treasure Chests tuning and reward roller (REVIVAL-001 M4-TREASURE-CHESTS).
]]

export type TreasureReward = {
	BobaBucks: number,
	Capsule: string?,
}

local TreasureHuntConfig = {
	MAX_ACTIVE_CHESTS = 5,
	RESPAWN_DELAY_SECONDS = 90,
	PLAYER_COOLDOWN_SECONDS = 15 * 60, -- DEC-035 Q2
	MIN_BOBABUCKS = 20, -- DEC-036
	MAX_BOBABUCKS = 40, -- DEC-036
	CAPSULE_CHANCE = 0.10, -- DEC-036
	PROMPT_HOLD_DURATION = 1.0,
	PROMPT_MAX_DISTANCE = 10,
	COOLDOWN_NOTICE_SECONDS = 5, -- UI throttle for the cooldown toast, not an economy value
	BADGE_ID = 2124774045,
}

local CAPSULE_OPTIONS = {
	"Regular Pet Capsule",
	"Nametag Capsule",
}

function TreasureHuntConfig.RollReward(randomSource: Random?): TreasureReward
	local rng = randomSource or Random.new()
	local bobaBucks = rng:NextInteger(TreasureHuntConfig.MIN_BOBABUCKS, TreasureHuntConfig.MAX_BOBABUCKS)
	local capsule: string? = nil
	if rng:NextNumber() <= TreasureHuntConfig.CAPSULE_CHANCE then
		capsule = CAPSULE_OPTIONS[rng:NextInteger(1, #CAPSULE_OPTIONS)]
	end
	return {
		BobaBucks = bobaBucks,
		Capsule = capsule,
	}
end

return TreasureHuntConfig

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
	MIN_BOBABUCKS = 35,
	MAX_BOBABUCKS = 100,
	CAPSULE_CHANCE = 0.15,
	PROMPT_HOLD_DURATION = 1.0,
	PROMPT_MAX_DISTANCE = 10,
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

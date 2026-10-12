--[[
    Module: DailyStreak
    Description: Pure streak arithmetic for daily login rewards.

    Kept free of Roblox APIs and of any state so the boundary conditions (claim
    interval, grace window, cycle wrap-around) can be tested directly.
--]]

local DailyStreak = {}

export type StreakState = {
	CanClaim: boolean,
	NextDay: number,
	StreakReset: boolean,
	SecondsRemaining: number,
}

export type StreakInput = {
	CurrentDay: number,
	LastClaimed: number,
}

export type StreakRules = {
	CycleLength: number,
	ClaimInterval: number,
	StreakGrace: number,
}

--- What the player is entitled to at time `now`.
function DailyStreak.evaluate(input: StreakInput, rules: StreakRules, now: number): StreakState
	local lastClaimed = input.LastClaimed or 0
	local currentDay = input.CurrentDay or 0
	local cycleLength = math.max(rules.CycleLength, 1)

	-- Never claimed before.
	if lastClaimed <= 0 then
		return {
			CanClaim = true,
			NextDay = 1,
			StreakReset = false,
			SecondsRemaining = 0,
		}
	end

	local elapsed = now - lastClaimed

	-- Claiming wraps around the end of the cycle.
	local nextDay = (currentDay % cycleLength) + 1

	if elapsed < rules.ClaimInterval then
		return {
			CanClaim = false,
			NextDay = nextDay,
			StreakReset = false,
			SecondsRemaining = rules.ClaimInterval - elapsed,
		}
	end

	-- Missed the grace window — start the cycle over.
	if elapsed >= rules.StreakGrace then
		return {
			CanClaim = true,
			NextDay = 1,
			StreakReset = true,
			SecondsRemaining = 0,
		}
	end

	return {
		CanClaim = true,
		NextDay = nextDay,
		StreakReset = false,
		SecondsRemaining = 0,
	}
end

return DailyStreak

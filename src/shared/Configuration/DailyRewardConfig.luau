--!strict

export type RewardEntry = {
	BobaBucks: number,
	Capsule: string?,
}

export type StreakStatus = {
	CanClaim: boolean,
	DayToClaim: number,
	SecondsUntilNextClaim: number,
	Expired: boolean,
}

local DailyRewardConfig = {}

DailyRewardConfig.CLAIM_COOLDOWN_SECONDS = 20 * 3600
DailyRewardConfig.STREAK_EXPIRE_SECONDS = 48 * 3600
DailyRewardConfig.VIP_GAMEPASS_ID = 12385781
DailyRewardConfig.VIP_MULTIPLIER = 2

DailyRewardConfig.REWARDS = {
	[1] = { BobaBucks = 30 }, -- DEC-036
	[2] = { BobaBucks = 45 }, -- DEC-036
	[3] = { BobaBucks = 60 }, -- DEC-036
	[4] = { BobaBucks = 60, Capsule = "Regular Pet Capsule" }, -- DEC-036
	[5] = { BobaBucks = 90 }, -- DEC-036
	[6] = { BobaBucks = 120 }, -- DEC-036
	[7] = { BobaBucks = 180, Capsule = "Rare Pet Capsule" }, -- DEC-036
} :: { [number]: RewardEntry }

function DailyRewardConfig.GetStreakStatus(streak: number, lastClaimTime: number, now: number): StreakStatus
	if lastClaimTime == 0 then
		return {
			CanClaim = true,
			DayToClaim = 1,
			SecondsUntilNextClaim = 0,
			Expired = false,
		}
	end

	local elapsed = now - lastClaimTime
	if elapsed < DailyRewardConfig.CLAIM_COOLDOWN_SECONDS then
		return {
			CanClaim = false,
			DayToClaim = (streak % 7) + 1,
			SecondsUntilNextClaim = DailyRewardConfig.CLAIM_COOLDOWN_SECONDS - elapsed,
			Expired = false,
		}
	elseif elapsed > DailyRewardConfig.STREAK_EXPIRE_SECONDS then
		return {
			CanClaim = true,
			DayToClaim = 1,
			SecondsUntilNextClaim = 0,
			Expired = true,
		}
	else
		return {
			CanClaim = true,
			DayToClaim = (streak % 7) + 1,
			SecondsUntilNextClaim = 0,
			Expired = false,
		}
	end
end

return DailyRewardConfig

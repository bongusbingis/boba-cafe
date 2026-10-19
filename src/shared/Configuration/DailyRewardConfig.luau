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
	[1] = { BobaBucks = 50 },
	[2] = { BobaBucks = 75 },
	[3] = { BobaBucks = 100 },
	[4] = { BobaBucks = 125, Capsule = "Regular Pet Capsule" },
	[5] = { BobaBucks = 150 },
	[6] = { BobaBucks = 200 },
	[7] = { BobaBucks = 300, Capsule = "Rare Pet Capsule" },
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

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local DailyRewardConfig = require(Shared.Configuration.DailyRewardConfig)
local GamepassUtil = require(Shared.Utility.GamepassUtil)

local DATA_TIMEOUT_SECONDS = 10
local claimsInProgress: { [number]: boolean } = {}

local DailyRewardService = Knit.CreateService({
	Name = "DailyRewardService",
	Client = {
		GetRewardStatus = function(self, player: Player)
			return self.Server:GetRewardStatus(player)
		end,
		ClaimReward = function(self, player: Player)
			local server = self.Server
			local now = server:_now()
			local last = server._lastClaimAttempts[player.UserId] or 0
			if now - last < 2 then
				return false, "RateLimited", nil
			end
			server._lastClaimAttempts[player.UserId] = now
			return server:ClaimReward(player)
		end,
	},
})

DailyRewardService._lastClaimAttempts = {} :: { [number]: number }

--- Resolves another Knit service. Indirection exists so specs can substitute fakes without starting Knit.
function DailyRewardService:_getService(name: string)
	return Knit.GetService(name)
end

--- Resolves current time. Indirection exists so specs can simulate time progression.
function DailyRewardService:_now(): number
	return os.time()
end

--- Resolves gamepass ownership. Indirection exists so specs can mock VIP pass ownership.
function DailyRewardService:_hasPass(player: Player, passId: number): boolean
	local ok, owns = pcall(function()
		return (GamepassUtil :: any):PlayerOwnsPassAsync(player, passId)
	end)
	return ok and owns == true
end

function DailyRewardService:PlayerRemoving(player: Player)
	claimsInProgress[player.UserId] = nil
	self._lastClaimAttempts[player.UserId] = nil
end

function DailyRewardService:GetRewardStatus(player: Player): { [string]: any }
	local ok, playerData = self:_getService("DataService"):GetDataAsync(player):timeout(DATA_TIMEOUT_SECONDS):await()
	if not ok or not playerData then
		return {
			CanClaim = false,
			DayToClaim = 1,
			SecondsUntilNextClaim = 0,
			Expired = false,
			CurrentStreak = 0,
			LastClaimTime = 0,
			IsVIP = false,
			Reward = DailyRewardConfig.REWARDS[1],
			DataLoaded = false,
		}
	end

	local dailyRewards = playerData.DailyRewards
	local streak = 0
	local lastClaimTime = 0
	if typeof(dailyRewards) == "table" then
		streak = typeof(dailyRewards.Streak) == "number" and dailyRewards.Streak or 0
		lastClaimTime = typeof(dailyRewards.LastClaimTime) == "number" and dailyRewards.LastClaimTime or 0
	end

	local now = self:_now()
	local streakStatus = DailyRewardConfig.GetStreakStatus(streak, lastClaimTime, now)
	local isVip = self:_hasPass(player, DailyRewardConfig.VIP_GAMEPASS_ID)

	return {
		CanClaim = streakStatus.CanClaim,
		DayToClaim = streakStatus.DayToClaim,
		SecondsUntilNextClaim = streakStatus.SecondsUntilNextClaim,
		Expired = streakStatus.Expired,
		CurrentStreak = streak,
		LastClaimTime = lastClaimTime,
		IsVIP = isVip,
		Reward = DailyRewardConfig.REWARDS[streakStatus.DayToClaim],
		DataLoaded = true,
	}
end

function DailyRewardService:ClaimReward(player: Player): (boolean, string?, { [string]: any }?)
	if claimsInProgress[player.UserId] then
		return false, "ClaimInProgress", nil
	end
	claimsInProgress[player.UserId] = true

	local success, ret1, ret2, ret3 = pcall(function()
		if typeof(player.Parent) == "Instance" and player.Parent ~= Players then
			return false, "PlayerLeaving", nil
		end

		local ok, playerData =
			self:_getService("DataService"):GetDataAsync(player):timeout(DATA_TIMEOUT_SECONDS):await()
		if not ok or not playerData then
			return false, "DataNotLoaded", nil
		end

		local dailyRewards = playerData.DailyRewards
		local streak = 0
		local lastClaimTime = 0
		if typeof(dailyRewards) == "table" then
			streak = typeof(dailyRewards.Streak) == "number" and dailyRewards.Streak or 0
			lastClaimTime = typeof(dailyRewards.LastClaimTime) == "number" and dailyRewards.LastClaimTime or 0
		end

		local now = self:_now()
		local status = DailyRewardConfig.GetStreakStatus(streak, lastClaimTime, now)
		if not status.CanClaim then
			return false, "CooldownActive", {
				SecondsUntilNextClaim = status.SecondsUntilNextClaim,
			}
		end

		local nextStreak = if status.Expired then 1 else status.DayToClaim
		local reward = DailyRewardConfig.REWARDS[nextStreak]
		if not reward then
			return false, "InvalidRewardDay", nil
		end

		-- Capsule days: grant the capsule first. A full inventory (or failure) changes nothing,
		-- so the streak is not consumed and the player can claim again once there is space.
		if reward.Capsule then
			local capsuleService = self:_getService("CapsuleService")
			if not capsuleService:HasCapsuleSpace(player) then
				return false, "InventoryFull", nil
			end
			local granted, reason = capsuleService:GrantEarnedCapsule(player, reward.Capsule)
			if not granted then
				return false, reason or "InternalError", nil
			end
		end

		if playerData.DailyRewards == nil then
			playerData:SetValue({ "DailyRewards" }, { Streak = 0, LastClaimTime = 0 })
		end
		playerData:SetValue({ "DailyRewards", "Streak" }, nextStreak)
		playerData:SetValue({ "DailyRewards", "LastClaimTime" }, now)

		local isVip = self:_hasPass(player, DailyRewardConfig.VIP_GAMEPASS_ID)
		local multiplier = if isVip then DailyRewardConfig.VIP_MULTIPLIER else 1
		local grantAmount = reward.BobaBucks * multiplier

		local currencyService = self:_getService("CurrencyService")
		if currencyService and typeof(currencyService.Modify) == "function" then
			currencyService:Modify(player, "BobaBucks", grantAmount, "DailyReward")
		end

		return true, nil, {
			Streak = nextStreak,
			BobaBucks = grantAmount,
			Capsule = reward.Capsule,
		}
	end)

	claimsInProgress[player.UserId] = nil

	if not success then
		warn(`[DailyRewardService] ClaimReward error for {player.Name}: {ret1}`)
		return false, "InternalError", nil
	end

	return ret1, ret2, ret3
end

return DailyRewardService

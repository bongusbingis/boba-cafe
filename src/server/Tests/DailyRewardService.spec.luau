-- selene: allow(undefined_variable)
--[[
	DailyRewardService.spec.luau
	TestEZ tests for DailyRewardService and DailyRewardConfig.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Promise = require(ReplicatedStorage.Packages.Promise)
	local DailyRewardConfig = require(ReplicatedStorage.Shared.Configuration.DailyRewardConfig)
	local service = require(ServerScriptService.Server.Modules.DailyRewardService)

	-- ──────────────────────────────────────────────────────────────────────
	-- Fakes & helpers
	-- ──────────────────────────────────────────────────────────────────────

	local function makePlayer(userId: number)
		return { UserId = userId, Name = "Player_" .. userId }
	end

	local function makePlayerData(initialStreak: number?, initialLastClaimTime: number?)
		local data = {
			DailyRewards = {
				Streak = initialStreak or 0,
				LastClaimTime = initialLastClaimTime or 0,
			},
			SetValueCalls = 0,
		}
		function data:SetValue(path: { string }, value: any)
			local pointer = self
			for i = 1, #path - 1 do
				pointer = pointer[path[i]]
			end
			pointer[path[#path]] = value
			self.SetValueCalls += 1
		end
		return data
	end

	local currentTime: number
	local isVip: boolean
	local fakeData: any
	local currencyCalls: { { player: any, type: string, amount: number, reason: string? } }
	local inventoryCalls: { { player: any, category: string, itemName: string } }

	local originalGetService = service._getService
	local originalNow = service._now
	local originalHasPass = service._hasPass
	local originalGetInventoryServer = service._getInventoryServer

	beforeEach(function()
		currentTime = 1000000
		isVip = false
		fakeData = makePlayerData(0, 0)
		currencyCalls = {}
		inventoryCalls = {}

		local dataService = {
			GetDataAsync = function(_, _player)
				return Promise.resolve(fakeData)
			end,
		}

		local currencyService = {
			Modify = function(_, player, currencyType, amount, reason)
				table.insert(currencyCalls, {
					player = player,
					type = currencyType,
					amount = amount,
					reason = reason,
				})
			end,
		}

		local fakeInventoryServer = {
			AddItem = function(_, player, category, itemName)
				table.insert(inventoryCalls, {
					player = player,
					category = category,
					itemName = itemName,
				})
			end,
		}

		service._getService = function(_, name)
			if name == "DataService" then
				return dataService
			elseif name == "CurrencyService" then
				return currencyService
			end
			error("unexpected service: " .. tostring(name))
		end

		service._now = function(_)
			return currentTime
		end

		service._hasPass = function(_, _player, passId)
			if passId == DailyRewardConfig.VIP_GAMEPASS_ID then
				return isVip
			end
			return false
		end

		service._getInventoryServer = function(_)
			return fakeInventoryServer
		end
	end)

	afterEach(function()
		service._getService = originalGetService
		service._now = originalNow
		service._hasPass = originalHasPass
		service._getInventoryServer = originalGetInventoryServer
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- Pure logic: DailyRewardConfig.GetStreakStatus
	-- ══════════════════════════════════════════════════════════════════════

	describe("DailyRewardConfig.GetStreakStatus", function()
		it("returns Day 1 available when lastClaimTime is 0", function()
			local status = DailyRewardConfig.GetStreakStatus(0, 0, 1000)
			expect(status.CanClaim).to.equal(true)
			expect(status.DayToClaim).to.equal(1)
			expect(status.SecondsUntilNextClaim).to.equal(0)
			expect(status.Expired).to.equal(false)
		end)

		it("enforces 20-hour cooldown", function()
			local claimTime = 1000000
			local elapsed = 10 * 3600
			local status = DailyRewardConfig.GetStreakStatus(1, claimTime, claimTime + elapsed)
			expect(status.CanClaim).to.equal(false)
			expect(status.DayToClaim).to.equal(2)
			expect(status.SecondsUntilNextClaim).to.equal(10 * 3600)
			expect(status.Expired).to.equal(false)
		end)

		it("allows claiming after exactly 20 hours", function()
			local claimTime = 1000000
			local elapsed = 20 * 3600
			local status = DailyRewardConfig.GetStreakStatus(1, claimTime, claimTime + elapsed)
			expect(status.CanClaim).to.equal(true)
			expect(status.DayToClaim).to.equal(2)
			expect(status.SecondsUntilNextClaim).to.equal(0)
			expect(status.Expired).to.equal(false)
		end)

		it("allows claiming within the 48-hour window", function()
			local claimTime = 1000000
			local elapsed = 40 * 3600
			local status = DailyRewardConfig.GetStreakStatus(3, claimTime, claimTime + elapsed)
			expect(status.CanClaim).to.equal(true)
			expect(status.DayToClaim).to.equal(4)
			expect(status.SecondsUntilNextClaim).to.equal(0)
			expect(status.Expired).to.equal(false)
		end)

		it("flags expiration and resets DayToClaim to 1 after 48 hours", function()
			local claimTime = 1000000
			local elapsed = 50 * 3600
			local status = DailyRewardConfig.GetStreakStatus(4, claimTime, claimTime + elapsed)
			expect(status.CanClaim).to.equal(true)
			expect(status.DayToClaim).to.equal(1)
			expect(status.SecondsUntilNextClaim).to.equal(0)
			expect(status.Expired).to.equal(true)
		end)

		it("wraps Day 7 back to Day 1", function()
			local claimTime = 1000000
			local elapsed = 22 * 3600
			local status = DailyRewardConfig.GetStreakStatus(7, claimTime, claimTime + elapsed)
			expect(status.CanClaim).to.equal(true)
			expect(status.DayToClaim).to.equal(1)
			expect(status.SecondsUntilNextClaim).to.equal(0)
			expect(status.Expired).to.equal(false)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- DailyRewardService
	-- ══════════════════════════════════════════════════════════════════════

	describe("DailyRewardService", function()
		it("allows a new player to claim the Day 1 reward", function()
			local player = makePlayer(1)
			local status = service:GetRewardStatus(player)
			expect(status.CanClaim).to.equal(true)
			expect(status.DayToClaim).to.equal(1)
			expect(status.CurrentStreak).to.equal(0)

			local ok, err, result = service:ClaimReward(player)
			expect(ok).to.equal(true)
			expect(err).to.equal(nil)
			expect(result.Streak).to.equal(1)
			expect(result.BobaBucks).to.equal(50)
			expect(result.Capsule).to.equal(nil)

			expect(fakeData.DailyRewards.Streak).to.equal(1)
			expect(fakeData.DailyRewards.LastClaimTime).to.equal(currentTime)
			expect(#currencyCalls).to.equal(1)
			expect(currencyCalls[1].type).to.equal("BobaBucks")
			expect(currencyCalls[1].amount).to.equal(50)
			expect(currencyCalls[1].reason).to.equal("DailyReward")
			expect(#inventoryCalls).to.equal(0)
		end)

		it("enforces cooldown: claim attempted before 20 hours is rejected with remaining time", function()
			local player = makePlayer(1)
			local ok1 = service:ClaimReward(player)
			expect(ok1).to.equal(true)

			-- Advance time by 8 hours (12 hours remaining on 20-hour cooldown)
			currentTime += 8 * 3600

			local status = service:GetRewardStatus(player)
			expect(status.CanClaim).to.equal(false)
			expect(status.DayToClaim).to.equal(2)
			expect(status.SecondsUntilNextClaim).to.equal(12 * 3600)

			local ok2, err2, info = service:ClaimReward(player)
			expect(ok2).to.equal(false)
			expect(err2).to.equal("CooldownActive")
			expect(info.SecondsUntilNextClaim).to.equal(12 * 3600)
			expect(fakeData.DailyRewards.Streak).to.equal(1)
			expect(#currencyCalls).to.equal(1)
		end)

		it("advances streak to 2 when claimed 22 hours later", function()
			local player = makePlayer(1)
			service:ClaimReward(player)

			-- Advance time by 22 hours
			currentTime += 22 * 3600

			local status = service:GetRewardStatus(player)
			expect(status.CanClaim).to.equal(true)
			expect(status.DayToClaim).to.equal(2)

			local ok, err, result = service:ClaimReward(player)
			expect(ok).to.equal(true)
			expect(err).to.equal(nil)
			expect(result.Streak).to.equal(2)
			expect(result.BobaBucks).to.equal(75)
			expect(result.Capsule).to.equal(nil)
			expect(fakeData.DailyRewards.Streak).to.equal(2)
			expect(fakeData.DailyRewards.LastClaimTime).to.equal(currentTime)
			expect(#currencyCalls).to.equal(2)
			expect(currencyCalls[2].amount).to.equal(75)
		end)

		it("resets streak to 1 after 50 hours of inactivity (expiration)", function()
			local player = makePlayer(1)
			fakeData = makePlayerData(4, currentTime)

			-- Advance time by 50 hours (> 48h expiration window)
			currentTime += 50 * 3600

			local status = service:GetRewardStatus(player)
			expect(status.CanClaim).to.equal(true)
			expect(status.DayToClaim).to.equal(1)
			expect(status.Expired).to.equal(true)

			local ok, err, result = service:ClaimReward(player)
			expect(ok).to.equal(true)
			expect(err).to.equal(nil)
			expect(result.Streak).to.equal(1)
			expect(result.BobaBucks).to.equal(50)
			expect(result.Capsule).to.equal(nil)
			expect(fakeData.DailyRewards.Streak).to.equal(1)
			expect(fakeData.DailyRewards.LastClaimTime).to.equal(currentTime)
			expect(#currencyCalls).to.equal(1)
			expect(currencyCalls[1].amount).to.equal(50)
		end)

		it("grants Day 7 reward with Rare Pet Capsule and wraps streak to Day 1", function()
			local player = makePlayer(1)
			fakeData = makePlayerData(6, currentTime)

			-- 22 hours later: claim Day 7
			currentTime += 22 * 3600

			local status7 = service:GetRewardStatus(player)
			expect(status7.DayToClaim).to.equal(7)

			local ok7, _, result7 = service:ClaimReward(player)
			expect(ok7).to.equal(true)
			expect(result7.Streak).to.equal(7)
			expect(result7.BobaBucks).to.equal(300)
			expect(result7.Capsule).to.equal("Rare Pet Capsule")
			expect(fakeData.DailyRewards.Streak).to.equal(7)
			expect(#inventoryCalls).to.equal(1)
			expect(inventoryCalls[1].category).to.equal("Capsules")
			expect(inventoryCalls[1].itemName).to.equal("Rare Pet Capsule")

			-- 22 hours later: claim next cycle Day 1
			currentTime += 22 * 3600

			local statusWrap = service:GetRewardStatus(player)
			expect(statusWrap.CanClaim).to.equal(true)
			expect(statusWrap.DayToClaim).to.equal(1)

			local okWrap, _, resultWrap = service:ClaimReward(player)
			expect(okWrap).to.equal(true)
			expect(resultWrap.Streak).to.equal(1)
			expect(resultWrap.BobaBucks).to.equal(50)
			expect(resultWrap.Capsule).to.equal(nil)
			expect(fakeData.DailyRewards.Streak).to.equal(1)
		end)

		it("grants Regular Pet Capsule on Day 4", function()
			local player = makePlayer(1)
			fakeData = makePlayerData(3, currentTime)

			currentTime += 22 * 3600

			local ok, _, result = service:ClaimReward(player)
			expect(ok).to.equal(true)
			expect(result.Streak).to.equal(4)
			expect(result.BobaBucks).to.equal(125)
			expect(result.Capsule).to.equal("Regular Pet Capsule")
			expect(fakeData.DailyRewards.Streak).to.equal(4)
			expect(#inventoryCalls).to.equal(1)
			expect(inventoryCalls[1].category).to.equal("Capsules")
			expect(inventoryCalls[1].itemName).to.equal("Regular Pet Capsule")
		end)

		it("applies 2x multiplier to BobaBucks payout for VIP gamepass owners", function()
			local player = makePlayer(1)
			isVip = true

			local status = service:GetRewardStatus(player)
			expect(status.IsVIP).to.equal(true)

			local ok, _, result = service:ClaimReward(player)
			expect(ok).to.equal(true)
			expect(result.Streak).to.equal(1)
			expect(result.BobaBucks).to.equal(100)
			expect(#currencyCalls).to.equal(1)
			expect(currencyCalls[1].amount).to.equal(100)
		end)

		it("exposes Client table functions that forward to Server", function()
			local player = makePlayer(1)
			local status = service.Client:GetRewardStatus(player)
			expect(status.CanClaim).to.equal(true)
			expect(status.DayToClaim).to.equal(1)

			local ok, err, result = service.Client:ClaimReward(player)
			expect(ok).to.equal(true)
			expect(err).to.equal(nil)
			expect(result.Streak).to.equal(1)
			expect(result.BobaBucks).to.equal(50)
		end)
	end)
end

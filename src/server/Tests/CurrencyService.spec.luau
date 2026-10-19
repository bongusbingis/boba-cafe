-- selene: allow(undefined_variable)
--[[
	CurrencyService.spec.luau
	TestEZ tests for CurrencyService:TrySpendAsync.

	Testing strategy
	────────────────
	CurrencyService is required without starting Knit. Its `_getService` hook is
	replaced with a lookup into a table of fakes, so no DataService, profile, or
	authored place content is needed. Player data is a plain table that records
	SetValue calls the same way the Replica-backed proxy applies them.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Promise = require(ReplicatedStorage.Packages.Promise)
	local service = require(ServerScriptService.Server.Modules.CurrencyService)

	-- ──────────────────────────────────────────────────────────────────────
	-- Fakes
	-- ──────────────────────────────────────────────────────────────────────

	local function makePlayer(userId: number)
		return { UserId = userId, Name = "Player_" .. userId }
	end

	-- Mirrors Replica:SetValue for the path shape CurrencyService uses.
	local function makePlayerData(bobaBucks: number, points: number)
		local data = {
			Currency = { BobaBucks = bobaBucks, Points = points },
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

	local fakeData
	local statCalls
	local leaderboardCalls
	local originalGetService = service._getService

	beforeEach(function()
		fakeData = makePlayerData(100, 10)
		statCalls = {}
		leaderboardCalls = {}

		local dataService = {
			GetDataAsync = function(_, _player)
				return Promise.resolve(fakeData)
			end,
		}
		local statisticsService = {
			IncrementStat = function(_, player, statName, amount)
				table.insert(statCalls, { player = player, statName = statName, amount = amount })
			end,
		}

		local leaderboardService = {
			IncrementStat = function(_, player, board, amount)
				table.insert(leaderboardCalls, { player = player, board = board, amount = amount })
			end,
		}
		local analyticsEvents = {
			Economy = function() end,
			Funnel = function() end,
		}

		service._getService = function(_, name)
			if name == "DataService" then
				return dataService
			elseif name == "LeaderboardService" then
				return leaderboardService
			elseif name == "AnalyticsEvents" then
				return analyticsEvents
			elseif name == "StatisticsService" then
				return statisticsService
			end
			error("unexpected service requested: " .. tostring(name))
		end
	end)

	afterEach(function()
		service._getService = originalGetService
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- Modify leaderboard feed (DEC-038 Q14)
	-- ══════════════════════════════════════════════════════════════════════

	describe("Modify leaderboard feed", function()
		-- Modify applies through a resolved Promise's andThen; yield once before asserting.
		local function modifyAndSettle(currency: string, amount: number, reason: string?)
			service:Modify(makePlayer(1), currency, amount, reason)
			task.wait()
		end

		for _, reason in { "PromoCode", "ItemSell", "QuestRerollRefund" } do
			it("does not feed MostBobaBucks for reason " .. reason, function()
				modifyAndSettle("BobaBucks", 50, reason)
				expect(fakeData.Currency.BobaBucks).to.equal(150)
				expect(#leaderboardCalls).to.equal(0)
			end)
		end

		for _, reason in { "Gameplay", "TreasureChest", "DailyReward" } do
			it("feeds MostBobaBucks for reason " .. reason, function()
				modifyAndSettle("BobaBucks", 50, reason)
				expect(#leaderboardCalls).to.equal(1)
				expect(leaderboardCalls[1].board).to.equal("MostBobaBucks")
				expect(leaderboardCalls[1].amount).to.equal(50)
			end)
		end

		it("feeds MostBobaBucks when no reason is given", function()
			modifyAndSettle("BobaBucks", 25, nil)
			expect(#leaderboardCalls).to.equal(1)
			expect(leaderboardCalls[1].amount).to.equal(25)
		end)

		it("never feeds for Points", function()
			modifyAndSettle("Points", 5, "Gameplay")
			expect(#leaderboardCalls).to.equal(0)
		end)

		it("never feeds for negative amounts", function()
			modifyAndSettle("BobaBucks", -30, "Gameplay")
			expect(fakeData.Currency.BobaBucks).to.equal(70)
			expect(#leaderboardCalls).to.equal(0)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- TrySpendAsync
	-- ══════════════════════════════════════════════════════════════════════

	describe("TrySpendAsync", function()
		describe("sufficient balance", function()
			it("should return true and deduct the amount", function()
				local ok = service:TrySpendAsync(makePlayer(1), "BobaBucks", 40)
				expect(ok).to.equal(true)
				expect(fakeData.Currency.BobaBucks).to.equal(60)
			end)

			it("should allow spending the exact balance down to zero", function()
				local ok = service:TrySpendAsync(makePlayer(1), "BobaBucks", 100)
				expect(ok).to.equal(true)
				expect(fakeData.Currency.BobaBucks).to.equal(0)
			end)

			it("should only touch the requested currency", function()
				service:TrySpendAsync(makePlayer(1), "Points", 4)
				expect(fakeData.Currency.Points).to.equal(6)
				expect(fakeData.Currency.BobaBucks).to.equal(100)
			end)

			it("should record BobaBucksSpent for BobaBucks spends", function()
				local player = makePlayer(1)
				service:TrySpendAsync(player, "BobaBucks", 25)
				expect(#statCalls).to.equal(1)
				expect(statCalls[1].statName).to.equal("BobaBucksSpent")
				expect(statCalls[1].amount).to.equal(25)
				expect(statCalls[1].player).to.equal(player)
			end)

			it("should not record BobaBucksSpent for Points spends", function()
				service:TrySpendAsync(makePlayer(1), "Points", 5)
				expect(#statCalls).to.equal(0)
			end)

			it("should never let sequential spends overdraw", function()
				local player = makePlayer(1)
				local first = service:TrySpendAsync(player, "BobaBucks", 70)
				local second = service:TrySpendAsync(player, "BobaBucks", 70)
				expect(first).to.equal(true)
				expect(second).to.equal(false)
				expect(fakeData.Currency.BobaBucks).to.equal(30)
			end)
		end)

		describe("insufficient balance", function()
			it("should return false with InsufficientFunds", function()
				local ok, reason = service:TrySpendAsync(makePlayer(1), "BobaBucks", 101)
				expect(ok).to.equal(false)
				expect(reason).to.equal("InsufficientFunds")
			end)

			it("should leave the balance untouched", function()
				service:TrySpendAsync(makePlayer(1), "BobaBucks", 101)
				expect(fakeData.Currency.BobaBucks).to.equal(100)
				expect(fakeData.SetValueCalls).to.equal(0)
			end)

			it("should not record a spent stat", function()
				service:TrySpendAsync(makePlayer(1), "BobaBucks", 101)
				expect(#statCalls).to.equal(0)
			end)
		end)

		describe("invalid currency type", function()
			it("should refuse an unknown currency name", function()
				local ok, reason = service:TrySpendAsync(makePlayer(1), "Gems" :: any, 1)
				expect(ok).to.equal(false)
				expect(reason).to.equal("InvalidCurrency")
				expect(fakeData.SetValueCalls).to.equal(0)
			end)

			it("should refuse a non-string currency type", function()
				local ok, reason = service:TrySpendAsync(makePlayer(1), 5 :: any, 1)
				expect(ok).to.equal(false)
				expect(reason).to.equal("InvalidCurrency")
			end)

			it("should refuse nil", function()
				local ok = service:TrySpendAsync(makePlayer(1), nil :: any, 1)
				expect(ok).to.equal(false)
			end)
		end)

		describe("invalid amount", function()
			it("should refuse zero", function()
				local ok, reason = service:TrySpendAsync(makePlayer(1), "BobaBucks", 0)
				expect(ok).to.equal(false)
				expect(reason).to.equal("InvalidAmount")
			end)

			it("should refuse negative amounts (cannot be used to add money)", function()
				local ok, reason = service:TrySpendAsync(makePlayer(1), "BobaBucks", -50)
				expect(ok).to.equal(false)
				expect(reason).to.equal("InvalidAmount")
				expect(fakeData.Currency.BobaBucks).to.equal(100)
			end)

			it("should refuse NaN", function()
				local ok = service:TrySpendAsync(makePlayer(1), "BobaBucks", 0 / 0)
				expect(ok).to.equal(false)
				expect(fakeData.Currency.BobaBucks).to.equal(100)
			end)

			it("should refuse infinity", function()
				local ok = service:TrySpendAsync(makePlayer(1), "BobaBucks", math.huge)
				expect(ok).to.equal(false)
				expect(fakeData.Currency.BobaBucks).to.equal(100)
			end)

			it("should refuse fractional amounts", function()
				local ok = service:TrySpendAsync(makePlayer(1), "BobaBucks", 1.5)
				expect(ok).to.equal(false)
				expect(fakeData.Currency.BobaBucks).to.equal(100)
			end)

			it("should refuse non-number amounts", function()
				local ok = service:TrySpendAsync(makePlayer(1), "BobaBucks", "10" :: any)
				expect(ok).to.equal(false)
				expect(fakeData.Currency.BobaBucks).to.equal(100)
			end)

			it("should not touch data for any rejected amount", function()
				service:TrySpendAsync(makePlayer(1), "BobaBucks", 0)
				service:TrySpendAsync(makePlayer(1), "BobaBucks", -1)
				expect(fakeData.SetValueCalls).to.equal(0)
				expect(#statCalls).to.equal(0)
			end)
		end)

		describe("data unavailable", function()
			it("should return false with NoData when the data promise rejects", function()
				service._getService = function()
					return {
						GetDataAsync = function()
							return Promise.reject("no profile")
						end,
					}
				end
				local ok, reason = service:TrySpendAsync(makePlayer(1), "BobaBucks", 1)
				expect(ok).to.equal(false)
				expect(reason).to.equal("NoData")
			end)
		end)
	end)
end

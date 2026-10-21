-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	LeaderboardService.spec.luau
	Unit tests covering month key generation, rollover formatting, score ranking,
	and board/statue refresh logic (REVIVAL-001 M4-LEADERBOARDS, DEC-032).
]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local LeaderboardConfig = require(ReplicatedStorage.Shared.Configuration.LeaderboardConfig)
	local LeaderboardService = require(ServerScriptService.Server.Modules.LeaderboardService) :: any

	describe("LeaderboardConfig", function()
		it("defines all 5 approved monthly boards", function()
			local boards = LeaderboardConfig.BOARDS
			expect(boards.MostTips).to.be.ok()
			expect(boards.MostBobaBucks).to.be.ok()
			expect(boards.OrdersServed).to.be.ok()
			expect(boards.MostActive).to.be.ok()
			expect(boards.TopDonators).to.be.ok()

			expect(boards.OrdersServed.BoardName).to.equal("Most Orders Served")
			expect(boards.OrdersServed.ModelName).to.equal("Most Staff Points")
			expect(boards.OrdersServed.Metric).to.equal("Orders")
		end)

		it("hides Most Tips and Top Donators only (DEC-035 Q4)", function()
			local boards = LeaderboardConfig.BOARDS
			expect(boards.MostTips.Hidden).to.equal(true)
			expect(boards.TopDonators.Hidden).to.equal(true)
			expect(boards.OrdersServed.Hidden).to.never.be.ok()
			expect(boards.MostBobaBucks.Hidden).to.never.be.ok()
			expect(boards.MostActive.Hidden).to.never.be.ok()
		end)

		it("has correct refresh interval and top limit", function()
			expect(LeaderboardConfig.REFRESH_INTERVAL_SECONDS).to.equal(120)
			expect(LeaderboardConfig.TOP_LIMIT).to.equal(10)
		end)

		it("generates correct monthly keys with YYYY_MM_ prefix", function()
			local octTimestamp = os.time({ year = 2026, month = 10, day = 18, hour = 12 })
			local octKey = LeaderboardConfig.GetMonthKey("OrdersServed", octTimestamp)
			expect(octKey).to.equal("2026_10_OrdersServed")

			local tipsKey = LeaderboardConfig.GetMonthKey("MostTips", octTimestamp)
			expect(tipsKey).to.equal("2026_10_MostTips")
		end)

		it("handles month rollover formatting correctly", function()
			local novTimestamp = os.time({ year = 2026, month = 11, day = 1, hour = 0 })
			local expectedNov = os.date("%Y_%m_", novTimestamp) .. "OrdersServed"
			expect(LeaderboardConfig.GetMonthKey("OrdersServed", novTimestamp)).to.equal(expectedNov)

			local janTimestamp = os.time({ year = 2027, month = 1, day = 15, hour = 0 })
			local expectedJan = os.date("%Y_%m_", janTimestamp) .. "OrdersServed"
			expect(LeaderboardConfig.GetMonthKey("OrdersServed", janTimestamp)).to.equal(expectedJan)
		end)

		it("defaults to current timestamp if omitted", function()
			local defaultKey = LeaderboardConfig.GetMonthKey("MostActive")
			expect(string.match(defaultKey, "^%d%d%d%d_%d%d_MostActive$") ~= nil).to.equal(true)
		end)
	end)

	describe("LeaderboardService Score Ranking & Top Entries", function()
		local mockStores: { [string]: any }
		local mockPlayersService: any

		local function createMockStore()
			local storeData: { [string]: number } = {}
			return {
				_data = storeData,
				UpdateAsync = function(_self, key: string, transform: (number?) -> number)
					local current = storeData[key]
					local new = transform(current)
					storeData[key] = new
					return new
				end,
				GetSortedAsync = function(_self, isAscending: boolean, pageSize: number)
					local items = {}
					for k, v in storeData do
						table.insert(items, { key = k, value = v })
					end
					table.sort(items, function(a, b)
						if isAscending then
							return a.value < b.value
						else
							return a.value > b.value
						end
					end)
					local page = {}
					for i = 1, math.min(pageSize, #items) do
						table.insert(page, items[i])
					end
					return {
						GetCurrentPage = function()
							return page
						end,
					}
				end,
			}
		end

		beforeEach(function()
			mockStores = {}
			LeaderboardService._pending = {}
			LeaderboardService._flushFailures = {}
			LeaderboardService._closing = false
			LeaderboardService._mockOrderedDataStore = function(name: string)
				if not mockStores[name] then
					mockStores[name] = createMockStore()
				end
				return mockStores[name]
			end

			mockPlayersService = {
				_names = {
					[101] = "BaristaAlice",
					[102] = "BaristaBob",
					[103] = "BaristaCharlie",
				},
				GetPlayerByUserId = function(_self, _uid: number)
					return nil
				end,
				GetNameFromUserIdAsync = function(self, uid: number)
					return self._names[uid] or `User_{uid}`
				end,
			}
			LeaderboardService._mockPlayers = mockPlayersService
			LeaderboardService._nameCache = {}
		end)

		afterEach(function()
			LeaderboardService._pending = {}
			LeaderboardService._flushFailures = {}
			LeaderboardService._closing = false
			LeaderboardService._mockOrderedDataStore = nil
			LeaderboardService._mockPlayers = nil
			LeaderboardService._nameCache = {}
		end)

		it("accumulates player score via _updatePlayerStat", function()
			local ok1 = LeaderboardService:_updatePlayerStat(101, "OrdersServed", 5)
			expect(ok1).to.equal(true)

			local ok2 = LeaderboardService:_updatePlayerStat(101, "OrdersServed", 3)
			expect(ok2).to.equal(true)

			local top = LeaderboardService:GetTopEntries("OrdersServed", 10)
			expect(#top).to.equal(1)
			expect(top[1].UserId).to.equal(101)
			expect(top[1].Name).to.equal("BaristaAlice")
			expect(top[1].Value).to.equal(8)
		end)

		it("ranks multiple players in descending order", function()
			LeaderboardService:_updatePlayerStat(101, "MostTips", 50)
			LeaderboardService:_updatePlayerStat(102, "MostTips", 150)
			LeaderboardService:_updatePlayerStat(103, "MostTips", 100)

			local top = LeaderboardService:GetTopEntries("MostTips", 10)
			expect(#top).to.equal(3)
			expect(top[1].UserId).to.equal(102)
			expect(top[1].Name).to.equal("BaristaBob")
			expect(top[1].Value).to.equal(150)

			expect(top[2].UserId).to.equal(103)
			expect(top[2].Name).to.equal("BaristaCharlie")
			expect(top[2].Value).to.equal(100)

			expect(top[3].UserId).to.equal(101)
			expect(top[3].Name).to.equal("BaristaAlice")
			expect(top[3].Value).to.equal(50)
		end)

		it("respects limit parameter", function()
			LeaderboardService:_updatePlayerStat(101, "MostActive", 10)
			LeaderboardService:_updatePlayerStat(102, "MostActive", 20)
			LeaderboardService:_updatePlayerStat(103, "MostActive", 30)

			local top1 = LeaderboardService:GetTopEntries("MostActive", 1)
			expect(#top1).to.equal(1)
			expect(top1[1].UserId).to.equal(103)
		end)

		it("caches resolved usernames", function()
			LeaderboardService:_updatePlayerStat(101, "MostBobaBucks", 500)
			LeaderboardService:GetTopEntries("MostBobaBucks", 1)
			expect(LeaderboardService._nameCache[101]).to.equal("BaristaAlice")

			-- Change name in mock service; cached name should still be returned
			mockPlayersService._names[101] = "ChangedName"
			local top = LeaderboardService:GetTopEntries("MostBobaBucks", 1)
			expect(top[1].Name).to.equal("BaristaAlice")
		end)

		it("batches increments into one write per (user, board) per flush", function()
			local fakePlayer: any = { UserId = 101, Name = "BaristaAlice" }
			local updateCalls = 0
			local store = LeaderboardService:_getOrderedDataStore(LeaderboardConfig.GetMonthKey("OrdersServed"))
			local originalUpdate = store.UpdateAsync
			store.UpdateAsync = function(self, key, transform)
				updateCalls += 1
				return originalUpdate(self, key, transform)
			end

			for _ = 1, 5 do
				LeaderboardService:IncrementStat(fakePlayer, "OrdersServed", 1)
			end
			LeaderboardService:IncrementStat(fakePlayer, "MostBobaBucks", 30)
			LeaderboardService:IncrementStat(fakePlayer, "MostBobaBucks", 12)
			expect(updateCalls).to.equal(0)

			LeaderboardService:FlushAll()
			expect(updateCalls).to.equal(1)
			expect(LeaderboardService:GetTopEntries("OrdersServed", 1)[1].Value).to.equal(5)
			expect(LeaderboardService:GetTopEntries("MostBobaBucks", 1)[1].Value).to.equal(42)

			-- Nothing left pending, so a second flush writes nothing.
			LeaderboardService:FlushAll()
			expect(updateCalls).to.equal(1)
		end)

		describe("failed flush re-queue", function()
			local fakePlayer: any = { UserId = 101, Name = "BaristaAlice" }

			-- Makes the first `failures` UpdateAsync calls throw; later calls use the real mock.
			local function failFirst(failures: number)
				local store = LeaderboardService:_getOrderedDataStore(LeaderboardConfig.GetMonthKey("OrdersServed"))
				local originalUpdate = store.UpdateAsync
				local calls = 0
				store.UpdateAsync = function(self, key, transform)
					calls += 1
					if calls <= failures then
						error("simulated DataStore failure")
					end
					return originalUpdate(self, key, transform)
				end
				return store
			end

			it("re-queues a failed write and writes it once on the next flush", function()
				local store = failFirst(1)
				LeaderboardService:IncrementStat(fakePlayer, "OrdersServed", 4)

				LeaderboardService:FlushAll()
				expect(LeaderboardService._pending[101].OrdersServed).to.equal(4)
				expect(store._data["101"]).to.equal(nil)
				expect(LeaderboardService._flushFailures[101].OrdersServed).to.equal(1)

				LeaderboardService:FlushAll()
				expect(store._data["101"]).to.equal(4)
				expect(LeaderboardService._pending[101]).to.equal(nil)
				expect(LeaderboardService._flushFailures[101]).to.equal(nil)
			end)

			it("drops the delta after FLUSH_MAX_ATTEMPTS failed flushes", function()
				local store = failFirst(math.huge)
				LeaderboardService:IncrementStat(fakePlayer, "OrdersServed", 4)

				for _ = 1, LeaderboardConfig.FLUSH_MAX_ATTEMPTS do
					LeaderboardService:FlushAll()
				end
				expect(LeaderboardService._pending[101]).to.equal(nil)
				expect(LeaderboardService._flushFailures[101]).to.equal(nil)
				expect(store._data["101"]).to.equal(nil)
			end)

			it("does not re-queue once shutdown has begun", function()
				failFirst(math.huge)
				LeaderboardService._closing = true
				LeaderboardService:IncrementStat(fakePlayer, "OrdersServed", 4)

				LeaderboardService:FlushAll()
				expect(LeaderboardService._pending[101]).to.equal(nil)
				expect(LeaderboardService._flushFailures[101]).to.equal(nil)
			end)

			it("sums an increment that arrives between the failure and the retry", function()
				local store = failFirst(1)
				LeaderboardService:IncrementStat(fakePlayer, "OrdersServed", 4)
				LeaderboardService:FlushAll()

				LeaderboardService:IncrementStat(fakePlayer, "OrdersServed", 3)
				expect(LeaderboardService._pending[101].OrdersServed).to.equal(7)

				LeaderboardService:FlushAll()
				expect(store._data["101"]).to.equal(7)
			end)
		end)

		it("feeds the all-time store too, so Global boards never reset monthly (TAKEOVER-REVIEW-FIX P2-4)", function()
			local fakePlayer: any = { UserId = 101, Name = "BaristaAlice" }
			LeaderboardService:IncrementStat(fakePlayer, "OrdersServed", 6)
			LeaderboardService:FlushAll()
			expect(LeaderboardService:GetTopEntries("OrdersServed", 1)[1].Value).to.equal(6)
			expect(LeaderboardService:GetTopEntries("OrdersServed", 1, true)[1].Value).to.equal(6)

			-- A later month's store starts empty; the all-time store keeps the total.
			local nextMonth = os.time({ year = 2099, month = 1, day = 15, hour = 12 })
			local nextKey = LeaderboardConfig.GetMonthKey("OrdersServed", nextMonth)
			expect(mockStores[nextKey]).to.equal(nil)
			expect(mockStores[LeaderboardConfig.GetAllTimeKey("OrdersServed")]._data["101"]).to.equal(6)
		end)

		it("ignores increments to hidden boards", function()
			local fakePlayer: any = { UserId = 102, Name = "BaristaBob" }
			LeaderboardService:IncrementStat(fakePlayer, "MostTips", 50)
			LeaderboardService:IncrementStat(fakePlayer, "TopDonators", 100)
			expect(LeaderboardService._pending[102]).to.equal(nil)
			LeaderboardService:FlushAll()
			expect(LeaderboardService:GetTopEntries("MostTips", 10)[1]).to.equal(nil)
			expect(LeaderboardService:GetTopEntries("TopDonators", 10)[1]).to.equal(nil)
		end)

		it("formats leaderboard text lines with top entries and placeholders", function()
			local entries = {
				{ UserId = 101, Name = "Alice", Value = 100 },
				{ UserId = 102, Name = "Bob", Value = 80 },
			}
			local text = LeaderboardService:_formatEntriesText(entries)
			expect(string.find(text, "1. Alice - 100", 1, true) ~= nil).to.equal(true)
			expect(string.find(text, "2. Bob - 80", 1, true) ~= nil).to.equal(true)
			expect(string.find(text, "3. ---", 1, true) ~= nil).to.equal(true)
			expect(string.find(text, "10. ---", 1, true) ~= nil).to.equal(true)
		end)
	end)
end

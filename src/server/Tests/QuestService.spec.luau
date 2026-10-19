-- selene: allow(undefined_variable)
--[[
	QuestService.spec.luau
	TestEZ unit tests for QuestService and QuestConfig.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Promise = require(ReplicatedStorage.Packages.Promise)
	local QuestConfig = require(ReplicatedStorage.Shared.Configuration.QuestConfig)
	local service = require(ServerScriptService.Server.Modules.QuestService)

	-- ──────────────────────────────────────────────────────────────────────
	-- Helpers and Fakes
	-- ──────────────────────────────────────────────────────────────────────

	local function makePlayer(userId: number)
		return { UserId = userId, Name = "Player_" .. userId }
	end

	local function makePlayerData(assignedDay: number?, activeQuests: any?, freeRerolls: number?, bobaBucks: number?)
		local data = {
			Currency = { BobaBucks = bobaBucks or 100, Points = 0 },
			Quests = {
				AssignedDay = assignedDay or 0,
				ActiveQuests = activeQuests or {},
				FreeRerollsRemaining = freeRerolls or 0,
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

	local fakeData: any
	local currentDay: number
	local currentTime: number
	local ownedPasses: { [number]: boolean }
	local currencyCalls: { { player: any, type: string, amount: number, reason: string? } }
	local xpCalls: { { player: any, amount: number } }

	local originalGetService = service._getService
	local originalNow = service._now
	local originalGetCurrentDay = service._getCurrentDay
	local originalHasPass = service._hasPass

	beforeEach(function()
		currentDay = 100
		currentTime = 100 * 86400
		fakeData = makePlayerData(0, {}, 0, 100)
		ownedPasses = {}
		currencyCalls = {}
		xpCalls = {}

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
				if currencyType == "BobaBucks" and fakeData.Currency then
					fakeData.Currency.BobaBucks += amount
				end
			end,
		}

		local progressionService = {
			AddXP = function(_, player, amount)
				table.insert(xpCalls, { player = player, amount = amount })
			end,
			AddXp = function(_, player, amount)
				table.insert(xpCalls, { player = player, amount = amount })
			end,
		}

		service._getService = function(_, name: string)
			if name == "DataService" then
				return dataService
			elseif name == "CurrencyService" then
				return currencyService
			elseif name == "ProgressionService" then
				return progressionService
			end
			return nil
		end

		service._now = function()
			return currentTime
		end

		service._getCurrentDay = function()
			return currentDay
		end

		service._hasPass = function(_, _player, passId: number)
			return ownedPasses[passId] == true
		end
	end)

	afterEach(function()
		service._getService = originalGetService
		service._now = originalNow
		service._getCurrentDay = originalGetCurrentDay
		service._hasPass = originalHasPass
	end)

	-- ──────────────────────────────────────────────────────────────────────
	-- Test Suites
	-- ──────────────────────────────────────────────────────────────────────

	describe("Day transition and fresh quest generation", function()
		it("should generate 3 base quests when player has no assigned day", function()
			local player = makePlayer(1001)
			local quests = service:GetQuests(player)

			expect(#quests).to.equal(3)
			expect(fakeData.Quests.AssignedDay).to.equal(100)
			for _, quest in quests do
				expect(quest.Progress).to.equal(0)
				expect(quest.Completed).to.equal(false)
				expect(quest.Claimed).to.equal(false)
				expect(quest.Target > 0).to.equal(true)
			end
		end)

		it("should return existing quests without regenerating if day has not changed", function()
			local player = makePlayer(1001)
			local firstQuests = service:GetQuests(player)
			firstQuests[1].Progress = 2

			local secondQuests = service:GetQuests(player)
			expect(#secondQuests).to.equal(3)
			expect(secondQuests[1].Progress).to.equal(2)
		end)

		it("should generate fresh quests when the day transitions", function()
			local player = makePlayer(1001)
			local firstQuests = service:GetQuests(player)
			firstQuests[1].Progress = 3

			currentDay = 101
			currentTime = 101 * 86400

			local secondQuests = service:GetQuests(player)
			expect(#secondQuests).to.equal(3)
			expect(fakeData.Quests.AssignedDay).to.equal(101)
			for _, quest in secondQuests do
				expect(quest.Progress).to.equal(0)
				expect(quest.Completed).to.equal(false)
				expect(quest.Claimed).to.equal(false)
			end
		end)
	end)

	describe("Progress advancement by quest type", function()
		it("should advance progress only for matching quest type", function()
			local player = makePlayer(1002)
			fakeData.Quests.AssignedDay = currentDay
			fakeData.Quests.ActiveQuests = {
				{
					Id = "100_CustomersServed_5",
					Type = "CustomersServed",
					Target = 5,
					Progress = 0,
					Completed = false,
					Claimed = false,
					RewardBobaBucks = 60,
					RewardXP = 30,
				},
				{
					Id = "100_SpillsCleaned_4",
					Type = "SpillsCleaned",
					Target = 4,
					Progress = 1,
					Completed = false,
					Claimed = false,
					RewardBobaBucks = 40,
					RewardXP = 20,
				},
			}

			local changed = service:AdvanceQuest(player, "CustomersServed", 2)
			expect(changed).to.equal(true)
			expect(fakeData.Quests.ActiveQuests[1].Progress).to.equal(2)
			expect(fakeData.Quests.ActiveQuests[1].Completed).to.equal(false)
			expect(fakeData.Quests.ActiveQuests[2].Progress).to.equal(1)
		end)

		it("should complete quest and clamp progress at target", function()
			local player = makePlayer(1002)
			fakeData.Quests.AssignedDay = currentDay
			fakeData.Quests.ActiveQuests = {
				{
					Id = "100_CustomersServed_5",
					Type = "CustomersServed",
					Target = 5,
					Progress = 4,
					Completed = false,
					Claimed = false,
					RewardBobaBucks = 60,
					RewardXP = 30,
				},
			}

			local changed = service:AdvanceQuest(player, "CustomersServed", 3)
			expect(changed).to.equal(true)
			expect(fakeData.Quests.ActiveQuests[1].Progress).to.equal(5)
			expect(fakeData.Quests.ActiveQuests[1].Completed).to.equal(true)

			-- Advancing an already completed quest should not increment progress
			local changedAgain = service:AdvanceQuest(player, "CustomersServed", 1)
			expect(changedAgain).to.equal(false)
			expect(fakeData.Quests.ActiveQuests[1].Progress).to.equal(5)
		end)
	end)

	describe("Quest completion and reward claim idempotency", function()
		it("should grant BobaBucks and XP when claiming a completed quest", function()
			local player = makePlayer(1003)
			fakeData.Quests.AssignedDay = currentDay
			fakeData.Quests.ActiveQuests = {
				{
					Id = "100_CustomersServed_5",
					Type = "CustomersServed",
					Target = 5,
					Progress = 5,
					Completed = true,
					Claimed = false,
					RewardBobaBucks = 60,
					RewardXP = 30,
				},
			}

			local ok, err = service:ClaimQuest(player, 1)
			expect(ok).to.equal(true)
			expect(err).to.equal(nil)
			expect(fakeData.Quests.ActiveQuests[1].Claimed).to.equal(true)

			expect(#currencyCalls).to.equal(1)
			expect(currencyCalls[1].type).to.equal("BobaBucks")
			expect(currencyCalls[1].amount).to.equal(60)
			expect(currencyCalls[1].reason).to.equal("QuestReward")

			expect(#xpCalls).to.equal(1)
			expect(xpCalls[1].amount).to.equal(30)
		end)

		it("should reject claiming an uncompleted quest", function()
			local player = makePlayer(1003)
			fakeData.Quests.AssignedDay = currentDay
			fakeData.Quests.ActiveQuests = {
				{
					Id = "100_CustomersServed_5",
					Type = "CustomersServed",
					Target = 5,
					Progress = 2,
					Completed = false,
					Claimed = false,
					RewardBobaBucks = 60,
					RewardXP = 30,
				},
			}

			local ok, err = service:ClaimQuest(player, 1)
			expect(ok).to.equal(false)
			expect(err).to.equal("QuestNotCompleted")
			expect(#currencyCalls).to.equal(0)
			expect(#xpCalls).to.equal(0)
		end)

		it("should reject claiming a quest that has already been claimed (idempotent)", function()
			local player = makePlayer(1003)
			fakeData.Quests.AssignedDay = currentDay
			fakeData.Quests.ActiveQuests = {
				{
					Id = "100_CustomersServed_5",
					Type = "CustomersServed",
					Target = 5,
					Progress = 5,
					Completed = true,
					Claimed = true,
					RewardBobaBucks = 60,
					RewardXP = 30,
				},
			}

			local ok, err = service:ClaimQuest(player, 1)
			expect(ok).to.equal(false)
			expect(err).to.equal("AlreadyClaimed")
			expect(#currencyCalls).to.equal(0)
			expect(#xpCalls).to.equal(0)
		end)
	end)

	describe("Bonus slot calculation with GamepassUtil mock", function()
		it("should grant 4 quest slots to Star Employee owners", function()
			local player = makePlayer(1004)
			ownedPasses[QuestConfig.BONUS_SLOT_PASSES[1]] = true -- Star Employee (219650999)

			local quests = service:GetQuests(player)
			expect(#quests).to.equal(4)
			expect(fakeData.Quests.FreeRerollsRemaining).to.equal(1)
		end)

		it("should grant 4 quest slots to More Quests owners", function()
			local player = makePlayer(1005)
			ownedPasses[QuestConfig.BONUS_SLOT_PASSES[2]] = true -- More Quests (12385834)

			local quests = service:GetQuests(player)
			expect(#quests).to.equal(4)
			expect(fakeData.Quests.FreeRerollsRemaining).to.equal(0)
		end)

		it("should allow Star Employee owner to use their free reroll", function()
			local player = makePlayer(1006)
			ownedPasses[QuestConfig.FREE_REROLL_PASS] = true
			fakeData.Currency.BobaBucks = 100

			service:GetQuests(player)
			expect(fakeData.Quests.FreeRerollsRemaining).to.equal(1)

			local ok, err = service:RerollQuest(player, 1)
			expect(ok).to.equal(true)
			expect(err).to.equal(nil)
			expect(fakeData.Quests.FreeRerollsRemaining).to.equal(0)
			-- Free reroll should not deduct BobaBucks
			expect(fakeData.Currency.BobaBucks).to.equal(100)
			expect(#currencyCalls).to.equal(0)
		end)

		it("should charge 50 BobaBucks for reroll when player has no free rerolls", function()
			local player = makePlayer(1007)
			fakeData.Quests.AssignedDay = currentDay
			fakeData.Quests.FreeRerollsRemaining = 0
			fakeData.Currency.BobaBucks = 100
			fakeData.Quests.ActiveQuests = {
				{
					Id = "100_CustomersServed_5",
					Type = "CustomersServed",
					Target = 5,
					Progress = 0,
					Completed = false,
					Claimed = false,
					RewardBobaBucks = 60,
					RewardXP = 30,
				},
			}

			local ok, err = service:RerollQuest(player, 1)
			expect(ok).to.equal(true)
			expect(err).to.equal(nil)
			expect(#currencyCalls).to.equal(1)
			expect(currencyCalls[1].type).to.equal("BobaBucks")
			expect(currencyCalls[1].amount).to.equal(-50)
			expect(currencyCalls[1].reason).to.equal("QuestReroll")
			expect(fakeData.Currency.BobaBucks).to.equal(50)
		end)

		it("should reject reroll if player has no free rerolls and insufficient BobaBucks", function()
			local player = makePlayer(1008)
			fakeData.Quests.AssignedDay = currentDay
			fakeData.Quests.FreeRerollsRemaining = 0
			fakeData.Currency.BobaBucks = 30
			fakeData.Quests.ActiveQuests = {
				{
					Id = "100_CustomersServed_5",
					Type = "CustomersServed",
					Target = 5,
					Progress = 0,
					Completed = false,
					Claimed = false,
					RewardBobaBucks = 60,
					RewardXP = 30,
				},
			}

			local ok, err = service:RerollQuest(player, 1)
			expect(ok).to.equal(false)
			expect(err).to.equal("InsufficientFunds")
			expect(#currencyCalls).to.equal(0)
			expect(fakeData.Currency.BobaBucks).to.equal(30)
		end)
	end)
end

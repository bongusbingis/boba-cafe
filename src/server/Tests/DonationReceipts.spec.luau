-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	DonationReceipts.spec.luau
	Donate! board receipt actions and Top Donators credit (REVIVAL-001 DONATIONS, Jack 2026-10-21).
]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local ProductIds = require(ReplicatedStorage.Shared.Configuration.ProductIds)
	local DonationReceipts = require(ServerScriptService.Server.Modules.DonationReceipts) :: any
	local LeaderboardService = require(ServerScriptService.Server.Modules.LeaderboardService) :: any

	-- The live IDs the Donate! board shipped with. Changing any of them needs Jack.
	local EXPECTED = {
		[928273533] = 5,
		[55777641] = 10,
		[680670445] = 20,
		[680670692] = 50,
		[680670865] = 100,
		[680671117] = 500,
		[680671325] = 1000,
		[680671544] = 5000,
		[680671832] = 10000,
		[928275862] = 50000,
		[928276567] = 100000,
		[1168137385] = 500000,
	}

	local function makePlayerData(robuxDonated: number?)
		local data: any = { RobuxDonated = robuxDonated }
		function data:SetValue(path: { string }, value: any)
			self[path[1]] = value
		end
		return data
	end

	local fakePlayer: any = { UserId = 301, Name = "Donor" }

	describe("ProductIds.Donations", function()
		it("lists exactly the 12 live donation products with their tiers", function()
			local count = 0
			for _, donation in ProductIds.Donations do
				count += 1
				expect(EXPECTED[donation.ProductId]).to.equal(donation.Robux)
			end
			expect(count).to.equal(12)
		end)
	end)

	describe("BuildActions", function()
		it("maps every donation product and nothing else", function()
			local actions = DonationReceipts.BuildActions()
			local count = 0
			for productId, action in actions do
				count += 1
				expect(EXPECTED[productId]).to.be.ok()
				expect(typeof(action.Grant)).to.equal("function")
				expect(typeof(action.OnGranted)).to.equal("function")
			end
			expect(count).to.equal(12)
			expect(actions[1143554452]).to.equal(nil) -- Skip Hatch stays in ProcessReceipt
		end)
	end)

	describe("Grant", function()
		local grant = DonationReceipts.BuildActions()[680670865].Grant

		it("adds CurrencySpent to RobuxDonated", function()
			local data = makePlayerData(40)
			local ok = grant(fakePlayer, {
				ProductId = 680670865,
				PurchaseId = "p1",
				CurrencySpent = 100,
				CurrencyType = Enum.CurrencyType.Robux,
			}, data)
			expect(ok).to.equal(true)
			expect(data.RobuxDonated).to.equal(140)
		end)

		it("falls back to the configured tier when CurrencySpent is missing", function()
			local data = makePlayerData(nil)
			local ok = grant(fakePlayer, { ProductId = 680670865, PurchaseId = "p2" }, data)
			expect(ok).to.equal(true)
			expect(data.RobuxDonated).to.equal(100)
		end)

		it("refuses a non-donation product without touching the profile", function()
			local data = makePlayerData(7)
			local ok = grant(fakePlayer, { ProductId = 1143554452, PurchaseId = "p3", CurrencySpent = 25 }, data)
			expect(ok).to.equal(false)
			expect(data.RobuxDonated).to.equal(7)
		end)
	end)

	describe("OnGranted", function()
		local originalGet = DonationReceipts._getLeaderboardService

		afterEach(function()
			DonationReceipts._getLeaderboardService = originalGet
		end)

		it("credits Top Donators with the recorded Robux", function()
			local credits = {}
			DonationReceipts._getLeaderboardService = function()
				return {
					CreditDonation = function(_, player, robux)
						table.insert(credits, { player = player, robux = robux })
					end,
				}
			end
			local onGranted = DonationReceipts.BuildActions()[680671117].OnGranted
			onGranted(fakePlayer, { ProductId = 680671117, PurchaseId = "p4", CurrencySpent = 500 })
			expect(#credits).to.equal(1)
			expect(credits[1].player).to.equal(fakePlayer)
			expect(credits[1].robux).to.equal(500)
		end)

		it("does not throw when the leaderboard is unavailable", function()
			DonationReceipts._getLeaderboardService = function()
				error("not started")
			end
			local onGranted = DonationReceipts.BuildActions()[680671117].OnGranted
			expect(function()
				onGranted(fakePlayer, { ProductId = 680671117, PurchaseId = "p5" })
			end).never.to.throw()
		end)
	end)

	describe("LeaderboardService:CreditDonation", function()
		local savedPending

		beforeEach(function()
			savedPending = LeaderboardService._pending
			LeaderboardService._pending = {}
		end)

		afterEach(function()
			LeaderboardService._pending = savedPending
		end)

		it("queues Top Donators credit even though the board is hidden", function()
			LeaderboardService:CreditDonation(fakePlayer, 100)
			LeaderboardService:CreditDonation(fakePlayer, 5)
			expect(LeaderboardService._pending[301].TopDonators).to.equal(105)
		end)

		it("ignores non-positive amounts and invalid players", function()
			LeaderboardService:CreditDonation(fakePlayer, 0)
			LeaderboardService:CreditDonation({ UserId = 0 } :: any, 50)
			expect(LeaderboardService._pending[301]).to.equal(nil)
			expect(LeaderboardService._pending[0]).to.equal(nil)
		end)
	end)
end

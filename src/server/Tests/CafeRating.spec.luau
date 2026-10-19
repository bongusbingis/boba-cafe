-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	CafeRating.spec.luau
	TestEZ tests for the rating delta maths (REVIVAL-001 M2-RATING).
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Apply = require(ServerScriptService.Server.Modules.CafeRatingService).Apply

	describe("Apply", function()
		it("adds the delta for one barista", function()
			expect(Apply(50, 4, 1)).to.equal(54)
		end)

		it("divides by the barista count", function()
			expect(Apply(50, 4, 4)).to.equal(51)
		end)

		it("treats zero baristas as one", function()
			expect(Apply(50, 4, 0)).to.equal(54)
		end)

		it("clamps to 0 and 100", function()
			expect(Apply(99, 4, 1)).to.equal(100)
			expect(Apply(1, -8, 1)).to.equal(0)
		end)
	end)

	describe("Boba Party", function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local RatingConfig = require(ReplicatedStorage.Shared.Configuration.RatingConfig)
		local CafeRatingService = require(ServerScriptService.Server.Modules.CafeRatingService) :: any

		beforeEach(function()
			CafeRatingService._partyActive = false
			CafeRatingService._partyEndTime = nil
			CafeRatingService._partyCooldownEnd = nil
			CafeRatingService._rush = false
			CafeRatingService._rating = 50
			CafeRatingService._lastRushEnd = nil
			workspace:SetAttribute("RushHour", false)
			workspace:SetAttribute("BobaParty", false)
		end)

		afterEach(function()
			CafeRatingService._partyActive = false
			CafeRatingService._partyEndTime = nil
			CafeRatingService._partyCooldownEnd = nil
			CafeRatingService._rush = false
			CafeRatingService._rating = 50
			CafeRatingService._lastRushEnd = nil
			workspace:SetAttribute("RushHour", false)
			workspace:SetAttribute("BobaParty", false)
		end)

		it("starts Boba Party when inactive and sets workspace attributes", function()
			local fakeBuyer = { Name = "TestBarista" } :: any
			local ok = CafeRatingService:StartOrExtendBobaParty(fakeBuyer)

			expect(ok).to.equal(true)
			expect(CafeRatingService._partyActive).to.equal(true)
			expect(CafeRatingService._rush).to.equal(true)
			expect(CafeRatingService._partyEndTime ~= nil).to.equal(true)
			expect(CafeRatingService._partyEndTime > os.clock()).to.equal(true)
			expect(workspace:GetAttribute("RushHour")).to.equal(true)
			expect(workspace:GetAttribute("BobaParty")).to.equal(true)
		end)

		it("extends party end time when already active", function()
			local ok1 = CafeRatingService:StartOrExtendBobaParty()
			expect(ok1).to.equal(true)
			local initialEndTime = CafeRatingService._partyEndTime

			local fakeBuyer = { Name = "TestSupporter" } :: any
			local ok2 = CafeRatingService:StartOrExtendBobaParty(fakeBuyer)

			expect(ok2).to.equal(true)
			expect(CafeRatingService._partyEndTime).to.equal(initialEndTime + RatingConfig.BOBA_PARTY_EXTENSION_SECONDS)
			expect(CafeRatingService._partyActive).to.equal(true)
			expect(CafeRatingService._rush).to.equal(true)
		end)

		it("suppresses earned rush hour while Boba Party is active", function()
			CafeRatingService:StartOrExtendBobaParty()
			expect(CafeRatingService._partyActive).to.equal(true)

			CafeRatingService._rating = 100
			CafeRatingService._lastRushEnd = nil
			CafeRatingService:_checkRush()

			expect(CafeRatingService._partyActive).to.equal(true)
			expect(CafeRatingService._rush).to.equal(true)
		end)

		it("suppresses earned rush hour during party cooldown", function()
			CafeRatingService._partyActive = false
			CafeRatingService._rush = false
			CafeRatingService._partyCooldownEnd = os.clock() + RatingConfig.BOBA_PARTY_COOLDOWN
			CafeRatingService._rating = 100
			CafeRatingService._lastRushEnd = nil

			CafeRatingService:_checkRush()

			expect(CafeRatingService._rush).to.equal(false)
		end)

		it("allows earned rush hour when party and cooldown are inactive", function()
			CafeRatingService._partyActive = false
			CafeRatingService._rush = false
			CafeRatingService._partyCooldownEnd = nil
			CafeRatingService._rating = 100
			CafeRatingService._lastRushEnd = nil

			CafeRatingService:_checkRush()

			expect(CafeRatingService._rush).to.equal(true)
		end)
	end)
end

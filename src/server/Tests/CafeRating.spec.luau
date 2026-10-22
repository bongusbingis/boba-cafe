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

		it("publishes RushEndsAt for an earned rush", function()
			CafeRatingService._partyActive = false
			CafeRatingService._rush = false
			CafeRatingService._rushEndsAt = nil
			CafeRatingService._partyCooldownEnd = nil
			CafeRatingService._rating = 100
			CafeRatingService._lastRushEnd = nil

			CafeRatingService:_checkRush()
			CafeRatingService:_publish()

			local ends = workspace:GetAttribute("RushEndsAt")
			expect(typeof(ends)).to.equal("number")
			expect(ends > workspace:GetServerTimeNow()).to.equal(true)

			CafeRatingService._rush = false
			CafeRatingService._rushEndsAt = nil
			CafeRatingService:_publish()
			expect(workspace:GetAttribute("RushEndsAt")).to.equal(nil)
		end)

		it("spotlights the buyer DisplayName and publishes BobaPartyBuyer", function()
			local fakeBuyer = { Name = "bob123", DisplayName = "Bobby" } :: any
			local ok = CafeRatingService:StartOrExtendBobaParty(fakeBuyer)

			expect(ok).to.equal(true)
			expect(CafeRatingService._partyBuyer).to.equal("Bobby")
			expect(workspace:GetAttribute("BobaPartyBuyer")).to.equal("Bobby")
			expect(typeof(workspace:GetAttribute("RushEndsAt"))).to.equal("number")

			CafeRatingService._partyActive = false
			CafeRatingService._partyEndTime = nil
			CafeRatingService._partyBuyer = nil
			CafeRatingService._rush = false
			CafeRatingService._rushEndsAt = nil
			CafeRatingService:_publish()
			expect(workspace:GetAttribute("BobaPartyBuyer")).to.equal(nil)
			expect(workspace:GetAttribute("RushEndsAt")).to.equal(nil)
		end)

		it("falls back to Name when DisplayName is missing or empty", function()
			local nameless = { Name = "SoloBarista" } :: any
			CafeRatingService:StartOrExtendBobaParty(nameless)
			expect(CafeRatingService._partyBuyer).to.equal("SoloBarista")

			CafeRatingService._partyActive = false
			CafeRatingService._partyEndTime = nil
			CafeRatingService._partyBuyer = nil
			CafeRatingService._rush = false
			CafeRatingService._rushEndsAt = nil

			local blankDisplay = { Name = "PlainName", DisplayName = "" } :: any
			CafeRatingService:StartOrExtendBobaParty(blankDisplay)
			expect(CafeRatingService._partyBuyer).to.equal("PlainName")

			CafeRatingService._partyActive = false
			CafeRatingService._partyEndTime = nil
			CafeRatingService._partyBuyer = nil
			CafeRatingService._rush = false
			CafeRatingService._rushEndsAt = nil
			CafeRatingService:_publish()
			workspace:SetAttribute("BobaPartyBuyer", nil)
			workspace:SetAttribute("RushEndsAt", nil)
		end)

		it("extension spotlights the latest buyer and keeps the buyer without one", function()
			local first = { Name = "first_one", DisplayName = "First" } :: any
			CafeRatingService:StartOrExtendBobaParty(first)
			expect(CafeRatingService._partyBuyer).to.equal("First")

			local second = { Name = "second_one", DisplayName = "Second" } :: any
			local ok = CafeRatingService:StartOrExtendBobaParty(second)
			expect(ok).to.equal(true)
			expect(CafeRatingService._partyBuyer).to.equal("Second")
			expect(workspace:GetAttribute("BobaPartyBuyer")).to.equal("Second")

			CafeRatingService:StartOrExtendBobaParty(nil)
			expect(CafeRatingService._partyBuyer).to.equal("Second")

			CafeRatingService._partyActive = false
			CafeRatingService._partyEndTime = nil
			CafeRatingService._partyBuyer = nil
			CafeRatingService._rush = false
			CafeRatingService._rushEndsAt = nil
			CafeRatingService:_publish()
			workspace:SetAttribute("BobaPartyBuyer", nil)
			workspace:SetAttribute("RushEndsAt", nil)
		end)

		it("clears BobaPartyBuyer when published nil", function()
			CafeRatingService._partyBuyer = "SomeBuyer"
			CafeRatingService:_publish()
			expect(workspace:GetAttribute("BobaPartyBuyer")).to.equal("SomeBuyer")

			CafeRatingService._partyBuyer = nil
			CafeRatingService:_publish()
			expect(workspace:GetAttribute("BobaPartyBuyer")).to.equal(nil)
		end)
	end)

	describe("Rush Hour product", function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local RatingConfig = require(ReplicatedStorage.Shared.Configuration.RatingConfig)
		local CafeRatingService = require(ServerScriptService.Server.Modules.CafeRatingService) :: any

		local function reset()
			CafeRatingService._partyActive = false
			CafeRatingService._partyEndTime = nil
			CafeRatingService._partyCooldownEnd = nil
			CafeRatingService._partyBuyer = nil
			CafeRatingService._rush = false
			CafeRatingService._rushEndTime = nil
			CafeRatingService._rushEndsAt = nil
			CafeRatingService._rushBuyer = nil
			CafeRatingService._rushToken += 1 -- retire any running end-time loop
			CafeRatingService._rating = 50
			CafeRatingService._lastRushEnd = nil
			workspace:SetAttribute("RushHour", false)
			workspace:SetAttribute("BobaParty", false)
			workspace:SetAttribute("RushHourBuyer", nil)
			workspace:SetAttribute("RushEndsAt", nil)
			workspace:SetAttribute("BobaPartyBuyer", nil)
		end

		beforeEach(reset)
		afterEach(reset)

		it("starts a rush for RUSH_SECONDS and names the buyer", function()
			local before = os.clock()
			local ok = CafeRatingService:StartOrExtendRush({ Name = "bob", DisplayName = "Bobby" } :: any)
			expect(ok).to.equal(true)
			expect(CafeRatingService._rush).to.equal(true)
			expect(CafeRatingService._partyActive).to.equal(false)
			expect(CafeRatingService._rushEndTime >= before + RatingConfig.RUSH_SECONDS).to.equal(true)
			expect(workspace:GetAttribute("RushHour")).to.equal(true)
			expect(workspace:GetAttribute("RushHourBuyer")).to.equal("Bobby")
			expect(workspace:GetAttribute("RushEndsAt") > workspace:GetServerTimeNow()).to.equal(true)
		end)

		it("adds RUSH_SECONDS to a running rush and keeps RushEndsAt accurate", function()
			CafeRatingService:StartOrExtendRush({ Name = "first" } :: any)
			local endTime = CafeRatingService._rushEndTime
			local endsAt = workspace:GetAttribute("RushEndsAt")

			CafeRatingService:StartOrExtendRush({ Name = "second" } :: any)
			expect(CafeRatingService._rushEndTime).to.equal(endTime + RatingConfig.RUSH_SECONDS)
			expect(workspace:GetAttribute("RushHourBuyer")).to.equal("second")
			local newEndsAt = workspace:GetAttribute("RushEndsAt")
			expect(math.abs(newEndsAt - (endsAt + RatingConfig.RUSH_SECONDS)) < 1).to.equal(true)
		end)

		it("adds RUSH_SECONDS to an active Boba Party", function()
			CafeRatingService:StartOrExtendBobaParty()
			local partyEnd = CafeRatingService._partyEndTime

			local ok = CafeRatingService:StartOrExtendRush({ Name = "buyer" } :: any)
			expect(ok).to.equal(true)
			expect(CafeRatingService._partyActive).to.equal(true)
			expect(CafeRatingService._partyEndTime).to.equal(partyEnd + RatingConfig.RUSH_SECONDS)
			expect(CafeRatingService._rushEndTime).to.equal(nil)
		end)

		it("ends a paid rush like an earned one and clears the buyer", function()
			CafeRatingService:StartOrExtendRush({ Name = "buyer" } :: any)
			CafeRatingService:_endRush()

			expect(CafeRatingService._rush).to.equal(false)
			expect(CafeRatingService._rating).to.equal(RatingConfig.AFTER_RUSH)
			expect(CafeRatingService._lastRushEnd ~= nil).to.equal(true)
			expect(workspace:GetAttribute("RushHour")).to.equal(false)
			expect(workspace:GetAttribute("RushHourBuyer")).to.equal(nil)
			expect(workspace:GetAttribute("RushEndsAt")).to.equal(nil)
		end)

		it("does not end a running Boba Party", function()
			CafeRatingService:StartOrExtendBobaParty()
			CafeRatingService:_endRush()
			expect(CafeRatingService._rush).to.equal(true)
			expect(CafeRatingService._partyActive).to.equal(true)
		end)

		it("earned rush uses the end-time loop and ends with the same effects", function()
			CafeRatingService._rating = 100
			CafeRatingService:_checkRush()
			expect(CafeRatingService._rush).to.equal(true)
			expect(CafeRatingService._rushBuyer).to.equal(nil)
			expect(CafeRatingService._rushEndTime > os.clock()).to.equal(true)

			-- Expire it; the loop wakes within a second.
			CafeRatingService._rushEndTime = os.clock() - 1
			local deadline = os.clock() + 3
			while CafeRatingService._rush and os.clock() < deadline do
				task.wait(0.1)
			end
			expect(CafeRatingService._rush).to.equal(false)
			expect(CafeRatingService._rating).to.equal(RatingConfig.AFTER_RUSH)
			expect(CafeRatingService._lastRushEnd ~= nil).to.equal(true)
		end)

		it("freezes the meter during a paid rush", function()
			CafeRatingService:StartOrExtendRush(nil)
			CafeRatingService:_change(4)
			expect(CafeRatingService._rating).to.equal(50)
		end)
	end)
end

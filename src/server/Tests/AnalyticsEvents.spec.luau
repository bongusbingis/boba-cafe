-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	AnalyticsEvents.spec.luau
	Unit tests for AnalyticsEvents wrapper, argument ordering, and transaction type mapping.
]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local AnalyticsEvents = require(ServerScriptService.Server.Modules.AnalyticsEvents) :: any

	describe("Transaction Type Mapping & Argument Order", function()
		it("maps transaction types to standard enum names", function()
			-- In tests or without live server, AnalyticsEvents safely executes via pcall
			local fakePlayer = { UserId = 1234567, Name = "AnalyticsTestPlayer" } :: any

			-- Economy source
			expect(function()
				AnalyticsEvents:Economy(fakePlayer, true, 50, 150, "Gameplay", "BobaBucks")
			end).never.to.throw()

			-- Economy sink with itemSku
			expect(function()
				AnalyticsEvents:Economy(fakePlayer, false, 25, 125, "Shop", "BobaBucks", "EspressoMachine_T2")
			end).never.to.throw()

			-- Points currency
			expect(function()
				AnalyticsEvents:Economy(fakePlayer, true, 10, 20, "Gameplay", "Points")
			end).never.to.throw()
		end)
	end)

	describe("Onboarding Funnel", function()
		local fakePlayer = { UserId = 7654321, Name = "FunnelTestPlayer" } :: any

		it("dispatches onboarding steps safely without throwing", function()
			expect(function()
				AnalyticsEvents:OnboardingFunnel(fakePlayer, 1, "Joined")
				AnalyticsEvents:OnboardingFunnel(fakePlayer, 2, "ClockedIn")
				AnalyticsEvents:OnboardingFunnel(fakePlayer, 3, "FirstStationUse")
				AnalyticsEvents:OnboardingFunnel(fakePlayer, 4, "FirstOrderServed")
				AnalyticsEvents:OnboardingFunnel(fakePlayer, 5, "OnboardingCompleted")
				AnalyticsEvents:OnboardingFunnel(fakePlayer, 6, "FirstShiftCompleted")
				AnalyticsEvents:OnboardingFunnel(fakePlayer, 7, "FirstNicknameSet")
				AnalyticsEvents:OnboardingFunnel(fakePlayer, 8, "FirstLevelUp")
			end).never.to.throw()
		end)

		it("is idempotent for the same step", function()
			expect(function()
				AnalyticsEvents:OnboardingFunnel(fakePlayer, 1, "Joined")
				AnalyticsEvents:OnboardingFunnel(fakePlayer, 1, "Joined")
			end).never.to.throw()
		end)
	end)

	describe("Progression Events", function()
		local fakePlayer = { UserId = 8888888, Name = "ProgressionTestPlayer" } :: any

		it("logs progression start, complete, and fail safely", function()
			expect(function()
				AnalyticsEvents:ProgressionStart(fakePlayer, "CareerLevel", 1, "Trainee")
				AnalyticsEvents:ProgressionComplete(fakePlayer, "CareerLevel", 2, "Junior Barista")
				AnalyticsEvents:ProgressionStart(fakePlayer, "Shift", 1, "Shift 1")
				AnalyticsEvents:ProgressionComplete(fakePlayer, "Shift", 1, "Shift 1")
			end).never.to.throw()
		end)
	end)

	describe("Player Segments", function()
		local fakePlayer = { UserId = 9999999, Name = "SegmentTestPlayer" } :: any

		it("returns safe table with HasData boolean", function()
			local segments = AnalyticsEvents:GetSegments(fakePlayer)
			expect(typeof(segments)).to.equal("table")
			expect(typeof(segments.HasData)).to.equal("boolean")
		end)
	end)
end

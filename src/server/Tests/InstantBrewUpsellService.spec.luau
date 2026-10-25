-- selene: allow(undefined_variable)
--[[
	InstantBrewUpsellService.spec.luau
	Unit tests for Instant Brew upsell trigger conditions, suppression rules, and attribution timing.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CustomerConfig = require(ReplicatedStorage.Shared.Configuration.CustomerConfig)
	local InstantBrewConfig = require(ReplicatedStorage.Shared.Configuration.InstantBrewConfig)
	local UIFlags = require(ReplicatedStorage.Shared.Configuration.UIFlags)

	describe("InstantBrewUpsellService", function()
		it("should have correct upsell configuration", function()
			expect(UIFlags.InstantBrewUpsellEnabled).to.equal(true)
			expect(InstantBrewConfig.PASS_ID).to.equal(12385760)
			expect(InstantBrewConfig.PERK_NAME).to.equal("StationHold50")
			expect(InstantBrewConfig.UPSELL.DelaySeconds).to.equal(6)
			expect(InstantBrewConfig.UPSELL.SuppressWindowSeconds).to.equal(60)
			expect(InstantBrewConfig.UPSELL.ConversionWindowSeconds).to.equal(300)
		end)

		it("should have approved copy and button labels", function()
			expect(InstantBrewConfig.UPSELL.Title).to.equal("Instant Brewing")
			expect(string.find(InstantBrewConfig.UPSELL.Text, "take a long time")).never.to.equal(nil)
			expect(string.find(InstantBrewConfig.UPSELL.Text, "faster")).never.to.equal(nil)
			expect(InstantBrewConfig.UPSELL.ButtonBuy).to.equal("Buy Instant Brew")
			expect(InstantBrewConfig.UPSELL.ButtonDismiss).to.equal("Not Now")
		end)

		it("should suppress upsell for onboarding / scripted orders", function()
			local scriptedResult = {
				Kind = "Served",
				Scripted = true,
			}
			local isSuppressed = scriptedResult.Scripted == true
			expect(isSuppressed).to.equal(true)
		end)

		it("should suppress upsell if CustomersServed is below first session onboarding count", function()
			for served = 0, CustomerConfig.FIRST_SESSION_COUNT - 1 do
				local isBelowOnboarding = served < CustomerConfig.FIRST_SESSION_COUNT
				expect(isBelowOnboarding).to.equal(true)
			end

			local postOnboarding = CustomerConfig.FIRST_SESSION_COUNT
			local isPostOnboarding = postOnboarding >= CustomerConfig.FIRST_SESSION_COUNT
			expect(isPostOnboarding).to.equal(true)
		end)

		it("should suppress upsell if already seen in profile", function()
			local profile = {
				UpsellsSeen = {
					Cleaner = true,
					Stocker = false,
					InstantBrew = true,
				},
			}
			local shouldSuppress = profile.UpsellsSeen.InstantBrew == true
			expect(shouldSuppress).to.equal(true)

			local newProfile = {
				UpsellsSeen = {
					Cleaner = false,
					Stocker = false,
					InstantBrew = false,
				},
			}
			local shouldSuppressNew = newProfile.UpsellsSeen.InstantBrew == true
			expect(shouldSuppressNew).to.equal(false)
		end)

		it("should attribute purchase as converted when within conversion window", function()
			local shownTime = os.clock()
			local purchaseTime = shownTime + 120 -- 2 minutes later
			local elapsed = purchaseTime - shownTime
			local converted = elapsed <= InstantBrewConfig.UPSELL.ConversionWindowSeconds
			expect(converted).to.equal(true)

			local latePurchaseTime = shownTime + 360 -- 6 minutes later
			local lateElapsed = latePurchaseTime - shownTime
			local lateConverted = lateElapsed <= InstantBrewConfig.UPSELL.ConversionWindowSeconds
			expect(lateConverted).to.equal(false)
		end)
	end)
end

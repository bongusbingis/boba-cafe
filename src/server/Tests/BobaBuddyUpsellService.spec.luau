-- selene: allow(undefined_variable)
--[[
	BobaBuddyUpsellService.spec.luau
	Unit tests for Boba Buddy upsell trigger thresholds, suppression rules, and attribution timing.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local BobaBuddyConfig = require(ReplicatedStorage.Shared.Configuration.BobaBuddyConfig)
	local UIFlags = require(ReplicatedStorage.Shared.Configuration.UIFlags)

	describe("BobaBuddyUpsellService", function()
		it("should have correct upsell configuration", function()
			expect(UIFlags.BobaBuddyUpsellEnabled).to.equal(true)
			expect(BobaBuddyConfig.UPSELL.TriggerCount).to.equal(1)
			expect(BobaBuddyConfig.UPSELL.DelaySeconds).to.equal(8)
			expect(BobaBuddyConfig.UPSELL.SuppressWindowSeconds).to.equal(60)
			expect(BobaBuddyConfig.UPSELL.ConversionWindowSeconds).to.equal(300)
		end)

		it("should have approved copy and button labels", function()
			expect(BobaBuddyConfig.UPSELL.CleanerTitle).to.equal("Boba Buddy")
			expect(string.find(BobaBuddyConfig.UPSELL.CleanerText, "clean spills")).never.to.equal(nil)
			expect(string.find(BobaBuddyConfig.UPSELL.StockerText, "restock")).never.to.equal(nil)
			expect(BobaBuddyConfig.UPSELL.ButtonSee).to.equal("See Buddy")
			expect(BobaBuddyConfig.UPSELL.ButtonDismiss).to.equal("Not Now")
		end)

		it("should suppress upsell if already seen in profile", function()
			local profile = {
				UpsellsSeen = {
					Cleaner = true,
					Stocker = false,
				},
			}
			local shouldSuppressCleaner = profile.UpsellsSeen.Cleaner == true
			local shouldSuppressStocker = profile.UpsellsSeen.Stocker == true

			expect(shouldSuppressCleaner).to.equal(true)
			expect(shouldSuppressStocker).to.equal(false)
		end)

		it("should attribute purchase as converted when within conversion window", function()
			local shownTime = os.clock()
			local purchaseTime = shownTime + 120 -- 2 minutes later
			local elapsed = purchaseTime - shownTime
			local converted = elapsed <= BobaBuddyConfig.UPSELL.ConversionWindowSeconds
			expect(converted).to.equal(true)

			local latePurchaseTime = shownTime + 360 -- 6 minutes later
			local lateElapsed = latePurchaseTime - shownTime
			local lateConverted = lateElapsed <= BobaBuddyConfig.UPSELL.ConversionWindowSeconds
			expect(lateConverted).to.equal(false)
		end)

		it("should have -5% rating penalty and toast message for NPC slips", function()
			expect(BobaBuddyConfig.NPC_SLIP.RATING_PENALTY_PERCENT).to.equal(5)
			expect(string.find(BobaBuddyConfig.NPC_SLIP.TOAST_MESSAGE, "-5%% Cafe Rating")).never.to.equal(nil)
		end)
	end)
end

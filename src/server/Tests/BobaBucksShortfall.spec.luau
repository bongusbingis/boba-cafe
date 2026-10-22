-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	BobaBucksShortfall.spec.luau
	TestEZ tests for the pure helpers of BobaBucksShortfall (UPSELL lane 1). Written, not run.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shortfall = require(ReplicatedStorage.Shared.UI.Utility.BobaBucksShortfall)

	describe("PickPackAmount", function()
		it("picks the smallest pack that covers the shortfall", function()
			expect(Shortfall.PickPackAmount(1)).to.equal(50)
			expect(Shortfall.PickPackAmount(50)).to.equal(50)
			expect(Shortfall.PickPackAmount(51)).to.equal(150)
			expect(Shortfall.PickPackAmount(500)).to.equal(500)
			expect(Shortfall.PickPackAmount(501)).to.equal(1000)
			expect(Shortfall.PickPackAmount(4999)).to.equal(5000)
		end)

		it("falls back to the largest pack when none covers it", function()
			expect(Shortfall.PickPackAmount(9000)).to.equal(5000)
		end)

		it("returns nil when nothing is owed or the input is bad", function()
			expect(Shortfall.PickPackAmount(0)).to.equal(nil)
			expect(Shortfall.PickPackAmount(-5)).to.equal(nil)
			expect(Shortfall.PickPackAmount(nil)).to.equal(nil)
			expect(Shortfall.PickPackAmount(0 / 0)).to.equal(nil)
		end)
	end)

	describe("BuildText", function()
		it("names the amount and the covering pack", function()
			local text = Shortfall.BuildText(120, "that upgrade")
			expect(string.find(text, "120 more Boba Bucks", 1, true) ~= nil).to.equal(true)
			expect(string.find(text, "150 Boba Bucks pack covers it", 1, true) ~= nil).to.equal(true)
		end)

		it("falls back to a generic line without a shortfall", function()
			expect(Shortfall.BuildText(nil, "that capsule")).to.equal(
				"You do not have enough Boba Bucks for that capsule."
			)
		end)
	end)
end

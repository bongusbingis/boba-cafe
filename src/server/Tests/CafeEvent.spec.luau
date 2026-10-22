-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	CafeEvent.spec.luau
	TestEZ tests for which Rush Hour / Boba Party intro plays on a state change (EVENT-FX).
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CafeEvent = require(ReplicatedStorage.Shared.Utility.CafeEvent)

	local function state(mode: any, endsAt: number?): any
		return { Mode = mode, EndsAt = endsAt }
	end

	describe("introFor", function()
		it("plays the new mode when an event starts", function()
			expect(CafeEvent.introFor(state(nil), state("Rush", 100))).to.equal("Rush")
			expect(CafeEvent.introFor(state(nil), state("Party", 100))).to.equal("Party")
		end)

		it("plays the party intro when a party starts during a rush", function()
			expect(CafeEvent.introFor(state("Rush", 100), state("Party", 700))).to.equal("Party")
		end)

		it("plays nothing when an event ends or nothing changes", function()
			expect(CafeEvent.introFor(state("Rush", 100), state(nil))).to.equal(nil)
			expect(CafeEvent.introFor(state("Rush", 100), state("Rush", 100))).to.equal(nil)
			expect(CafeEvent.introFor(state(nil), state(nil))).to.equal(nil)
		end)

		it("plays the extension intro only on a big end-time jump during a party", function()
			expect(CafeEvent.introFor(state("Party", 100), state("Party", 700))).to.equal("Extended")
			expect(CafeEvent.introFor(state("Party", 100), state("Party", 101))).to.equal(nil)
			expect(CafeEvent.introFor(state("Rush", 100), state("Rush", 101))).to.equal(nil)
		end)

		it("plays the rush extension intro on a big end-time jump during a rush", function()
			expect(CafeEvent.introFor(state("Rush", 100), state("Rush", 700))).to.equal("RushExtended")
			expect(CafeEvent.introFor(state("Rush", 100), state("Rush", 130))).to.equal(nil)
		end)
	end)
end

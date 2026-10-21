-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	UiSfx.spec.luau
	TestEZ tests for the pure helpers of UiSfx (REVIVAL-001 SOUNDS). Written, not run.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local UiSfx = require(ReplicatedStorage.Shared.UI.Utility.UiSfx)

	describe("ServeSpeed", function()
		it("maps combo to pitch capped at 1.25", function()
			expect(UiSfx.ServeSpeed(nil)).to.equal(1.0)
			expect(math.abs(UiSfx.ServeSpeed(2) - 1.05) < 1e-9).to.equal(true)
			expect(math.abs(UiSfx.ServeSpeed(6) - 1.25) < 1e-9).to.equal(true)
			expect(math.abs(UiSfx.ServeSpeed(20) - 1.25) < 1e-9).to.equal(true)
		end)
	end)

	describe("IsComboMilestone", function()
		it("is true only for 3, 5 and 10", function()
			expect(UiSfx.IsComboMilestone(2)).to.equal(false)
			expect(UiSfx.IsComboMilestone(3)).to.equal(true)
			expect(UiSfx.IsComboMilestone(4)).to.equal(false)
			expect(UiSfx.IsComboMilestone(5)).to.equal(true)
			expect(UiSfx.IsComboMilestone(10)).to.equal(true)
			expect(UiSfx.IsComboMilestone(11)).to.equal(false)
			expect(UiSfx.IsComboMilestone(15)).to.equal(false)
		end)
	end)
end

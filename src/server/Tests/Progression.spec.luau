-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	Progression.spec.luau
	TestEZ tests for the XP curve and ticket slots (REVIVAL-001 M2-PROGRESS).
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Progression = require(ReplicatedStorage.Shared.Configuration.Progression)

	describe("XpToNext", function()
		it("matches the design curve", function()
			expect(Progression.XpToNext(1)).to.equal(87)
			expect(Progression.XpToNext(9)).to.equal(447)
		end)
	end)

	describe("LevelForXp", function()
		it("crosses level 2 at 87 XP", function()
			expect(Progression.LevelForXp(86)).to.equal(1)
			expect(Progression.LevelForXp(87)).to.equal(2)
			expect(Progression.LevelForXp(88)).to.equal(2)
		end)

		it("caps at 50", function()
			expect(Progression.LevelForXp(10000000)).to.equal(50)
		end)
	end)

	describe("SlotsFor", function()
		it("gives a second slot at level 5", function()
			expect(Progression.SlotsFor(4)).to.equal(1)
			expect(Progression.SlotsFor(5)).to.equal(2)
		end)
	end)
end

-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	PassUpsell.spec.luau
	TestEZ tests for the UPSELL lane 2 cap and offer rules (pure logic only).
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local PassUpsell = require(ReplicatedStorage.Shared.UI.Utility.PassUpsell)

	local BARISTA = PassUpsell.BARISTA
	local LEADER = PassUpsell.KITCHEN_LEADER

	describe("ShouldShowOnPaycheck", function()
		it("never shows on the first shift", function()
			expect(PassUpsell.ShouldShowOnPaycheck(1)).to.equal(false)
		end)

		it("shows from the 2nd shift, then every 3rd", function()
			local shown = {}
			for shift = 1, 12 do
				if PassUpsell.ShouldShowOnPaycheck(shift) then
					table.insert(shown, shift)
				end
			end
			expect(table.concat(shown, ",")).to.equal("2,5,8,11")
		end)

		it("rejects non-numbers", function()
			expect(PassUpsell.ShouldShowOnPaycheck(nil)).to.equal(false)
			expect(PassUpsell.ShouldShowOnPaycheck("2")).to.equal(false)
		end)
	end)

	describe("ShouldShowOnLevelUp", function()
		it("shows from the 2nd level, then every 3rd", function()
			local shown = {}
			for level = 1, 12 do
				if PassUpsell.ShouldShowOnLevelUp(level) then
					table.insert(shown, level)
				end
			end
			expect(table.concat(shown, ",")).to.equal("2,5,8,11")
			expect(PassUpsell.ShouldShowOnLevelUp(0)).to.equal(false)
		end)
	end)

	describe("PickPaycheckOffer", function()
		it("offers Barista to a player with neither pass", function()
			expect(PassUpsell.PickPaycheckOffer({ [BARISTA] = false, [LEADER] = false })).to.equal(BARISTA)
		end)

		it("offers Kitchen Leader to a Barista owner", function()
			expect(PassUpsell.PickPaycheckOffer({ [BARISTA] = true, [LEADER] = false })).to.equal(LEADER)
		end)

		it("offers nothing to a Kitchen Leader owner or while ownership is unknown", function()
			expect(PassUpsell.PickPaycheckOffer({ [BARISTA] = false, [LEADER] = true })).to.equal(nil)
			expect(PassUpsell.PickPaycheckOffer({ [BARISTA] = true, [LEADER] = true })).to.equal(nil)
			expect(PassUpsell.PickPaycheckOffer({ [BARISTA] = false })).to.equal(nil)
			expect(PassUpsell.PickPaycheckOffer({})).to.equal(nil)
		end)
	end)

	describe("PickLevelUpOffer", function()
		it("offers Barista only when no XP pass is owned", function()
			expect(PassUpsell.PickLevelUpOffer({ [BARISTA] = false, [LEADER] = false })).to.equal(BARISTA)
			expect(PassUpsell.PickLevelUpOffer({ [BARISTA] = true, [LEADER] = false })).to.equal(nil)
			expect(PassUpsell.PickLevelUpOffer({ [BARISTA] = false, [LEADER] = true })).to.equal(nil)
			expect(PassUpsell.PickLevelUpOffer({})).to.equal(nil)
		end)
	end)

	describe("perk-based ownership", function()
		local SENIOR_BARISTA = 6202144
		local STAFF_ASSISTANT = 6202139
		local PREMIUM_LOUNGE = 2126368
		local MORE_QUESTS = 12385834
		local STAR_EMPLOYEE = 219650999

		it("lists legacy passes as perk siblings", function()
			expect(table.find(PassUpsell.GetPerkSiblings(BARISTA), SENIOR_BARISTA)).to.be.ok()
			expect(table.find(PassUpsell.GetPerkSiblings(LEADER), STAFF_ASSISTANT)).to.be.ok()
			expect(table.find(PassUpsell.GetPerkSiblings(PassUpsell.VIP), PREMIUM_LOUNGE)).to.be.ok()
			expect(table.find(PassUpsell.GetPerkSiblings(STAR_EMPLOYEE), MORE_QUESTS)).to.be.ok()
			expect(#PassUpsell.GetPerkSiblings(1)).to.equal(0)
		end)

		it("treats a legacy owner as having the perks", function()
			expect(PassUpsell.HasPerks(BARISTA, { [SENIOR_BARISTA] = true })).to.equal(true)
			expect(PassUpsell.HasPerks(LEADER, { [STAFF_ASSISTANT] = true })).to.equal(true)
			expect(PassUpsell.HasPerks(STAR_EMPLOYEE, { [MORE_QUESTS] = true })).to.equal(false)
		end)

		it("treats the pass itself as owned and non-owners as not", function()
			expect(PassUpsell.HasPerks(BARISTA, { [BARISTA] = true })).to.equal(true)
			expect(PassUpsell.HasPerks(BARISTA, { [BARISTA] = false, [SENIOR_BARISTA] = false })).to.equal(false)
			expect(PassUpsell.HasPerks(BARISTA, { [LEADER] = true })).to.equal(false)
		end)
	end)
end

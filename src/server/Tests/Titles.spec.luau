-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	Titles.spec.luau
	TestEZ tests for the title catalog (earned cosmetic): level titles are
	derived from Progression.TITLES, ownership follows level, manual titles
	are catalog-gated, and equip requires ownership.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Progression = require(ReplicatedStorage.Shared.Configuration.Progression)
	local Titles = require(ReplicatedStorage.Shared.Configuration.Titles)

	describe("level titles", function()
		it("derives one title per Progression.TITLES entry, in level order", function()
			local count = 0
			for _ in Progression.TITLES do
				count += 1
			end
			local levelTitles = {}
			for _, def in Titles.All() do
				if def.Source == "Level" then
					table.insert(levelTitles, def)
					expect(def.Text).to.equal(Progression.TITLES[def.Level])
				end
			end
			expect(#levelTitles).to.equal(count)
			for i = 2, #levelTitles do
				expect(levelTitles[i].Level > levelTitles[i - 1].Level).to.equal(true)
			end
		end)

		it("earns titles at and below the player's level only", function()
			expect(Titles.LevelOwned(1)["Level1"]).to.equal(true)
			expect(Titles.LevelOwned(4)["Level5"]).to.equal(nil)
			expect(Titles.LevelOwned(5)["Level5"]).to.equal(true)
			expect(Titles.HighestLevelTitleId(9)).to.equal("Level5")
			expect(Titles.HighestLevelTitleId(50)).to.equal("Level50")
		end)
	end)

	describe("Normalize", function()
		it("fills the shape from nothing and grants nothing", function()
			local data = Titles.Normalize(nil)
			expect(next(data.Owned)).to.equal(nil)
			expect(data.Equipped).to.equal("")
		end)

		it("drops unknown ids and an equipped title that is not owned", function()
			local data = Titles.Normalize({
				Owned = { Level1 = true, NotARealTitle = true },
				Equipped = "Level5",
			})
			expect(data.Owned.Level1).to.equal(true)
			expect(data.Owned.NotARealTitle).to.equal(nil)
			expect(data.Equipped).to.equal("")
		end)

		it("keeps an owned equipped title", function()
			local data = Titles.Normalize({
				Owned = { Level5 = true },
				Equipped = "Level5",
			})
			expect(data.Equipped).to.equal("Level5")
			expect(Titles.TextFor(data.Equipped)).to.equal(Progression.TITLES[5])
		end)
	end)

	describe("equip rules", function()
		it("requires catalog membership and ownership", function()
			local data = Titles.Normalize({ Owned = { Level1 = true }, Equipped = "" })
			expect(Titles.CanEquip(data, "Level1")).to.equal(true)
			expect(Titles.CanEquip(data, "Level5")).to.equal(false)
			expect(Titles.CanEquip(data, "NotARealTitle")).to.equal(false)
			expect(Titles.Get("NotARealTitle")).to.equal(nil)
		end)

		it("allows unequipping with empty string", function()
			local data = Titles.Normalize({ Owned = { Level1 = true }, Equipped = "Level1" })
			expect(Titles.CanEquip(data, "")).to.equal(true)
			expect(Titles.TextFor("")).to.equal("")
		end)
	end)

	describe("manual titles and unearned visibility", function()
		it("supports Secret and Hidden unearned display modes", function()
			local secretDef = Titles.Get("EventChampion")
			expect(secretDef).to.be.ok()
			expect(Titles.IsSecret(secretDef, false)).to.equal(true)
			expect(Titles.IsSecret(secretDef, true)).to.equal(false)
			expect(Titles.IsHidden(secretDef, false)).to.equal(false)

			local hiddenDef = Titles.Get("BetaTester")
			expect(hiddenDef).to.be.ok()
			expect(Titles.IsHidden(hiddenDef, false)).to.equal(true)
			expect(Titles.IsHidden(hiddenDef, true)).to.equal(false)
			expect(Titles.IsSecret(hiddenDef, false)).to.equal(false)
		end)
	end)
end

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

	describe("criteria titles and Veteran abstraction", function()
		local function createMockPlayer(attributes: { [string]: any }?)
			local attrs = attributes or {}
			return {
				UserId = 12345,
				Name = "TestPlayer",
				GetAttribute = function(_self, name: string)
					return attrs[name]
				end,
				SetAttribute = function(_self, name: string, value: any)
					attrs[name] = value
				end,
			} :: any
		end

		it("defines Veteran as a Criteria title with the approved legacy badges", function()
			local veteranDef = Titles.Get("Veteran")
			expect(veteranDef).to.be.ok()
			expect(veteranDef.Source).to.equal("Criteria")
			expect(veteranDef.SetsAttribute).to.equal("IsVeteran")
			expect(veteranDef.UnearnedDisplay).to.equal("Hidden")
			expect(veteranDef.Criteria).to.be.ok()
			expect(veteranDef.Criteria.AnyBadge).to.be.ok()
			expect(#veteranDef.Criteria.AnyBadge).to.equal(5)
			expect(Titles.VETERAN_BADGES).to.be.ok()
			expect(#Titles.VETERAN_BADGES).to.equal(5)

			local criteriaList = Titles.GetCriteriaTitles()
			expect(#criteriaList >= 1).to.equal(true)
			local foundVeteran = false
			for _, def in criteriaList do
				if def.Id == "Veteran" then
					foundVeteran = true
					break
				end
			end
			expect(foundVeteran).to.equal(true)
		end)

		it("evaluates AnyBadge criteria correctly", function()
			local veteranDef = Titles.Get("Veteran")
			local player = createMockPlayer()

			local meetsWithBadge = Titles.MeetsCriteria(veteranDef, player, {
				HasBadge = function(_p, badgeId)
					return badgeId == 2124640229
				end,
			})
			expect(meetsWithBadge).to.equal(true)

			local failsWithoutBadge = Titles.MeetsCriteria(veteranDef, player, {
				HasBadge = function(_p, _badgeId)
					return false
				end,
			})
			expect(failsWithoutBadge).to.equal(false)
		end)

		it("evaluates Stat criteria correctly", function()
			local statDef = {
				Id = "TestStatTitle",
				Text = "Master Barista",
				Source = "Criteria" :: any,
				Description = "Serve 100 drinks",
				Criteria = {
					Stat = { Key = "CustomersServed", Value = 100 },
				},
			}
			local player = createMockPlayer()

			local meetsStat = Titles.MeetsCriteria(statDef, player, {
				GetStat = function(_p, key)
					return if key == "CustomersServed" then 150 else 0
				end,
			})
			expect(meetsStat).to.equal(true)

			local failsStat = Titles.MeetsCriteria(statDef, player, {
				GetStat = function(_p, key)
					return if key == "CustomersServed" then 50 else 0
				end,
			})
			expect(failsStat).to.equal(false)
		end)

		it("evaluates Attribute and Custom criteria correctly", function()
			local attrDef = {
				Id = "TestAttrTitle",
				Text = "VIP",
				Source = "Criteria" :: any,
				Description = "Is VIP",
				Criteria = {
					Attribute = { Name = "IsVIP", Value = true },
				},
			}
			local vipPlayer = createMockPlayer({ IsVIP = true })
			local normalPlayer = createMockPlayer({ IsVIP = false })
			expect(Titles.MeetsCriteria(attrDef, vipPlayer)).to.equal(true)
			expect(Titles.MeetsCriteria(attrDef, normalPlayer)).to.equal(false)

			local customDef = {
				Id = "TestCustomTitle",
				Text = "Custom",
				Source = "Criteria" :: any,
				Description = "Custom check",
				Criteria = {
					Custom = function(p)
						return p.UserId == 12345
					end,
				},
			}
			expect(Titles.MeetsCriteria(customDef, vipPlayer)).to.equal(true)
		end)

		it("orders Level titles first, then Criteria titles, then Manual titles", function()
			local all = Titles.All()
			local seenCriteria = false
			local seenManual = false
			for _, def in all do
				if def.Source == "Level" then
					expect(seenCriteria).to.equal(false)
					expect(seenManual).to.equal(false)
				elseif def.Source == "Criteria" then
					seenCriteria = true
					expect(seenManual).to.equal(false)
				elseif def.Source == "Manual" then
					seenManual = true
				end
			end
		end)
	end)
end

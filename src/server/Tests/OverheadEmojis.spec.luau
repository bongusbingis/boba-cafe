-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	OverheadEmojis.spec.luau
	TestEZ tests for overhead emoji badges:
	- MR staff members receive the shield emoji 🛡️
	- Multi-emoji rows are evaluated per configurable criteria (MinRank, Badge, Gamepass, Stat, Attribute, Custom)
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local OverheadEmojis = require(ReplicatedStorage.Shared.Configuration.OverheadEmojis)
	local Titles = require(ReplicatedStorage.Shared.Configuration.Titles)

	local function createMockPlayer(userId: number?, attributes: { [string]: any }?)
		local attrs = attributes or {}
		return {
			UserId = userId or 12345,
			Name = "TestPlayer",
			GetAttribute = function(_self, name: string)
				return attrs[name]
			end,
			SetAttribute = function(_self, name: string, value: any)
				attrs[name] = value
			end,
		} :: any
	end

	describe("OverheadEmojis catalog", function()
		it("includes MRShield with MinRank = 11 and shield emoji", function()
			local mrShield = OverheadEmojis.Get("MRShield")
			expect(mrShield).to.be.ok()
			expect(mrShield.Emoji).to.equal("🛡️")
			expect(mrShield.Criteria).to.be.ok()
			expect(mrShield.Criteria.MinRank).to.equal(11)

			local all = OverheadEmojis.All()
			expect(#all >= 1).to.equal(true)
			local found = false
			for _, def in all do
				if def.Id == "MRShield" then
					found = true
					break
				end
			end
			expect(found).to.equal(true)
		end)
	end)

	describe("GetEmojiString and MR evaluation", function()
		it("grants shield emoji when player has rank >= 11 (MR)", function()
			local player = createMockPlayer(2001)
			local checkers: Titles.CriteriaCheckers = {
				GetRank = function(_p)
					return 11 -- MR rank
				end,
			}

			local emojiString = OverheadEmojis.GetEmojiString(player, checkers)
			expect(emojiString).to.equal("🛡️")
		end)

		it("grants shield emoji when player has higher rank (e.g. HR rank 16)", function()
			local player = createMockPlayer(2002)
			local checkers: Titles.CriteriaCheckers = {
				GetRank = function(_p)
					return 16 -- HR
				end,
			}

			local emojiString = OverheadEmojis.GetEmojiString(player, checkers)
			expect(emojiString).to.equal("🛡️")
		end)

		it("does not grant shield emoji for ranks below MR (e.g. rank 10 or 1)", function()
			local player = createMockPlayer(2003)
			local checkers: Titles.CriteriaCheckers = {
				GetRank = function(_p)
					return 10
				end,
			}

			local emojiString = OverheadEmojis.GetEmojiString(player, checkers)
			expect(emojiString).to.equal("")
		end)

		it("grants shield emoji when player has IsMR attribute set", function()
			local player = createMockPlayer(2004, { IsMR = true })
			local emojiString = OverheadEmojis.GetEmojiString(player)
			expect(emojiString).to.equal("🛡️")
		end)
	end)

	describe("Rainbow Pack emoji", function()
		it("catalogs the rainbow emoji gated on the RainbowPack attribute", function()
			local rainbow = OverheadEmojis.Get("Rainbow")
			expect(rainbow).to.be.ok()
			expect(rainbow.Emoji).to.equal("🌈")
			expect(rainbow.Criteria.Attribute.Name).to.equal("RainbowPack")
			expect(rainbow.Criteria.Attribute.Value).to.equal(true)
		end)

		it("shows the rainbow for Rainbow Pack owners, after the VIP star", function()
			local player = createMockPlayer(4001, { RainbowPack = true, VipTag = true })
			expect(OverheadEmojis.GetEmojiString(player)).to.equal("⭐ 🌈")
		end)

		it("shows no rainbow without the pass", function()
			local player = createMockPlayer(4002)
			expect(OverheadEmojis.GetEmojiString(player)).to.equal("")
		end)
	end)

	describe("Titles.MeetsCriteria with MinRank", function()
		it("evaluates MinRank criteria", function()
			local def = {
				Criteria = {
					MinRank = 11,
				},
			}
			local player = createMockPlayer(3001)

			local meets = Titles.MeetsCriteria(def, player, {
				GetRank = function(_p)
					return 12
				end,
			})
			expect(meets).to.equal(true)

			local fails = Titles.MeetsCriteria(def, player, {
				GetRank = function(_p)
					return 7
				end,
			})
			expect(fails).to.equal(false)
		end)
	end)
end

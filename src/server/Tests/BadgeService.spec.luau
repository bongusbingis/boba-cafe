-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	BadgeService.spec.luau
	Unit tests covering legacy badge definitions, veteran evaluation logic,
	and overhead title formatting (REVIVAL-001 M4-VETERAN, DEC-032).
]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")

	local BadgeService = require(ServerScriptService.Server.Modules.BadgeService) :: any

	local EXPECTED_LEGACY_BADGES = {
		Welcome = 2124469255,
		MetTheOwner = 2124491880,
		MetTheCoOwner = 2124640228,
		MetADeveloper = 2124640227,
		FirstQuest = 2124640229,
		FirstStaff = 2124640230,
		Celebrity = 2124640231,
		SakuraIsland = 2124640232,
		TreasureChest = 2124774045,
		ShinyPet = 2124774046,
		HalloweenEvent = 2124837610,
		Slipped = 2150110926,
		FirstPaycheck = 2150110897,
		LevelUp = 2150110948,
	}

	local function createMockPlayer(userId: number, initialAttributes: { [string]: any }?)
		local attributes: { [string]: any } = initialAttributes or {}
		local mockPlayer = {
			UserId = userId,
			Name = "Player_" .. tostring(userId),
			GetAttribute = function(_self, name: string)
				return attributes[name]
			end,
			SetAttribute = function(_self, name: string, value: any)
				attributes[name] = value
			end,
		}
		return mockPlayer
	end

	describe("LEGACY_BADGES array", function()
		it("contains exactly 14 pre-revival badge IDs", function()
			expect(BadgeService.LEGACY_BADGES).to.be.ok()
			expect(#BadgeService.LEGACY_BADGES).to.equal(14)
		end)

		it("contains all approved legacy badge IDs", function()
			for _, id in EXPECTED_LEGACY_BADGES do
				local found = table.find(BadgeService.LEGACY_BADGES, id) ~= nil
				expect(found).to.equal(true)
			end
		end)
	end)

	describe("CheckVeteranStatusAsync", function()
		local originalBadgeService: any

		beforeEach(function()
			originalBadgeService = BadgeService._badgeService
		end)

		afterEach(function()
			BadgeService._badgeService = originalBadgeService
		end)

		it("returns true and sets IsVeteran attribute when player owns a legacy badge", function()
			local ownedBadges: { [number]: boolean } = {
				[2124469255] = true, -- Welcome badge
			}
			BadgeService._badgeService = {
				UserHasBadgeAsync = function(_self, _userId: number, badgeId: number): boolean
					return ownedBadges[badgeId] == true
				end,
			}

			local player = createMockPlayer(1001)
			expect(player:GetAttribute("IsVeteran")).to.never.be.ok()

			local result = BadgeService:CheckVeteranStatusAsync(player)
			expect(result).to.equal(true)
			expect(player:GetAttribute("IsVeteran")).to.equal(true)
		end)

		it("returns false and leaves IsVeteran unset when player owns no legacy badges", function()
			BadgeService._badgeService = {
				UserHasBadgeAsync = function(_self, _userId: number, _badgeId: number): boolean
					return false
				end,
			}

			local player = createMockPlayer(1002)
			local result = BadgeService:CheckVeteranStatusAsync(player)
			expect(result).to.equal(false)
			expect(player:GetAttribute("IsVeteran")).to.never.be.ok()
		end)

		it("handles error during UserHasBadgeAsync gracefully without failing", function()
			BadgeService._badgeService = {
				UserHasBadgeAsync = function(_self, _userId: number, _badgeId: number): boolean
					error("Roblox HTTP 500 internal server error")
				end,
			}

			local player = createMockPlayer(1003)
			local success, result = pcall(function()
				return BadgeService:CheckVeteranStatusAsync(player)
			end)

			expect(success).to.equal(true)
			expect(result).to.equal(false)
			expect(player:GetAttribute("IsVeteran")).to.never.be.ok()
		end)

		it("short-circuits when player already has IsVeteran attribute set", function()
			local callCount = 0
			BadgeService._badgeService = {
				UserHasBadgeAsync = function(_self, _userId: number, _badgeId: number): boolean
					callCount += 1
					return true
				end,
			}

			local player = createMockPlayer(1004, { IsVeteran = true })
			local result = BadgeService:CheckVeteranStatusAsync(player)
			expect(result).to.equal(true)
			expect(callCount).to.equal(0)
		end)

		it("detects veteran status on the last badge in the list (LevelUp)", function()
			local ownedBadges: { [number]: boolean } = {
				[2150110948] = true, -- LevelUp badge
			}
			BadgeService._badgeService = {
				UserHasBadgeAsync = function(_self, _userId: number, badgeId: number): boolean
					return ownedBadges[badgeId] == true
				end,
			}

			local player = createMockPlayer(1005)
			local result = BadgeService:CheckVeteranStatusAsync(player)
			expect(result).to.equal(true)
			expect(player:GetAttribute("IsVeteran")).to.equal(true)
		end)

		it("returns false if player is nil", function()
			local result = BadgeService:CheckVeteranStatusAsync(nil)
			expect(result).to.equal(false)
		end)
	end)

	describe("Overhead Title Formatting Rules", function()
		local function formatOverheadTitle(isVeteran: boolean?, levelTitle: string?): string
			local hasVeteran = isVeteran == true
			local validLevelTitle = if typeof(levelTitle) == "string" and levelTitle ~= "" then levelTitle else nil

			if hasVeteran and validLevelTitle then
				return "Veteran • " .. validLevelTitle
			elseif hasVeteran then
				return "Veteran"
			elseif validLevelTitle then
				return validLevelTitle
			else
				return ""
			end
		end

		it("formats Veteran only when veteran with no level title", function()
			expect(formatOverheadTitle(true, nil)).to.equal("Veteran")
			expect(formatOverheadTitle(true, "")).to.equal("Veteran")
		end)

		it("formats Veteran • LevelTitle when veteran with level title", function()
			expect(formatOverheadTitle(true, "Master Barista")).to.equal("Veteran • Master Barista")
		end)

		it("formats LevelTitle only when not veteran but has level title", function()
			expect(formatOverheadTitle(false, "Master Barista")).to.equal("Master Barista")
			expect(formatOverheadTitle(nil, "Novice")).to.equal("Novice")
		end)

		it("formats empty string when neither veteran nor level title", function()
			expect(formatOverheadTitle(false, nil)).to.equal("")
			expect(formatOverheadTitle(nil, "")).to.equal("")
		end)
	end)
end

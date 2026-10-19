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

	-- DEC-035 Q3, DEC-037 Q12: FirstStaff is not a Veteran badge.
	local EXPECTED_LEGACY_BADGES = {
		FirstQuest = 2124640229,
		Celebrity = 2124640231,
		SakuraIsland = 2124640232,
		ShinyPet = 2124774046,
		HalloweenEvent = 2124837610,
	}
	local FIRST_STAFF_BADGE_ID = 2124640230

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
		it("contains exactly the five approved Veteran badge IDs", function()
			expect(BadgeService.LEGACY_BADGES).to.be.ok()
			expect(#BadgeService.LEGACY_BADGES).to.equal(5)
		end)

		it("does not include FirstStaff", function()
			expect(table.find(BadgeService.LEGACY_BADGES, FIRST_STAFF_BADGE_ID)).to.equal(nil)
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
				[2124640229] = true, -- FirstQuest badge
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

		it("does not grant Veteran when FirstStaff is the only badge owned", function()
			BadgeService._badgeService = {
				UserHasBadgeAsync = function(_self, _userId: number, badgeId: number): boolean
					return badgeId == FIRST_STAFF_BADGE_ID
				end,
			}

			local player = createMockPlayer(1006)
			local result = BadgeService:CheckVeteranStatusAsync(player)
			expect(result).to.equal(false)
			expect(player:GetAttribute("IsVeteran")).to.never.be.ok()
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

		it("detects veteran status on the last badge in the list (HalloweenEvent)", function()
			local ownedBadges: { [number]: boolean } = {
				[2124837610] = true, -- HalloweenEvent badge
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

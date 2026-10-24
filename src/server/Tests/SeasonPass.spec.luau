-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	SeasonPass.spec.luau
	"Boba Season" Season Pass (SEASON-PASS, 2026-10-23): pure SeasonConfig
	math plus SeasonPassService state normalization and premium grants,
	fake-based like BobaBuckReceipts.spec.luau.
]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local SeasonConfig = require(ReplicatedStorage.Shared.Configuration.SeasonConfig)
	local service = require(ServerScriptService.Server.Modules.SeasonPassService) :: any

	local EPOCH = SeasonConfig.SEASON_1_START_EPOCH
	local DAY = 86400

	local function makePlayerData(seasonPass: any?)
		local data: any = {
			SeasonPass = seasonPass,
			StarterBundleClaimed = false,
		}
		function data:SetValue(path: { string }, value: any)
			local pointer = self
			for i = 1, #path - 1 do
				pointer = pointer[path[i]]
			end
			pointer[path[#path]] = value
		end
		return data
	end

	local function state(seasonId: number, xp: number, premium: boolean, claimed: any?): any
		return {
			SeasonId = seasonId,
			Xp = xp,
			Premium = premium,
			ClaimedTiers = claimed or {},
		}
	end

	describe("GetCurrentSeasonId", function()
		it("returns 0 before the first season starts", function()
			expect(SeasonConfig.GetCurrentSeasonId(EPOCH - 1)).to.equal(0)
		end)

		it("returns 1 at the exact start epoch", function()
			expect(SeasonConfig.GetCurrentSeasonId(EPOCH)).to.equal(1)
		end)

		it("stays on season 1 through day 27", function()
			expect(SeasonConfig.GetCurrentSeasonId(EPOCH + 27 * DAY)).to.equal(1)
		end)

		it("rolls to season 2 at 28 days", function()
			expect(SeasonConfig.GetCurrentSeasonId(EPOCH + 28 * DAY)).to.equal(2)
		end)
	end)

	describe("XpRequired and XpCumulative", function()
		it("charges 60 for tier 1 and 350 for tier 30", function()
			expect(SeasonConfig.XpRequired(1)).to.equal(60)
			expect(SeasonConfig.XpRequired(30)).to.equal(350)
		end)

		it("totals 60 for tier 1 and 6150 for tier 30", function()
			expect(SeasonConfig.XpCumulative(1)).to.equal(60)
			expect(SeasonConfig.XpCumulative(30)).to.equal(6150)
		end)
	end)

	describe("ValidateClaim", function()
		it("rejects out-of-range tiers", function()
			local s = state(1, 99999, true)
			expect(SeasonConfig.ValidateClaim(s, 0)).to.equal("InvalidTier")
			expect(SeasonConfig.ValidateClaim(s, 31)).to.equal("InvalidTier")
			expect(SeasonConfig.ValidateClaim(s, "1")).to.equal("InvalidTier")
		end)

		it("locks tiers above the player's XP", function()
			local s = state(1, 0, true)
			expect(SeasonConfig.ValidateClaim(s, 1)).to.equal("Locked")
		end)

		it("approves a reached free tier without premium", function()
			local s = state(1, SeasonConfig.XpCumulative(3), false)
			expect(SeasonConfig.ValidateClaim(s, 3)).to.equal("Ok")
		end)

		it("requires premium for premium-only tiers", function()
			local s = state(1, SeasonConfig.XpCumulative(1), false)
			expect(SeasonConfig.ValidateClaim(s, 1)).to.equal("PremiumRequired")
		end)

		it("approves a reached premium tier with premium", function()
			local s = state(1, SeasonConfig.XpCumulative(1), true)
			expect(SeasonConfig.ValidateClaim(s, 1)).to.equal("Ok")
		end)

		it("reports already-claimed tiers", function()
			local s = state(1, SeasonConfig.XpCumulative(3), false, { [3] = true })
			expect(SeasonConfig.ValidateClaim(s, 3)).to.equal("Claimed")
		end)

		it("keeps premium retroactive after a free-only claim", function()
			local need = SeasonConfig.XpCumulative(10)
			local s = state(1, need, false, { [10] = "Free" })
			expect(SeasonConfig.ValidateClaim(s, 10)).to.equal("PremiumRequired")
			local premium = state(1, need, true, { [10] = "Free" })
			expect(SeasonConfig.ValidateClaim(s, 10)).to.equal("PremiumRequired")
			expect(SeasonConfig.ValidateClaim(premium, 10)).to.equal("Ok")
		end)

		it("treats rewardless tiers as nothing to claim", function()
			local s = state(1, SeasonConfig.XpCumulative(2), true)
			expect(SeasonConfig.ValidateClaim(s, 2)).to.equal("Empty")
		end)

		it("supports PREVIEW_SEASON_ID override", function()
			SeasonConfig.PREVIEW_SEASON_ID = 99
			expect(SeasonConfig.GetCurrentSeasonId(0)).to.equal(99)
			SeasonConfig.PREVIEW_SEASON_ID = nil
		end)

		it("derives PERK_TIERS correctly from TRACK", function()
			expect(SeasonConfig.PERK_TIERS.QuestSlot).to.equal(5)
			expect(SeasonConfig.PERK_TIERS.HatchSpeed).to.equal(10)
			expect(SeasonConfig.PERK_TIERS.QuestReroll).to.equal(15)
		end)
	end)

	describe("_ensureState", function()
		it("fills a missing table for the current season", function()
			local data = makePlayerData(nil)
			local fresh = service:_ensureState(data, EPOCH + DAY)
			expect(fresh.SeasonId).to.equal(1)
			expect(fresh.Xp).to.equal(0)
			expect(fresh.Premium).to.equal(false)
		end)

		it("resets stale seasons and forfeits unclaimed rewards", function()
			local data = makePlayerData(state(1, 5000, true, { [1] = true }))
			local fresh = service:_ensureState(data, EPOCH + 28 * DAY)
			expect(fresh.SeasonId).to.equal(2)
			expect(fresh.Xp).to.equal(0)
			expect(fresh.Premium).to.equal(false)
			expect(next(fresh.ClaimedTiers)).to.equal(nil)
		end)

		it("preserves the current season's progress", function()
			local data = makePlayerData(state(1, 500, true, { [1] = true }))
			local kept = service:_ensureState(data, EPOCH + DAY)
			expect(kept.SeasonId).to.equal(1)
			expect(kept.Xp).to.equal(500)
			expect(kept.Premium).to.equal(true)
			expect(kept.ClaimedTiers[1]).to.equal(true)
		end)

		it("stays on season 0 before the first season", function()
			local data = makePlayerData(nil)
			local fresh = service:_ensureState(data, EPOCH - 1)
			expect(fresh.SeasonId).to.equal(0)
		end)
	end)

	describe("GrantPremium", function()
		it("flags premium for the current season and returns true", function()
			local data = makePlayerData(state(1, 100, false))
			local ok = service:GrantPremium({ UserId = 7, Name = "PremiumBuyer" }, data)
			expect(ok).to.equal(true)
			expect(data.SeasonPass.Premium).to.equal(true)
			expect(data.SeasonPass.SeasonId).to.equal(1)
			expect(data.SeasonPass.Xp).to.equal(100)
		end)
	end)
end

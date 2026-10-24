-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	GroupRankProgression.spec.luau
	Unit tests for group rank mapping, level thresholds, and retired game pass overrides.
]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local GroupRankProgression = require(ReplicatedStorage.Shared.Configuration.GroupRankProgression)

	local BARISTA_PASS_ID = 6202153
	local KITCHEN_LEADER_PASS_ID = 15243046

	describe("Standard level progression", function()
		it("unlocks Trainee (Rank 6) at Level 1", function()
			local tier = GroupRankProgression.GetClaimableTier(1, 1, {})
			expect(tier ~= nil).to.equal(true)
			expect(tier.Rank).to.equal(6)
			expect(tier.RoleName).to.equal("Trainee")
		end)

		it("unlocks Junior Barista (Rank 7) at Level 5", function()
			local tier = GroupRankProgression.GetClaimableTier(5, 6, {})
			expect(tier ~= nil).to.equal(true)
			expect(tier.Rank).to.equal(7)
			expect(tier.RoleName).to.equal("Junior Barista")
		end)

		it("unlocks Barista (Rank 8) at Level 10 without game pass", function()
			local tier = GroupRankProgression.GetClaimableTier(10, 7, {})
			expect(tier ~= nil).to.equal(true)
			expect(tier.Rank).to.equal(8)
			expect(tier.RoleName).to.equal("Barista")
		end)

		it("unlocks Senior Barista (Rank 9) at Level 15", function()
			local tier = GroupRankProgression.GetClaimableTier(15, 8, {})
			expect(tier ~= nil).to.equal(true)
			expect(tier.Rank).to.equal(9)
		end)

		it("unlocks Head Barista (Rank 10) at Level 20", function()
			local tier = GroupRankProgression.GetClaimableTier(20, 9, {})
			expect(tier ~= nil).to.equal(true)
			expect(tier.Rank).to.equal(10)
		end)
	end)

	describe("Retired game pass overrides", function()
		it("allows Barista pass owner to claim Barista (Rank 8) below Level 10", function()
			-- Player is Level 2 (normally Trainee only) but owns Barista pass
			local passes = { [BARISTA_PASS_ID] = true }
			local tier = GroupRankProgression.GetClaimableTier(2, 6, passes)
			expect(tier ~= nil).to.equal(true)
			expect(tier.Rank).to.equal(8)
			expect(tier.RoleName).to.equal("Barista")
		end)

		it("allows Kitchen Leader pass owner to claim Head Barista (Rank 10) below Level 20", function()
			-- Player is Level 3 (normally Trainee only) but owns Kitchen Leader pass
			local passes = { [KITCHEN_LEADER_PASS_ID] = true }
			local tier = GroupRankProgression.GetClaimableTier(3, 1, passes)
			expect(tier ~= nil).to.equal(true)
			expect(tier.Rank).to.equal(10)
			expect(tier.RoleName).to.equal("Head Barista")
		end)

		it(
			"does NOT allow a Kitchen Leader pass owner to claim Barista (Rank 8) if they do not own Barista and are below level 10",
			function()
				-- Player owns Kitchen Leader (15243046) but NOT Barista (6202153), and is Level 3
				local passes = { [KITCHEN_LEADER_PASS_ID] = true }
				local baristaTier = nil
				for _, t in GroupRankProgression.TIERS do
					if t.Rank == 8 then
						baristaTier = t
						break
					end
				end
				expect(baristaTier ~= nil).to.equal(true)
				local isEligible = GroupRankProgression.IsEligibleForTier(baristaTier, 3, passes)
				expect(isEligible).to.equal(false)
			end
		)

		it("does NOT allow a Barista pass owner to claim Head Barista (Rank 10) if they are below level 20", function()
			-- Player owns Barista pass but NOT Kitchen Leader pass, and is Level 12
			local passes = { [BARISTA_PASS_ID] = true }
			local kitchenLeaderTier = nil
			for _, t in GroupRankProgression.TIERS do
				if t.Rank == 10 then
					kitchenLeaderTier = t
					break
				end
			end
			expect(kitchenLeaderTier ~= nil).to.equal(true)
			local isEligible = GroupRankProgression.IsEligibleForTier(kitchenLeaderTier, 12, passes)
			expect(isEligible).to.equal(false)
		end)
	end)

	describe("Up-to-date and next locked tiers", function()
		it("returns nil when player is already at or above highest eligible rank", function()
			-- Level 12, current rank 8 (Barista). Eligible up to Barista (8).
			local tier = GroupRankProgression.GetClaimableTier(12, 8, {})
			expect(tier).to.equal(nil)

			local nextTier = GroupRankProgression.GetNextLockedTier(12, 8, {})
			expect(nextTier ~= nil).to.equal(true)
			expect(nextTier.Rank).to.equal(9)
			expect(nextTier.MinLevel).to.equal(15)
		end)
	end)
end

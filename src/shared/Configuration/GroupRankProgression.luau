--!strict
--[[
	GroupRankProgression.luau
	Configuration mapping career levels and legacy game passes to Roblox group roles/ranks.

	- Maps player levels to group roles via RankId (6-10).
	- RankId is the main mapping ID plugged into the ranking system; RoleId has been removed.
	- Exposes direct x -> y mapping tables (LEVEL_TO_RANK_ID and PASS_TO_RANK_ID).
	- Supports retired passes (Barista 6202153, Kitchen Leader 15243046) which allow
	  claiming their specific rank without meeting the level requirement.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GamepassUtil = require(ReplicatedStorage:WaitForChild("Shared").Utility.GamepassUtil)

export type GroupRankTier = {
	MinLevel: number,
	RoleName: string,
	RankId: number, -- Main mapping ID plugged into the ranking system (numeric rank 6-10)
	Rank: number, -- Alias for RankId for backwards compatibility
	PassId: number?, -- Retired pass ID that allows claiming this specific rank
	PassName: string?,
}

local GroupRankProgression = {}

-- Retired pass IDs:
local BARISTA_PASS_ID = 6202153
local KITCHEN_LEADER_PASS_ID = 15243046

GroupRankProgression.BARISTA_PASS_ID = BARISTA_PASS_ID
GroupRankProgression.KITCHEN_LEADER_PASS_ID = KITCHEN_LEADER_PASS_ID

--- Direct x -> y mapping: MinLevel -> RankId
GroupRankProgression.LEVEL_TO_RANK_ID = {
	[1] = 6,
	[5] = 7,
	[10] = 8,
	[15] = 9,
	[20] = 10,
} :: { [number]: number }

--- Direct x -> y mapping: Retired PassId -> RankId
GroupRankProgression.PASS_TO_RANK_ID = {
	[BARISTA_PASS_ID] = 8,
	[KITCHEN_LEADER_PASS_ID] = 10,
} :: { [number]: number }

--- Direct x -> y mapping: RankId -> RoleName
GroupRankProgression.RANK_ID_TO_ROLE_NAME = {
	[6] = "Trainee",
	[7] = "Junior Barista",
	[8] = "Barista",
	[9] = "Senior Barista",
	[10] = "Head Barista",
} :: { [number]: string }

-- Career level to group rank tiers:
GroupRankProgression.TIERS = {
	{
		MinLevel = 1,
		RoleName = "Trainee",
		RankId = 6,
		Rank = 6,
	},
	{
		MinLevel = 5,
		RoleName = "Junior Barista",
		RankId = 7,
		Rank = 7,
	},
	{
		MinLevel = 10,
		RoleName = "Barista",
		RankId = 8,
		Rank = 8,
		PassId = BARISTA_PASS_ID,
		PassName = "Barista",
	},
	{
		MinLevel = 15,
		RoleName = "Senior Barista",
		RankId = 9,
		Rank = 9,
	},
	{
		MinLevel = 20,
		RoleName = "Head Barista",
		RankId = 10,
		Rank = 10,
		PassId = KITCHEN_LEADER_PASS_ID,
		PassName = "Kitchen Leader",
	},
} :: { GroupRankTier }

--- Checks if a player qualifies for a specific tier based on level OR specific pass ownership.
--- NOTE: Game pass ownership qualifies the player ONLY for that specific tier.
function GroupRankProgression.IsEligibleForTier(
	tier: GroupRankTier,
	playerLevel: number,
	ownedPasses: { [number]: boolean }?
): boolean
	-- 1. Standard career level requirement
	if playerLevel >= tier.MinLevel then
		return true
	end

	-- 2. Pass ownership for this specific tier
	if tier.PassId and ownedPasses and ownedPasses[tier.PassId] == true then
		return true
	end

	return false
end

--- Resolves the highest tier the player qualifies for that is strictly higher than their current rank.
function GroupRankProgression.GetClaimableTier(
	playerLevel: number,
	currentRank: number,
	ownedPasses: { [number]: boolean }?
): GroupRankTier?
	local claimable: GroupRankTier? = nil
	for _, tier in GroupRankProgression.TIERS do
		if tier.RankId > currentRank and GroupRankProgression.IsEligibleForTier(tier, playerLevel, ownedPasses) then
			if not claimable or tier.RankId > claimable.RankId then
				claimable = tier
			end
		end
	end
	return claimable
end

--- Resolves the highest overall tier the player qualifies for (regardless of current rank).
function GroupRankProgression.GetHighestEligibleTier(
	playerLevel: number,
	ownedPasses: { [number]: boolean }?
): GroupRankTier?
	local highest: GroupRankTier? = nil
	for _, tier in GroupRankProgression.TIERS do
		if GroupRankProgression.IsEligibleForTier(tier, playerLevel, ownedPasses) then
			if not highest or tier.RankId > highest.RankId then
				highest = tier
			end
		end
	end
	return highest
end

--- Resolves the next upcoming locked tier above the player's current rank and level.
function GroupRankProgression.GetNextLockedTier(
	playerLevel: number,
	currentRank: number,
	ownedPasses: { [number]: boolean }?
): GroupRankTier?
	for _, tier in GroupRankProgression.TIERS do
		if tier.RankId > currentRank and not GroupRankProgression.IsEligibleForTier(tier, playerLevel, ownedPasses) then
			return tier
		end
	end
	return nil
end

--- Asynchronously fetches relevant pass ownership for the local player.
function GroupRankProgression.FetchPassOwnershipAsync(player: Player): { [number]: boolean }
	local owned = {}
	local passesToCheck = { BARISTA_PASS_ID, KITCHEN_LEADER_PASS_ID }
	for _, passId in passesToCheck do
		local ok, owns = pcall(function()
			return GamepassUtil:PlayerOwnsPassAsync(player, passId)
		end)
		owned[passId] = ok and owns == true
	end
	return owned
end

return GroupRankProgression

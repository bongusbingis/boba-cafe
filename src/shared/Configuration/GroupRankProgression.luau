--!strict
--[[
	GroupRankProgression.luau
	Configuration mapping career levels and legacy game passes to Roblox group roles/ranks.

	- Maps player levels to group roles (with their respective rank 6-10).
	- RoleId fields are stubs for Jack to provide Open Cloud Role IDs later.
	- Supports retired passes (Barista 6202153, Kitchen Leader 15243046) which allow
	  claiming their specific rank without meeting the level requirement.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GamepassUtil = require(ReplicatedStorage:WaitForChild("Shared").Utility.GamepassUtil)

export type GroupRankTier = {
	MinLevel: number,
	RoleName: string,
	Rank: number, -- Numeric rank (6-10)
	RoleId: string?, -- STUB: Jack to provide Open Cloud Role ID later
	PassId: number?, -- Retired pass ID that allows claiming this specific rank
	PassName: string?,
}

local GroupRankProgression = {}

-- Retired pass IDs:
local BARISTA_PASS_ID = 6202153
local KITCHEN_LEADER_PASS_ID = 15243046

-- Career level to group rank tiers:
GroupRankProgression.TIERS = {
	{
		MinLevel = 1,
		RoleName = "Trainee",
		Rank = 6,
		RoleId = nil, -- STUB: Jack to provide Role ID
	},
	{
		MinLevel = 5,
		RoleName = "Junior Barista",
		Rank = 7,
		RoleId = nil, -- STUB: Jack to provide Role ID
	},
	{
		MinLevel = 10,
		RoleName = "Barista",
		Rank = 8,
		RoleId = nil, -- STUB: Jack to provide Role ID
		PassId = BARISTA_PASS_ID,
		PassName = "Barista",
	},
	{
		MinLevel = 15,
		RoleName = "Senior Barista",
		Rank = 9,
		RoleId = nil, -- STUB: Jack to provide Role ID
	},
	{
		MinLevel = 20,
		RoleName = "Head Barista",
		Rank = 10,
		RoleId = nil, -- STUB: Jack to provide Role ID
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
		if tier.Rank > currentRank and GroupRankProgression.IsEligibleForTier(tier, playerLevel, ownedPasses) then
			if not claimable or tier.Rank > claimable.Rank then
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
			if not highest or tier.Rank > highest.Rank then
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
		if tier.Rank > currentRank and not GroupRankProgression.IsEligibleForTier(tier, playerLevel, ownedPasses) then
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

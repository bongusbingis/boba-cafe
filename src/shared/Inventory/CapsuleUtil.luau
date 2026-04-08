--!strict
-- Shared utility for capsule reward selection.
-- Kept separate so both ItemActions (shared) and CapsuleService (server)
-- can require it without creating circular dependencies.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local TIER_WEIGHTS = InventoryItemDefinitions.Tiers

export type Reward = { Name: string, Tier: string }

-- Returns a randomly selected item from itemType's definitions weighted by
-- tier probability, with an optional minimum rarity floor (minTier).
-- Items with a lower weight value are rarer; minTier excludes anything
-- more common than that tier (i.e. weight > minTier.Weight is excluded).
local function pickWeightedRandom(itemType: string, minTier: string?): Reward?
	local definitions = InventoryItemDefinitions[itemType]
	if not definitions then
		return nil
	end

	local minWeight: number = math.huge
	if minTier then
		local tierDef = TIER_WEIGHTS[minTier]
		if tierDef then
			minWeight = tierDef.Weight
		end
	end

	local pool: { { Name: string, Tier: string, Weight: number } } = {}
	local totalWeight = 0

	for itemName, itemDef in definitions do
		local tierDef = TIER_WEIGHTS[itemDef.Tier]
		if not tierDef then
			continue
		end
		local weight = tierDef.Weight
		if weight <= 0 then
			continue -- special/unobtainable
		end
		if weight > minWeight then
			continue -- below minimum rarity floor
		end
		table.insert(pool, { Name = itemName, Tier = itemDef.Tier, Weight = weight })
		totalWeight += weight
	end

	if totalWeight <= 0 or #pool == 0 then
		return nil
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for _, entry in pool do
		cumulative += entry.Weight
		if roll <= cumulative then
			return { Name = entry.Name, Tier = entry.Tier }
		end
	end

	local last = pool[#pool]
	return { Name = last.Name, Tier = last.Tier }
end

return {
	pickWeightedRandom = pickWeightedRandom,
}

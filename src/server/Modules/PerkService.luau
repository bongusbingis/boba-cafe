--!strict
--[[
	PerkService
	Resolves pass perks through PassCatalog (REVIVAL-001 M3-REM-B). Owners get the
	perks whether the pass is Listed or not. Boosts in one family take the highest
	value, never the sum (DEC-036 B3).
--]]

---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local PassCatalog = require(Shared.Configuration.PassCatalog)
local PerkConfig = require(Shared.Configuration.Perks)

---> service declaration
local PerkService = Knit.CreateService({
	Name = "PerkService",

	_tipRemainder = {} :: { [Player]: number }, -- fractional boost BB carried per player
	_storageMultiplier = {} :: { [Player]: number }, -- Double Storage multiplier per player
})

---> private
function PerkService:_hasPass(player: Player, passId: number): boolean
	local ok, owns = pcall(function()
		return (GamepassUtil :: any):PlayerOwnsPassAsync(player, passId)
	end)
	return ok and owns == true
end

---> public
function PerkService:HasPerk(player: Player, perk: string): boolean
	for passId, entry in PassCatalog do
		if table.find(entry.Perks, perk) ~= nil and self:_hasPass(player, passId) then
			return true
		end
	end
	return false
end

-- Highest Value among the owned perks of a family, else 0.
function PerkService:GetFamilyBonus(player: Player, family: string): number
	local best = 0
	for perkName, boost in PerkConfig.Perks do
		if boost.Family == family and boost.Value > best and self:HasPerk(player, perkName) then
			best = boost.Value
		end
	end
	return best
end

-- Tip-family bonus for serve pay: the higher of the pass and the best equipped pet
-- (highest wins, DEC-036 B1/B3). Pay is multiplied by 1 + this.
function PerkService:GetTipBonus(player: Player): number
	local passBonus = self:GetFamilyBonus(player, "Tip")
	local ok, petBonus = pcall(function()
		return Knit.GetService("PetService"):GetBestTipBonus(player)
	end)
	return math.max(passBonus, if ok and typeof(petBonus) == "number" then petBonus else 0)
end

-- Whole extra BB for one payout (synchronous: call it after GetTipBonus, never in
-- between). Base pay is untouched; base * bonus is added to the player's remainder,
-- floor(remainder) is paid and the fraction is kept for later serves.
function PerkService:TakeTipExtra(player: Player, basePay: number, bonus: number): number
	if bonus <= 0 or basePay <= 0 then
		return 0
	end
	local remainder = (self._tipRemainder[player] or 0) + basePay * bonus
	local extra = math.floor(remainder + 1e-9) -- absorb float error such as 0.02 * 50
	self._tipRemainder[player] = math.max(0, remainder - extra)
	return extra
end

-- Resolves the Double Storage multiplier once (yields on a cold pass cache; never call
-- it from a count-then-insert span). Departed players are not re-added.
function PerkService:RefreshStorageMultiplier(player: Player)
	local multiplier = if self:HasPerk(player, "InventoryX2") then PerkConfig.StorageMultiplier else 1
	if (player :: any).Parent ~= nil then
		self._storageMultiplier[player] = multiplier
	end
end

-- Synchronous, no yield. 1 until resolved, so it only ever blocks an addition.
function PerkService:GetStorageMultiplier(player: Player): number
	return self._storageMultiplier[player] or 1
end

---> lifecycle
function PerkService:PlayerAdded(player: Player)
	-- Warm the pass cache so serve/XP paths read it without yielding, then resolve the
	-- storage multiplier once the prefetch settles (no await in the hook).
	pcall(function()
		(GamepassUtil :: any):PrefetchAllPassesAsync(player):andThen(function()
			self:RefreshStorageMultiplier(player)
		end)
	end)
end

function PerkService:PlayerRemoving(player: Player)
	self._tipRemainder[player] = nil
	self._storageMultiplier[player] = nil
end

return PerkService

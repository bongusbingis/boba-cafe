--!strict
--[[
	SeasonConfig
	"Boba Season" Season Pass tuning (SEASON-PASS, 2026-10-23).

	Every economy line below is PROPOSED (Jack) until Jack approves it.
	Robux prices are never stored here (DEC-026): the UI fetches live
	Marketplace product metadata and the purchase prompt is click-only.

	Pure data + pure helpers only: no Instances, no services.
]]

export type Reward =
	{ Type: "BobaBucks", Amount: number }
	| { Type: "Capsule", Name: string }
	| { Type: "Nametag", Name: string }
	| { Type: "Title", Id: string }
	| { Type: "Perk", Perk: string }
	| { Type: "Costume", Id: string, Name: string? }

export type TierTrack = {
	Free: Reward?,
	Premium: Reward?,
}

export type ClaimMarker = true | "Free" | "Premium"

export type SeasonState = {
	SeasonId: number,
	Xp: number,
	Premium: boolean,
	ClaimedTiers: { [number]: ClaimMarker },
}

local SeasonConfig = {}

-- Emergency kill-switch: set false to disable the Season Pass and reject all claims.
SeasonConfig.ENABLED = true

-- Pre-launch / Studio override: when set, forces GetCurrentSeasonId to return this value.
SeasonConfig.PREVIEW_SEASON_ID = nil :: number?

SeasonConfig.TIER_COUNT = 30
SeasonConfig.SEASON_LENGTH_SECONDS = 28 * 86400
-- First Monday after release (2026-10-26), per Jack 2026-10-23.
SeasonConfig.SEASON_1_START_EPOCH = 1792972800 -- 2026-10-26 00:00 UTC

-- PROPOSED (Jack): tier requirement curve.
function SeasonConfig.XpRequired(tier: number): number
	return 50 + 10 * tier
end

function SeasonConfig.XpCumulative(tier: number): number
	local total = 0
	for i = 1, tier do
		total += SeasonConfig.XpRequired(i)
	end
	return total
end

-- PROPOSED (Jack): Season XP source values.
SeasonConfig.XP_SERVE = 10 -- per served customer (flat)
SeasonConfig.XP_SHIFT = 15 -- per shift ending
SeasonConfig.XP_SPILL = 5 -- per spill cleaned
SeasonConfig.XP_QUEST = 10 -- per quest claimed

-- PROPOSED (Jack): convenience perks, premium-only while claimed this season.
-- No Tip/Xp perks: they would cannibalize the Barista/Kitchen Leader/VIP
-- pass families (DEC-036 B3 highest-wins).
SeasonConfig.HATCH_SPEED_MULT = 1.25 -- PROPOSED (Jack)

-- PROPOSED (Jack): full 30-tier track. Free totals ~225 BB + 3 capsules;
-- premium adds 550 BB + exclusive nametag + Boba Buddy Costume + 3 perks.
local function bb(amount: number): Reward
	return { Type = "BobaBucks", Amount = amount }
end

local TRACK: { [number]: TierTrack } = {
	[1] = { Free = nil, Premium = { Type = "Nametag", Name = "Sunrise" } },
	[2] = {},
	[3] = { Free = bb(25) },
	[4] = {},
	[5] = { Free = nil, Premium = { Type = "Perk", Perk = "QuestSlot" } },
	[6] = { Free = bb(25) },
	[7] = {},
	[8] = {},
	[9] = { Free = bb(25) },
	[10] = { Free = { Type = "Capsule", Name = "Nametag Capsule" }, Premium = { Type = "Perk", Perk = "HatchSpeed" } },
	[11] = {},
	[12] = { Free = bb(25) },
	[13] = {},
	[14] = {},
	[15] = { Free = bb(25), Premium = { Type = "Perk", Perk = "QuestReroll" } },
	[16] = {},
	[17] = {},
	[18] = { Free = bb(25) },
	[19] = {},
	[20] = { Free = { Type = "Capsule", Name = "Regular Pet Capsule" }, Premium = bb(150) },
	[21] = { Free = bb(25) },
	[22] = {},
	[23] = {},
	[24] = { Free = bb(25) },
	[25] = { Free = nil, Premium = { Type = "Costume", Id = "BobaCostume", Name = "Boba Buddy Costume" } },
	[26] = {},
	[27] = { Free = bb(25) },
	[28] = {},
	[29] = {},
	[30] = { Free = { Type = "Capsule", Name = "Nametag Capsule" }, Premium = bb(400) },
}
SeasonConfig.TRACK = TRACK

-- Derived from TRACK so there is a single source of truth for perk tiers.
local perkTiers: { [string]: number } = {}
for tier, track in TRACK do
	if track.Premium and track.Premium.Type == "Perk" then
		perkTiers[track.Premium.Perk] = tier
	end
	if track.Free and track.Free.Type == "Perk" then
		perkTiers[track.Free.Perk] = tier
	end
end
SeasonConfig.PERK_TIERS = perkTiers

function SeasonConfig.GetCurrentSeasonId(now: number): number
	if SeasonConfig.PREVIEW_SEASON_ID ~= nil then
		return SeasonConfig.PREVIEW_SEASON_ID
	end
	if now < SeasonConfig.SEASON_1_START_EPOCH then
		return 0
	end
	return math.floor((now - SeasonConfig.SEASON_1_START_EPOCH) / SeasonConfig.SEASON_LENGTH_SECONDS) + 1
end

function SeasonConfig.GetSeasonEndTimestamp(seasonId: number): number
	return SeasonConfig.SEASON_1_START_EPOCH + seasonId * SeasonConfig.SEASON_LENGTH_SECONDS
end

export type ClaimVerdict = "Ok" | "Locked" | "Claimed" | "PremiumRequired" | "InvalidTier" | "Empty"

--- Claim validation for a tier. Returns one of:
--- "Ok" | "Locked" | "Claimed" | "PremiumRequired" | "InvalidTier" | "Empty".
--- ClaimedTiers[tier] is true when fully claimed, or "Free" when only the
--- free reward was taken (tiers with both tracks keep premium retroactive).
function SeasonConfig.ValidateClaim(state: SeasonState, tier: any): ClaimVerdict
	if typeof(tier) ~= "number" or tier ~= math.floor(tier) or tier < 1 or tier > SeasonConfig.TIER_COUNT then
		return "InvalidTier"
	end
	local track = SeasonConfig.TRACK[tier]
	local claimed = state.ClaimedTiers[tier]
	local xp = if typeof(state.Xp) == "number" then state.Xp else 0
	if xp < SeasonConfig.XpCumulative(tier) then
		return "Locked"
	end
	local freeReward = if track then track.Free else nil
	local premiumReward = if track then track.Premium else nil
	if freeReward == nil and premiumReward == nil then
		return "Empty"
	end
	local freeAvailable = freeReward ~= nil and claimed ~= true and claimed ~= "Free"
	local premiumAvailable = premiumReward ~= nil and state.Premium == true and claimed ~= true and claimed ~= "Premium"
	if freeAvailable or premiumAvailable then
		return "Ok"
	end
	if premiumReward ~= nil and state.Premium ~= true then
		return "PremiumRequired"
	end
	return "Claimed"
end

return SeasonConfig

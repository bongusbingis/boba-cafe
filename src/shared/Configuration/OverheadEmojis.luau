--!strict
--[[
	OverheadEmojis
	Catalog of overhead emoji badges displayed in a row directly above a player's nickname.

	Configurable using the exact same criteria system as Titles (`Titles.CriteriaDef`):
	- `MinRank`: minimum Roblox group rank (e.g. 11 for MR staff shield)
	- `AnyBadge` / `AllBadges`: badge ownership
	- `AnyGamepass` / `AllGamepasses`: gamepass ownership
	- `Stat`: profile statistics threshold (e.g. CustomersServed)
	- `Attribute`: player instance attributes (e.g. IsVIP, IsVeteran)
	- `Custom`: arbitrary predicate function

	To add an emoji to the overhead row, add a new entry to `OverheadEmojis.EMOJIS`!
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Titles = require(Shared.Configuration.Titles)
local PassCosmetics = require(Shared.Configuration.PassCosmetics)

export type EmojiDef = {
	Id: string,
	Emoji: string,
	Description: string,
	Criteria: Titles.CriteriaDef,
	Priority: number?, -- Lower numbers appear earlier (left-to-right) in the emoji row
}

local OverheadEmojis = {}

-- Active catalog of overhead emojis.
OverheadEmojis.EMOJIS = {
	{
		Id = "MRShield",
		Emoji = "🛡️",
		Description = "Medium Rank (MR) staff member",
		Criteria = {
			MinRank = 11,
		},
		Priority = 1,
	},
	{
		Id = "VipStar",
		Emoji = "⭐",
		Description = "VIP pass owner",
		Criteria = {
			Attribute = { Name = "VipTag", Value = true },
		},
		Priority = 2,
	},
	{
		Id = "Rainbow",
		Emoji = PassCosmetics.RAINBOW_EMOJI,
		Description = "Rainbow Pack owner",
		Criteria = {
			Attribute = { Name = PassCosmetics.RAINBOW_ATTRIBUTE, Value = true },
		},
		Priority = 3,
	},
} :: { EmojiDef }

local byId: { [string]: EmojiDef } = {}
local ordered: { EmojiDef } = {}

for _, def in OverheadEmojis.EMOJIS do
	byId[def.Id] = def
	table.insert(ordered, def)
end

table.sort(ordered, function(a: EmojiDef, b: EmojiDef): boolean
	local pA = a.Priority or 100
	local pB = b.Priority or 100
	if pA ~= pB then
		return pA < pB
	end
	return a.Id < b.Id
end)

function OverheadEmojis.All(): { EmojiDef }
	return ordered
end

function OverheadEmojis.Get(id: string): EmojiDef?
	return byId[id]
end

-- Evaluates criteria for all configured emojis and returns the ones qualified for this player.
function OverheadEmojis.GetActiveEmojis(player: Player, checkers: Titles.CriteriaCheckers?): { EmojiDef }
	local active: { EmojiDef } = {}
	for _, def in ordered do
		if Titles.MeetsCriteria(def, player, checkers) then
			table.insert(active, def)
		end
	end
	return active
end

-- Returns the active emojis concatenated as a row string (e.g. "🛡️ ⭐"), or "" if none.
function OverheadEmojis.GetEmojiString(player: Player, checkers: Titles.CriteriaCheckers?): string
	local active = OverheadEmojis.GetActiveEmojis(player, checkers)
	if #active == 0 then
		return ""
	end
	local chars: { string } = {}
	for _, def in active do
		table.insert(chars, def.Emoji)
	end
	return table.concat(chars, " ")
end

return OverheadEmojis

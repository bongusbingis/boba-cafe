--!strict
--[[
	Titles
	Title catalog: the earned cosmetic shown on the player overhead.

	Level titles are derived from `Progression.TITLES` (the single source for
	the names and the levels that earn them), so levelling up can never drift
	from this catalog.

	Criteria titles (`CRITERIA_TITLES`) are non-level titles earned automatically
	when a player meets custom conditions (badges, gamepasses, stats, attributes,
	or custom functions). Add an entry to `CRITERIA_TITLES` to make a new one!

	Manual titles (`MANUAL_TITLES`) are granted by server code only
	(`ProgressionService:GrantTitle`) for events and one-off awards; add an
	entry to `MANUAL_TITLES` to make a new one grantable. Title ids, names and
	how they are earned are product data (Jack).

	Profile shape (replicated, written only by ProgressionService):
		Titles = { Owned = { [titleId] = true }, Equipped = titleId | "" }
	Existing profiles may have no `Titles` field yet; every reader must go
	through `Normalize`, which fills the shape without granting anything.
]]

local Progression = require(script.Parent.Progression)

export type UnearnedDisplay = "Hidden" | "Secret"

export type CriteriaDef = {
	-- Minimum Roblox group rank (e.g. 11 for MR)
	MinRank: number?,
	-- Badge IDs: player qualifies if they own AT LEAST ONE of these badges
	AnyBadge: { number }?,
	-- Badge IDs: player must own ALL of these badges
	AllBadges: { number }?,
	-- Gamepass IDs: player qualifies if they own AT LEAST ONE of these gamepasses
	AnyGamepass: { number }?,
	-- Gamepass IDs: player must own ALL of these gamepasses
	AllGamepasses: { number }?,
	-- Minimum stat requirement from profile Statistics (e.g. { Key = "CustomersServed", Value = 100 })
	Stat: { Key: string, Value: number }?,
	-- Player attribute check (e.g. { Name = "IsVIP", Value = true })
	Attribute: { Name: string, Value: any }?,
	-- Custom predicate function: arbitrary logic on player
	-- (player: Player, context: { [string]: any }?) -> boolean
	Custom: ((player: Player, context: { [string]: any }?) -> boolean)?,
}

export type TitleDef = {
	Id: string,
	Text: string,
	-- "Level" titles are earned automatically at `Level`; "Criteria" titles are
	-- earned when meeting custom criteria; "Manual" titles are granted by server code.
	Source: "Level" | "Criteria" | "Manual",
	Level: number?,
	Description: string,
	-- Unearned display mode:
	-- "Hidden": completely hidden from the inventory until earned.
	-- "Secret": displays as "???" with description "???" until earned.
	-- nil: displays normally with name and description.
	UnearnedDisplay: UnearnedDisplay?,
	-- For Source == "Criteria": the criteria required to earn the title
	Criteria: CriteriaDef?,
	-- Optional attribute to set on the Player instance when earned (e.g. "IsVeteran")
	SetsAttribute: string?,
}

export type TitlesData = {
	Owned: { [string]: boolean },
	Equipped: string,
}

export type CriteriaCheckers = {
	HasBadge: ((player: Player, badgeId: number) -> boolean)?,
	HasGamepass: ((player: Player, gamepassId: number) -> boolean)?,
	GetStat: ((player: Player, statKey: string) -> number?)?,
	GetRank: ((player: Player) -> number?)?,
	Context: { [string]: any }?,
}

local Titles = {}

-- Approved legacy badge IDs for the Veteran title (DEC-032, DEC-035 Q3, DEC-037 Q12).
-- Excludes FirstStaff (DEC-037 Q12).
Titles.VETERAN_BADGES = {
	2124640229, -- FirstQuest
	2124640231, -- Celebrity
	2124640232, -- SakuraIsland
	2124774046, -- ShinyPet
	2124837610, -- HalloweenEvent
}

-- Criteria titles (non-level titles granted automatically when criteria are met).
-- To add any new criteria title, simply append an entry here!
--
-- Examples:
--   Badge criteria:
--     { Id = "Veteran", Text = "Veteran", Source = "Criteria", Description = "...", Criteria = { AnyBadge = { ... } } }
--   Stat criteria:
--     { Id = "MasterBarista", Text = "Master Barista", Source = "Criteria", Description = "...", Criteria = { Stat = { Key = "CustomersServed", Value = 500 } } }
--   Gamepass criteria:
--     { Id = "VIP", Text = "VIP", Source = "Criteria", Description = "...", Criteria = { AnyGamepass = { 12345 } } }
--   Custom criteria:
--     { Id = "NightOwl", Text = "Night Owl", Source = "Criteria", Description = "...", Criteria = { Custom = function(player) ... end } }
Titles.CRITERIA_TITLES = {
	{
		Id = "Veteran",
		Text = "Veteran",
		Source = "Criteria",
		Description = "Awarded to players who played Boba Cafe prior to the revival fresh start",
		UnearnedDisplay = "Hidden",
		SetsAttribute = "IsVeteran",
		Criteria = {
			AnyBadge = Titles.VETERAN_BADGES,
		},
	},
	{
		Id = "FormerMod",
		Text = "Former Mod",
		Source = "Criteria",
		Description = "Awarded to players who were a part of the moderation dept. prior to its merger",
		UnearnedDisplay = "Hidden",
		SetsAttribute = "IsVeteran",
		Criteria = {
			Custom = function(player)
				local ok, rank = pcall(function()
					return player:IsInGroupAsync(3174578)
				end)
				return ok and rank
			end,
		},
	},
} :: { TitleDef }

-- Manual (event / staff-awarded) titles.
-- Add { Id = "Event2026", Text = "...", Description = "...", UnearnedDisplay = "Hidden" | "Secret" }
-- and it becomes grantable with ProgressionService:GrantTitle(player, "Event2026").
Titles.MANUAL_TITLES = {
	{
		Id = "BetaTester",
		Text = "Beta Tester",
		Source = "Manual",
		Description = "Awarded for participating in early access",
		UnearnedDisplay = "Hidden",
	},
	{
		Id = "EventChampion",
		Text = "Event Champion",
		Source = "Manual",
		Description = "Awarded for winning a special event",
		UnearnedDisplay = "Secret",
	},
	{
		Id = "CafeFavourite", -- BIG-B5, DEC-058 Opus-set, Jack to tune
		Text = "Cafe Favourite",
		Source = "Manual",
		Description = "Stamp every regular on the Regulars page",
		UnearnedDisplay = "Secret",
	},
} :: { TitleDef }

local byId: { [string]: TitleDef } = {}
local ordered: { TitleDef } = {}

for level, text in Progression.TITLES do
	local def: TitleDef = {
		Id = `Level{level}`,
		Text = text,
		Source = "Level",
		Level = level,
		Description = `Reach Level {level}`,
	}
	byId[def.Id] = def
	table.insert(ordered, def)
end
for _, def in Titles.CRITERIA_TITLES do
	byId[def.Id] = def
	table.insert(ordered, def)
end
for _, def in Titles.MANUAL_TITLES do
	byId[def.Id] = def
	table.insert(ordered, def)
end

local SOURCE_ORDER = {
	Level = 1,
	Criteria = 2,
	Manual = 3,
}

table.sort(ordered, function(a: TitleDef, b: TitleDef): boolean
	if a.Source ~= b.Source then
		return (SOURCE_ORDER[a.Source] or 99) < (SOURCE_ORDER[b.Source] or 99)
	end
	if a.Level ~= b.Level then
		return (a.Level or 0) < (b.Level or 0)
	end
	return a.Id < b.Id
end)

-- Every title in display order (level titles by level, then criteria and manual titles).
function Titles.All(): { TitleDef }
	return ordered
end

-- All titles defined with custom criteria.
function Titles.GetCriteriaTitles(): { TitleDef }
	return Titles.CRITERIA_TITLES
end

function Titles.Get(titleId: string): TitleDef?
	return byId[titleId]
end

-- Title earned at exactly `level`, if any.
function Titles.ForLevel(level: number): TitleDef?
	return byId[`Level{level}`]
end

-- Id of the highest level title earned at `level` ("" below the first one).
function Titles.HighestLevelTitleId(level: number): string
	local bestLevel, bestId = 0, ""
	for _, def in ordered do
		if def.Source == "Level" and def.Level ~= nil and def.Level <= level and def.Level > bestLevel then
			bestLevel, bestId = def.Level, def.Id
		end
	end
	return bestId
end

-- Owned set a player at `level` has earned from levels alone.
function Titles.LevelOwned(level: number): { [string]: boolean }
	local owned: { [string]: boolean } = {}
	for _, def in ordered do
		if def.Source == "Level" and def.Level ~= nil and def.Level <= level then
			owned[def.Id] = true
		end
	end
	return owned
end

-- Fills the profile shape from any (possibly nil or partial) stored value.
-- Grants nothing: callers merge `LevelOwned` in themselves when they mean to.
function Titles.Normalize(raw: any): TitlesData
	local owned: { [string]: boolean } = {}
	local equipped = ""
	if typeof(raw) == "table" then
		if typeof(raw.Owned) == "table" then
			for titleId, flag in raw.Owned do
				if flag == true and typeof(titleId) == "string" and byId[titleId] ~= nil then
					owned[titleId] = true
				end
			end
		end
		if typeof(raw.Equipped) == "string" and owned[raw.Equipped] then
			equipped = raw.Equipped
		end
	end
	return { Owned = owned, Equipped = equipped }
end

function Titles.CanEquip(data: TitlesData, titleId: string): boolean
	if titleId == "" then
		return true
	end
	return byId[titleId] ~= nil and data.Owned[titleId] == true
end

-- True if the title should be redacted as "???" when locked.
function Titles.IsSecret(def: TitleDef, isOwned: boolean): boolean
	return not isOwned and def.UnearnedDisplay == "Secret"
end

-- True if the title should be completely hidden when locked.
function Titles.IsHidden(def: TitleDef, isOwned: boolean): boolean
	return not isOwned and def.UnearnedDisplay == "Hidden"
end

-- Display text for an equipped id ("" when nothing valid is equipped).
function Titles.TextFor(titleId: string): string
	local def = byId[titleId]
	return if def ~= nil then def.Text else ""
end

-- Evaluates whether a player meets a criteria definition.
-- Supports MinRank, AnyBadge, AllBadges, AnyGamepass, AllGamepasses, Stat, Attribute, and Custom function.
function Titles.MeetsCriteria(def: { Criteria: CriteriaDef? }, player: Player, checkers: CriteriaCheckers?): boolean
	local criteria = def.Criteria
	if criteria == nil then
		return false
	end

	-- 0. MinRank: minimum Roblox group rank (e.g. 11 for MR)
	if criteria.MinRank ~= nil then
		local rank: number? = nil
		if checkers ~= nil and checkers.GetRank ~= nil then
			rank = checkers.GetRank(player)
		else
			if criteria.MinRank == 11 and player:GetAttribute("IsMR") == true then
				rank = 11
			else
				local ok, res = pcall(function()
					local RankUtil = require(game:GetService("ReplicatedStorage").Shared.Utility.RankUtil)
					return RankUtil:GetRankAsync(player)
				end)
				if ok and typeof(res) == "number" then
					rank = res
				end
			end
		end
		if rank == nil or rank < criteria.MinRank then
			return false
		end
	end

	-- 1. AnyBadge: player must own at least one of these badges
	if criteria.AnyBadge ~= nil and #criteria.AnyBadge > 0 then
		local hasAny = false
		for _, badgeId in criteria.AnyBadge do
			if checkers ~= nil and checkers.HasBadge ~= nil then
				if checkers.HasBadge(player, badgeId) == true then
					hasAny = true
					break
				end
			else
				local ok, owned = pcall(function()
					local badgeService = game:GetService("BadgeService")
					return badgeService:UserHasBadgeAsync(player.UserId, badgeId)
				end)
				if ok and owned == true then
					hasAny = true
					break
				end
			end
		end
		if not hasAny then
			return false
		end
	end

	-- 2. AllBadges: player must own all of these badges
	if criteria.AllBadges ~= nil and #criteria.AllBadges > 0 then
		for _, badgeId in criteria.AllBadges do
			local owned = false
			if checkers ~= nil and checkers.HasBadge ~= nil then
				owned = checkers.HasBadge(player, badgeId) == true
			else
				local ok, res = pcall(function()
					local badgeService = game:GetService("BadgeService")
					return badgeService:UserHasBadgeAsync(player.UserId, badgeId)
				end)
				owned = ok and res == true
			end
			if not owned then
				return false
			end
		end
	end

	-- 3. AnyGamepass: player must own at least one of these gamepasses
	if criteria.AnyGamepass ~= nil and #criteria.AnyGamepass > 0 then
		local hasAny = false
		for _, passId in criteria.AnyGamepass do
			if checkers ~= nil and checkers.HasGamepass ~= nil then
				if checkers.HasGamepass(player, passId) == true then
					hasAny = true
					break
				end
			else
				local ok, owned = pcall(function()
					local ms = game:GetService("MarketplaceService")
					return ms:UserOwnsGamePassAsync(player.UserId, passId)
				end)
				if ok and owned == true then
					hasAny = true
					break
				end
			end
		end
		if not hasAny then
			return false
		end
	end

	-- 4. AllGamepasses: player must own all of these gamepasses
	if criteria.AllGamepasses ~= nil and #criteria.AllGamepasses > 0 then
		for _, passId in criteria.AllGamepasses do
			local owned = false
			if checkers ~= nil and checkers.HasGamepass ~= nil then
				owned = checkers.HasGamepass(player, passId) == true
			else
				local ok, res = pcall(function()
					local ms = game:GetService("MarketplaceService")
					return ms:UserOwnsGamePassAsync(player.UserId, passId)
				end)
				owned = ok and res == true
			end
			if not owned then
				return false
			end
		end
	end

	-- 5. Stat: profile statistic threshold (e.g. CustomersServed >= 500)
	if criteria.Stat ~= nil then
		local val: number? = nil
		if checkers ~= nil and checkers.GetStat ~= nil then
			val = checkers.GetStat(player, criteria.Stat.Key)
		else
			local attr = player:GetAttribute(criteria.Stat.Key)
			if typeof(attr) == "number" then
				val = attr
			end
		end
		if val == nil or val < criteria.Stat.Value then
			return false
		end
	end

	-- 6. Attribute: player attribute match
	if criteria.Attribute ~= nil then
		if player:GetAttribute(criteria.Attribute.Name) ~= criteria.Attribute.Value then
			return false
		end
	end

	-- 7. Custom predicate function
	if criteria.Custom ~= nil then
		local ok, result = pcall(criteria.Custom, player, if checkers ~= nil then checkers.Context else nil)
		if not ok or result ~= true then
			return false
		end
	end

	return true
end

return Titles
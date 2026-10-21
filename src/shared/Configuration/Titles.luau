--!strict
--[[
	Titles
	Title catalog: the earned cosmetic shown on the player overhead.

	Level titles are derived from `Progression.TITLES` (the single source for
	the names and the levels that earn them), so levelling up can never drift
	from this catalog. Manual titles are granted by server code only
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

export type TitleDef = {
	Id: string,
	Text: string,
	-- "Level" titles are earned automatically at `Level`; "Manual" titles are
	-- only ever granted by server code (events, staff awards).
	Source: string,
	Level: number?,
	Description: string,
	-- Unearned display mode for manual titles:
	-- "Hidden": completely hidden from the inventory until earned.
	-- "Secret": displays as "???" with description "???" until earned.
	-- nil: displays normally with name and description.
	UnearnedDisplay: UnearnedDisplay?,
}

export type TitlesData = {
	Owned: { [string]: boolean },
	Equipped: string,
}

local Titles = {}

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
for _, def in Titles.MANUAL_TITLES do
	byId[def.Id] = def
	table.insert(ordered, def)
end
table.sort(ordered, function(a: TitleDef, b: TitleDef): boolean
	if a.Source ~= b.Source then
		return a.Source == "Level"
	end
	if a.Level ~= b.Level then
		return (a.Level or 0) < (b.Level or 0)
	end
	return a.Id < b.Id
end)

-- Every title in display order (level titles by level, then manual titles).
function Titles.All(): { TitleDef }
	return ordered
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

return Titles

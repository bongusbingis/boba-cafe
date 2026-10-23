--!strict
--[[
	ProgressionService
	XP and levels 1-50 (REVIVAL-001 M2-PROGRESS). Serving earns XP, level-ups
	grant a nametag every 5 levels, show a toast, and fire Client.LeveledUp
	for the HUD celebration card. Nothing is locked.

	Player attributes: Level (number), LevelTitle (string), EquippedTitle (string).
	Titles are an earned cosmetic: level titles are granted automatically,
	manual titles only through the server-only `GrantTitle` (events, staff
	awards), and players equip owned titles from the Inventory Titles tab.
	A failure here warns and never blocks serving.
--]]

---> services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local CustomerConfig = require(Shared.Configuration.CustomerConfig)
local Progression = require(Shared.Configuration.Progression)
local Titles = require(Shared.Configuration.Titles)
local ShiftConfig = require(Shared.Configuration.ShiftConfig)
local Rules = require(script.Parent.CustomerService.Rules)

---> service declaration
local ProgressionService = Knit.CreateService({
	Name = "ProgressionService",
	Client = {
		-- Fired to the leveling player on every level-up with
		-- { Level: number, Title: string, Unlocks: { string } }.
		-- The HUD LevelUpCelebration card renders it; the toast stays
		-- as the tier-1 fallback when the card cannot show.
		LeveledUp = Knit.CreateSignal(),
	},

	_state = {} :: { [Player]: { Level: number, XP: number } }, -- cache; the profile is written on every change
	_shiftXp = {} :: { [Player]: number }, -- XP gained since the last ShiftEnding
	_equipDebounces = {} :: { [number]: boolean },
})

local function setAttributes(player: Player, level: number)
	pcall(function()
		player:SetAttribute("Level", level)
		player:SetAttribute("LevelTitle", Progression.TitleFor(level))
	end)
end

local function setEquippedTitleAttribute(player: Player, data: Titles.TitlesData)
	pcall(function()
		player:SetAttribute("EquippedTitle", Titles.TextFor(data.Equipped))
	end)
end

-- What opens at `level`, read from shared config only (GAMEPLAY-PROGRESS-CALLOUTS).
local function unlocksAt(level: number): { string }
	local out: { string } = {}
	local drinks = Rules.NewDrinksAt(level)
	if #drinks == 1 then
		table.insert(out, `New drink: {drinks[1]}`)
	elseif #drinks > 1 then
		table.insert(out, `New drinks: {table.concat(drinks, ", ")}`)
	end
	local title = Progression.TITLES[level]
	if level > 1 and title ~= nil then
		table.insert(out, `New title: {title}`)
	end
	local slots = Progression.TICKET_SLOTS[level]
	if slots ~= nil then
		table.insert(out, `{slots} order tickets`)
	end
	local items = CustomerConfig.ITEM_COUNT_BY_LEVEL[level]
	if items ~= nil then
		table.insert(out, `Orders with {items} items`)
	end
	for _, name in { "VIP", "Karen" } do
		local variant = CustomerConfig.VARIANTS[name]
		if variant ~= nil and variant.MinLevel == level then
			table.insert(out, `{name} customers`)
		end
	end
	local reward = Progression.COSMETIC_REWARDS[level]
	if reward ~= nil then
		table.insert(out, `New nametag: {reward.Name}`)
	end
	return out
end

local function nextUnlock(level: number): string?
	for n = level + 1, Progression.MAX_LEVEL do
		local list = unlocksAt(n)
		if #list > 0 then
			return `Level {n} · {list[1]}`
		end
	end
	return nil
end

---> public

-- Pure helpers (exposed for specs).

-- Level and XP into that level after adding `add` XP to `level` with `xp` into it.
function ProgressionService.Predict(level: number, xp: number, add: number): (number, number)
	local after, into = level, xp + add
	while after < Progression.MAX_LEVEL and into >= Progression.XpToNext(after) do
		into -= Progression.XpToNext(after)
		after += 1
	end
	if after >= Progression.MAX_LEVEL then
		into = 0
	end
	return after, into
end

-- Level-up toast (FEEDBACK-VOICE 6): new drinks and the nametag reward first, at most two unlocks.
function ProgressionService.LevelUpText(level: number): string
	local all = unlocksAt(level)
	local picked: { string } = {}
	for _, line in all do
		if string.find(line, "^New drink") or string.find(line, "^New nametag") then
			table.insert(picked, line)
		end
	end
	for _, line in all do
		if #picked >= 2 then
			break
		end
		if table.find(picked, line) == nil then
			table.insert(picked, line)
		end
	end
	local text = `Level up! You are now level {level}`
	for index = 1, math.min(#picked, 2) do
		text ..= ` · {picked[index]}`
	end
	return text
end

function ProgressionService.UnlocksAt(level: number): { string }
	return unlocksAt(level)
end

function ProgressionService:GetLevel(player: Player): number
	local level = player:GetAttribute("Level")
	return if typeof(level) == "number" then level else 1
end

-- Merges the level titles earned at the player's level into the stored
-- titles, keeps a valid equipped title (defaulting to the highest level
-- title for new profiles), and writes back only when something changed.
function ProgressionService:_ensureTitles(player: Player, proxy: any): Titles.TitlesData
	local state = self._state[player]
	local level = if state ~= nil then state.Level else self:GetLevel(player)
	local isNew = typeof(proxy.Data.Titles) ~= "table"
	local data = Titles.Normalize(proxy.Data.Titles)
	local changed = isNew
	for titleId in Titles.LevelOwned(level) do
		if not data.Owned[titleId] then
			data.Owned[titleId] = true
			changed = true
		end
	end
	if isNew and data.Equipped == "" then
		data.Equipped = Titles.HighestLevelTitleId(level)
	elseif data.Equipped ~= "" and not data.Owned[data.Equipped] then
		data.Equipped = ""
		changed = true
	end
	if changed then
		proxy:SetValue({ "Titles" }, data)
	end
	for ownedId in data.Owned do
		local def = Titles.Get(ownedId)
		if def ~= nil and def.SetsAttribute ~= nil and player:GetAttribute(def.SetsAttribute) ~= true then
			player:SetAttribute(def.SetsAttribute, true)
		end
	end
	setEquippedTitleAttribute(player, data)
	return data
end

-- Server-only manual grant for events and staff awards. This is the entry
-- point other server code (EventService, a Studio command) calls; it is
-- deliberately not on `Client`, so no player can grant themselves a title.
-- Returns (false, reason) for an unknown title id; granting a title the
-- player already owns succeeds and does nothing.
function ProgressionService:GrantTitle(player: Player, titleId: string): (boolean, string?)
	if Titles.Get(titleId) == nil then
		return false, "UnknownTitle"
	end
	Knit.GetService("DataService")
		:GetDataAsync(player)
		:andThen(function(proxy)
			local data = self:_ensureTitles(player, proxy)
			if data.Owned[titleId] then
				return
			end
			data.Owned[titleId] = true
			if data.Equipped == "" then
				data.Equipped = titleId
			end
			proxy:SetValue({ "Titles" }, data)
			setEquippedTitleAttribute(player, data)
			local def = Titles.Get(titleId)
			if def ~= nil then
				if def.SetsAttribute ~= nil and player:GetAttribute(def.SetsAttribute) ~= true then
					player:SetAttribute(def.SetsAttribute, true)
				end
				Knit.GetService("DialogService")
					:Notify(player, { Text = `New title: {def.Text}`, SoundEnabled = true } :: any)
			end
		end)
		:catch(function(err)
			warn(`[ProgressionService] GrantTitle failed: {err}`)
		end)
	return true, nil
end

-- Evaluates criteria titles (e.g. Veteran) for the player and grants any newly qualified ones.
function ProgressionService:_checkCriteriaTitlesAsync(player: Player, proxy: any)
	task.spawn(function()
		local checkers: Titles.CriteriaCheckers = {
			GetStat = function(_p: Player, key: string): number?
				if
					proxy.Data
					and typeof(proxy.Data.Statistics) == "table"
					and typeof(proxy.Data.Statistics[key]) == "number"
				then
					return proxy.Data.Statistics[key]
				end
				return nil
			end,
		}

		local criteriaTitles = Titles.GetCriteriaTitles()
		for _, def in criteriaTitles do
			local data = Titles.Normalize(proxy.Data.Titles)
			if not data.Owned[def.Id] then
				local meets = Titles.MeetsCriteria(def, player, checkers)
				if meets then
					self:GrantTitle(player, def.Id)
				end
			else
				if def.SetsAttribute ~= nil and player:GetAttribute(def.SetsAttribute) ~= true then
					player:SetAttribute(def.SetsAttribute, true)
				end
			end
		end
	end)
end

---> client

-- Equips an owned title, or unequips when titleId is "". The overhead
-- and the Staff tab read the result from the replicated profile and the
-- `EquippedTitle` attribute.
function ProgressionService.Client:EquipTitle(player: Player, titleId: any): { Success: boolean, Message: string }
	if typeof(titleId) ~= "string" or (titleId ~= "" and Titles.Get(titleId) == nil) then
		return { Success = false, Message = "Unknown title." }
	end
	local server = self.Server
	if server._equipDebounces[player.UserId] then
		return { Success = false, Message = "Please wait before switching again." }
	end
	server._equipDebounces[player.UserId] = true
	task.delay(1, function()
		server._equipDebounces[player.UserId] = nil
	end)

	local ok, proxy = Knit.GetService("DataService"):GetDataAsync(player):await()
	if not ok or proxy == nil then
		return { Success = false, Message = "Your titles are still loading." }
	end
	local data = server:_ensureTitles(player, proxy)
	if titleId ~= "" and not Titles.CanEquip(data, titleId) then
		return { Success = false, Message = "You haven't earned that title yet." }
	end
	if data.Equipped ~= titleId then
		data.Equipped = titleId
		proxy:SetValue({ "Titles" }, data)
		setEquippedTitleAttribute(player, data)
	end
	local msg = if titleId == "" then "Title unequipped." else "Title equipped."
	return { Success = true, Message = msg }
end

-- Adds XP, levels up while the curve allows. Safe to call at any time.
-- Returns the XP actually granted (boost included).
function ProgressionService:AddXp(player: Player, amount: number, skipShiftCount: boolean?): number
	if amount <= 0 then
		return 0
	end
	-- Pass XP boost applies to all play XP, highest wins (DEC-036 B2/B3).
	amount = math.round(amount * (1 + self:_getXpBonus(player)))
	local data = Knit.GetService("DataService")
	data:GetDataAsync(player)
		:andThen(function(proxy)
			if typeof(player) == "Instance" and not player:IsDescendantOf(Players) then
				return
			end
			local state = self._state[player]
			if state == nil then
				state = { Level = proxy.Data.Level or 1, XP = proxy.Data.XP or 0 }
				self._state[player] = state
			end
			if not skipShiftCount then
				self._shiftXp[player] = (self._shiftXp[player] or 0) + amount
			end

			state.XP += amount
			local gained: { number } = {}
			while state.Level < Progression.MAX_LEVEL and state.XP >= Progression.XpToNext(state.Level) do
				state.XP -= Progression.XpToNext(state.Level)
				state.Level += 1
				table.insert(gained, state.Level)
			end
			if state.Level >= Progression.MAX_LEVEL then
				state.XP = 0
			end
			proxy:SetValue({ "XP" }, state.XP)
			if #gained > 0 then
				proxy:SetValue({ "Level" }, state.Level)
				setAttributes(player, state.Level)
				for _, level in gained do
					self:_onLevelUp(player, level, proxy)
				end
			end
		end)
		:catch(function(err)
			warn(`[ProgressionService] AddXp failed: {err}`)
		end)
	return amount
end

function ProgressionService:_getXpBonus(player: Player): number
	local ok, bonus = pcall(function()
		return Knit.GetService("PerkService"):GetFamilyBonus(player, "Xp")
	end)
	return if ok and typeof(bonus) == "number" then bonus else 0
end

function ProgressionService:_onLevelUp(player: Player, level: number, proxy: any)
	local ok, err = pcall(function()
		local titles = self:_ensureTitles(player, proxy)
		-- TAKEOVER-REVIEW-FIX P3-5: the overhead follows level-ups again. Only a player still wearing the previous
		-- highest level title moves up; a manual title, an older pick or an unequip is left alone.
		local previousBest = Titles.HighestLevelTitleId(level - 1)
		local newBest = Titles.HighestLevelTitleId(level)
		if
			titles.Equipped ~= ""
			and titles.Equipped == previousBest
			and newBest ~= previousBest
			and titles.Owned[newBest]
		then
			titles.Equipped = newBest
			proxy:SetValue({ "Titles" }, titles)
			setEquippedTitleAttribute(player, titles)
		end
		local reward = Progression.COSMETIC_REWARDS[level]
		if reward ~= nil then
			task.spawn(function()
				local Inventory = require(Shared.Inventory)
				local okInv, inv = Inventory:GetPlayerInventoryAsync(player, reward.ItemType):await()
				if okInv and inv then
					inv:Insert({
						Name = reward.Name,
						Tier = reward.Tier,
						Properties = {},
					})
				else
					proxy:SetValue({ "Inventory", "Items", reward.ItemType, HttpService:GenerateGUID(false) }, {
						Name = reward.Name,
						Tier = reward.Tier,
						Equipped = false,
						Properties = {},
					})
				end
			end)
		end
		local text = ProgressionService.LevelUpText(level)
		Knit.GetService("DialogService"):Notify(player, { Text = text, SoundEnabled = true } :: any)
		ProgressionService.Client.LeveledUp:Fire(player, {
			Level = level,
			Title = Progression.TitleFor(level),
			Unlocks = unlocksAt(level),
		})
		pcall(function()
			local a = Knit.GetService("AnalyticsEvents")
			if level == 2 then
				a:OnboardingFunnel(player, 8, "FirstLevelUp")
				a:Funnel(player, 8, "FirstLevelUp")
			end
			a:ProgressionComplete(player, "CareerLevel", level, Progression.TitleFor(level))
		end)
	end)
	if not ok then
		warn(`[ProgressionService] Level-up step failed: {err}`)
	end
end

-- Grants the shift XP and fills the card fields (Xp, LevelBefore, LevelAfter, XpIntoLevel,
-- XpForLevel, NextUnlock). AddXp can apply synchronously when the profile is already loaded,
-- so the prediction starts from a snapshot taken before it (REVIEW-FIX P2-1).
function ProgressionService:_applyShiftXp(player: Player, summary: any)
	local levelBefore = self:GetLevel(player)
	local shiftXp = ShiftConfig.SHIFT_XP + ShiftConfig.SHIFT_XP_PER_STAR * summary.Stars
	local earned = self._shiftXp[player] or 0 -- serve XP, already boosted
	self._shiftXp[player] = 0
	local cached = self._state[player]
	local snapshot = if cached ~= nil then { Level = cached.Level, XP = cached.XP } else nil
	local granted = self:AddXp(player, shiftXp, true)
	summary.Xp = earned + granted
	summary.LevelBefore = levelBefore
	summary.LevelAfter = levelBefore

	local after, into
	if snapshot ~= nil then
		after, into = ProgressionService.Predict(snapshot.Level, snapshot.XP, granted)
	else
		-- No cache before AddXp: whatever is cached now already includes `granted` (or it is still loading).
		local state = self._state[player]
		if state == nil then
			return
		end
		after, into = state.Level, state.XP
	end
	summary.LevelAfter = after
	if after < Progression.MAX_LEVEL then
		summary.XpIntoLevel = math.floor(into)
		summary.XpForLevel = Progression.XpToNext(after)
	end
	summary.NextUnlock = nextUnlock(after)
end

---> lifecycle

function ProgressionService:KnitStart()
	local customers = Knit.GetService("CustomerService")
	customers.CustomerResolved:Connect(function(player, result)
		local ok, err = pcall(function()
			if result.Kind ~= "Served" then
				return
			end
			local items = result.Items or 1
			local xp = Progression.XP_PER_ITEM * items
			if result.Grade == "Perfect" then
				xp += Progression.XP_PERFECT
			end
			if result.Fast then
				xp += Progression.XP_FAST
			end
			self:AddXp(player, xp)
		end)
		if not ok then
			warn(`[ProgressionService] Serve XP failed: {err}`)
		end
	end)

	Knit.GetService("ShiftService").ShiftEnding:Connect(function(player, summary)
		local ok, err = pcall(function()
			self:_applyShiftXp(player, summary)
		end)
		if not ok then
			warn(`[ProgressionService] Shift XP failed: {err}`)
		end
	end)
end

function ProgressionService:PlayerAdded(player: Player)
	Knit.GetService("DataService"):GetDataAsync(player):andThen(function(proxy)
		local state = { Level = proxy.Data.Level or 1, XP = proxy.Data.XP or 0 }
		self._state[player] = state
		setAttributes(player, state.Level)
		self:_ensureTitles(player, proxy)
		self:_checkCriteriaTitlesAsync(player, proxy)
	end)
end

function ProgressionService:PlayerRemoving(player: Player)
	self._state[player] = nil
	self._shiftXp[player] = nil
	self._equipDebounces[player.UserId] = nil
end

return ProgressionService

--!strict
--[[
	ProgressionService
	XP and levels 1-50 (REVIVAL-001 M2-PROGRESS). Serving earns XP, level-ups
	grant a nametag every 5 levels and show a toast. Nothing is locked.

	Player attributes: Level (number), LevelTitle (string).
	A failure here warns and never blocks serving.
--]]

---> services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local Progression = require(Shared.Configuration.Progression)
local ShiftConfig = require(Shared.Configuration.ShiftConfig)

---> service declaration
local ProgressionService = Knit.CreateService({
	Name = "ProgressionService",

	_state = {} :: { [Player]: { Level: number, XP: number } }, -- cache; the profile is written on every change
	_shiftXp = {} :: { [Player]: number }, -- XP gained since the last ShiftEnding
})

local function setAttributes(player: Player, level: number)
	pcall(function()
		player:SetAttribute("Level", level)
		player:SetAttribute("LevelTitle", Progression.TitleFor(level))
	end)
end

---> public

function ProgressionService:GetLevel(player: Player): number
	local level = player:GetAttribute("Level")
	return if typeof(level) == "number" then level else 1
end

-- Adds XP, levels up while the curve allows. Safe to call at any time.
function ProgressionService:AddXp(player: Player, amount: number, skipShiftCount: boolean?)
	if amount <= 0 then
		return
	end
	local data = Knit.GetService("DataService")
	data:GetDataAsync(player)
		:andThen(function(proxy)
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
end

function ProgressionService:_onLevelUp(player: Player, level: number, proxy: any)
	local ok, err = pcall(function()
		local reward = Progression.COSMETIC_REWARDS[level]
		if reward ~= nil then
			proxy:SetValue({ "Inventory", "Items", reward.ItemType, HttpService:GenerateGUID(false) }, {
				Name = reward.Name,
				Tier = reward.Tier,
				Equipped = false,
				Properties = {},
			})
		end
		local text = `Level up! You are now level {level}`
		if reward ~= nil then
			text ..= ` · New nametag: {reward.Name}`
		end
		Knit.GetService("DialogService"):Notify(player, { Text = text, SoundEnabled = true } :: any)
	end)
	if not ok then
		warn(`[ProgressionService] Level-up step failed: {err}`)
	end
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
			local levelBefore = self:GetLevel(player)
			local shiftXp = ShiftConfig.SHIFT_XP + ShiftConfig.SHIFT_XP_PER_STAR * summary.Stars
			local total = (self._shiftXp[player] or 0) + shiftXp
			self._shiftXp[player] = 0
			self:AddXp(player, shiftXp, true)
			summary.Xp = total
			summary.LevelBefore = levelBefore
			-- AddXp finishes after the profile loads; predict from the cache for the card.
			local state = self._state[player]
			local after = levelBefore
			if state ~= nil then
				local xp = state.XP + shiftXp
				after = state.Level
				while after < Progression.MAX_LEVEL and xp >= Progression.XpToNext(after) do
					xp -= Progression.XpToNext(after)
					after += 1
				end
			end
			summary.LevelAfter = after
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
	end)
end

function ProgressionService:PlayerRemoving(player: Player)
	self._state[player] = nil
	self._shiftXp[player] = nil
end

return ProgressionService

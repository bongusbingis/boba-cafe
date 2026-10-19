--!strict
--[[
    Module: ShiftService
    Description: Server-owned "clocked in" state. A clocked-in player works as a
                 barista (kitchen stations, claiming and queueing for orders); a
                 clocked-out player is a customer. Anyone may clock in or out at any
                 time. The state lives on the player as the `ClockedIn` attribute so
                 the client HUD and Teams.server.luau can read it.
--]]

---> services

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

---> dependencies

local Knit = require(Packages.Knit)
local GoodSignal = require(Packages.GoodSignal)
local ShiftConfig = require(ReplicatedStorage.Shared.Configuration.ShiftConfig)

---> types

export type CustomerResult = {
	Kind: string,
	Grade: string?,
	Pay: number,
	Fast: boolean,
	Combo: number,
}

export type ShiftState = {
	Resolved: number,
	Target: number,
	Served: number,
	Walkouts: number,
	Perfects: number,
	Pay: number,
	BestCombo: number,
	Completed: number, -- shifts completed before this one (profile stat)
	Loaded: boolean, -- Target has been read from the profile
}

export type SetClockedInResult = {
	Success: boolean,
	Message: string?,
}

---> constants

local CLOCKED_IN_ATTRIBUTE = "ClockedIn"
local DEFAULT_CLOCKED_IN = true -- new players start as baristas
local TOGGLE_COOLDOWN_SECONDS = 2
local READ_TIMEOUT_SECONDS = 5
local COUNT_ATTRIBUTE = "ShiftCount"
local TARGET_ATTRIBUTE = "ShiftTarget"

---> service

local ShiftService = Knit.CreateService({
	Name = "ShiftService",
	Client = {
		-- Fires (summary) to the barista when a shift ends. Summary shape: see _endShift.
		ShiftEnded = Knit.CreateSignal(),
	},

	-- Server-side signal: fires (player: Player, clockedIn: boolean) after a change.
	ClockedInChanged = GoodSignal.new(),

	-- Server-side signal: fires (player, summary) BEFORE the client is told. Listeners may
	-- add Xp, LevelBefore and LevelAfter to the summary table.
	ShiftEnding = GoodSignal.new(),

	_toggleDebounces = {} :: { [number]: boolean },
	_states = {} :: { [Player]: ShiftState },
	_customers = nil :: any,
})

---> private

-- 3 stars: no walkouts and at least 80% Perfect. 2 stars: at most 1 walkout and at
-- least 50% Perfect. Otherwise 1 (design 5.2). `served` counts Perfect and Close.
function ShiftService.StarsFor(served: number, perfects: number, walkouts: number): number
	local ratio = if served > 0 then perfects / served else 0
	if walkouts == 0 and ratio >= 0.8 then
		return 3
	end
	if walkouts <= 1 and ratio >= 0.5 then
		return 2
	end
	return 1
end

local function newState(target: number, completed: number, loaded: boolean): ShiftState
	return {
		Resolved = 0,
		Target = target,
		Served = 0,
		Walkouts = 0,
		Perfects = 0,
		Pay = 0,
		BestCombo = 0,
		Completed = completed,
		Loaded = loaded,
	}
end

function ShiftService:_publish(player: Player, state: ShiftState?)
	if state ~= nil and state.Loaded then
		player:SetAttribute(COUNT_ATTRIBUTE, state.Resolved)
		player:SetAttribute(TARGET_ATTRIBUTE, state.Target)
	else
		player:SetAttribute(COUNT_ATTRIBUTE, nil)
		player:SetAttribute(TARGET_ATTRIBUTE, nil)
	end
end

-- Reads Statistics.ShiftsCompleted the way CustomerService reads CustomersServed.
-- Missing data means a normal-size shift.
function ShiftService:_readCompleted(player: Player): number?
	local data = Knit.GetService("DataService")
	local pcallOk, awaitOk, profile = pcall(function()
		return data:GetDataAsync(player):timeout(READ_TIMEOUT_SECONDS):await()
	end)
	if pcallOk and awaitOk and typeof(profile) == "table" then
		local stats = (profile :: any).Statistics
		if typeof(stats) == "table" and typeof(stats.ShiftsCompleted) == "number" then
			return stats.ShiftsCompleted
		end
	end
	warn(`[ShiftService] Could not read ShiftsCompleted for {player.Name}; using a normal shift.`)
	return nil
end

function ShiftService:_beginShift(player: Player)
	local state = newState(ShiftConfig.SHIFT_SIZE, 1, false)
	self._states[player] = state
	task.spawn(function()
		local ok, err = pcall(function()
			local completed = self:_readCompleted(player)
			if self._states[player] ~= state then
				return -- clocked out or left while reading
			end
			if completed ~= nil then
				state.Completed = completed
				if completed == 0 then
					state.Target = ShiftConfig.FIRST_SHIFT_SIZE
				end
			end
			state.Loaded = true
			self:_publish(player, state)
			self:_checkEnd(player, state)
		end)
		if not ok then
			warn(`[ShiftService] Begin shift failed: {err}`)
		end
	end)
end

function ShiftService:_checkEnd(player: Player, state: ShiftState)
	if not state.Loaded or state.Resolved < state.Target then
		return
	end
	local customers = self._customers
	if customers ~= nil and customers:HasTicket(player) then
		return -- wait: the next CustomerResolved re-checks
	end
	self:_endShift(player, state)
end

function ShiftService:_endShift(player: Player, state: ShiftState)
	local stars = ShiftService.StarsFor(state.Served, state.Perfects, state.Walkouts)
	local first = state.Completed == 0
	local bonus = stars * ShiftConfig.SHIFT_BONUS_PER_STAR
	-- Summary shape (PROGRESS depends on it). Xp, LevelBefore and LevelAfter are added
	-- by ProgressionService from the ShiftEnding signal and may be nil.
	local summary = {
		Shift = state.Completed + 1,
		Stars = stars,
		Served = state.Served,
		Walkouts = state.Walkouts,
		Pay = state.Pay,
		Tips = 0,
		Bonus = bonus,
		BestCombo = state.BestCombo,
		First = first,
		Seconds = if first then ShiftConfig.CARD_SECONDS_FIRST else ShiftConfig.CARD_SECONDS_LATER,
		Xp = nil :: number?,
		LevelBefore = nil :: number?,
		LevelAfter = nil :: number?,
	}

	-- Reset first so a failure below never leaves the shift stuck.
	self._states[player] = newState(ShiftConfig.SHIFT_SIZE, state.Completed + 1, true)
	self:_publish(player, self._states[player])

	pcall(function()
		self.ShiftEnding:Fire(player, summary)
	end)
	if bonus > 0 then
		pcall(function()
			Knit.GetService("CurrencyService"):Modify(player, "BobaBucks", bonus, "Gameplay")
		end)
	end
	pcall(function()
		Knit.GetService("StatisticsService"):IncrementStat(player, "ShiftsCompleted")
	end)
	pcall(function()
		Knit.GetService("QuestService"):AdvanceQuest(player, "ShiftsCompleted", 1)
	end)
	self.Client.ShiftEnded:Fire(player, summary)
end

---> public

function ShiftService:IsClockedIn(player: Player): boolean
	return player:GetAttribute(CLOCKED_IN_ATTRIBUTE) == true
end

-- Server-authoritative setter. Does not rate-limit; use the Client method for
-- player requests.
function ShiftService:SetClockedIn(player: Player, clockedIn: boolean)
	if player:GetAttribute(CLOCKED_IN_ATTRIBUTE) == clockedIn then
		return
	end
	player:SetAttribute(CLOCKED_IN_ATTRIBUTE, clockedIn)
	if clockedIn then
		self:_beginShift(player)
	else
		-- Shift paused, nothing banked (pay is already banked per serve).
		self._states[player] = nil
		self:_publish(player, nil)
	end
	self.ClockedInChanged:Fire(player, clockedIn)
	if clockedIn then
		pcall(function()
			Knit.GetService("AnalyticsEvents"):Funnel(player, 2, "ClockedIn")
		end)
	end
end

-- Records one resolved customer for the barista and ends the shift when due.
function ShiftService:RecordCustomer(player: Player, result: CustomerResult)
	local state = self._states[player]
	if state == nil then
		return
	end
	state.Resolved += 1
	if result.Kind == "Served" then
		state.Served += 1
		if result.Grade == "Perfect" then
			state.Perfects += 1
		end
		state.Pay += result.Pay
		state.BestCombo = math.max(state.BestCombo, result.Combo)
	else
		state.Walkouts += 1
	end
	self:_publish(player, state)
	self:_checkEnd(player, state)
end

---> client

function ShiftService.Client:SetClockedIn(player: Player, clockedIn: any): SetClockedInResult
	if typeof(clockedIn) ~= "boolean" then
		return { Success = false, Message = "Invalid request." }
	end

	local server = self.Server
	if server._toggleDebounces[player.UserId] then
		return { Success = false, Message = "Please wait before switching again." }
	end

	server._toggleDebounces[player.UserId] = true
	task.delay(TOGGLE_COOLDOWN_SECONDS, function()
		server._toggleDebounces[player.UserId] = nil
	end)

	server:SetClockedIn(player, clockedIn)
	return { Success = true, Message = if clockedIn then "Clocked in." else "Clocked out." }
end

---> lifecycle

function ShiftService:PlayerAdded(player: Player)
	-- Respect a value that is already set (for example by a Studio test).
	if player:GetAttribute(CLOCKED_IN_ATTRIBUTE) == nil then
		self:SetClockedIn(player, DEFAULT_CLOCKED_IN)
	end
end

function ShiftService:KnitStart()
	local customers = Knit.GetService("CustomerService")
	self._customers = customers
	customers.CustomerResolved:Connect(function(p, r)
		local ok, err = pcall(function()
			self:RecordCustomer(p, r)
		end)
		if not ok then
			warn(`[ShiftService] RecordCustomer failed: {err}`)
		end
	end)
end

function ShiftService:PlayerRemoving(player: Player)
	self._states[player] = nil
	self._toggleDebounces[player.UserId] = nil
end

return ShiftService

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
local InventoryItemDefinitions = require(ReplicatedStorage.Shared.Configuration.InventoryItemDefinitions)

---> types

export type CustomerResult = {
	Kind: string,
	Grade: string?,
	Pay: number,
	Fast: boolean,
	Combo: number,
	Tip: number?, -- extra BB from the pass/pet tip boost, already inside Pay
}

export type ShiftState = {
	Resolved: number,
	Target: number,
	Served: number,
	Walkouts: number,
	Perfects: number,
	Pay: number,
	Tips: number, -- boost BB earned this shift (part of Pay)
	BestCombo: number,
	Completed: number, -- shifts completed before this one (profile stat)
	Loaded: boolean, -- Target has been read from the profile
	PrevBestCombo: number?, -- stored personal bests before this shift (nil = unknown)
	PrevBestShiftPay: number?,
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
local NUDGE_TEXT = "You can afford a capsule! Check the Shop."
local NUDGE_DELAY_SECONDS = 1.5 -- lets the star bonus land before the balance is read
local NUDGE_POLL_SECONDS = 1
local NUDGE_NICK_WAIT_SECONDS = 160 -- covers the card plus the 120 s nickname prompt timeout
local NUDGE_DRAIN_SECONDS = 1
local NEW_BEST_MIN_COMBO = 2
local CARD_OPEN_ATTRIBUTE = "ShiftCardOpen"
local NICK_PENDING_ATTRIBUTE = "NicknamePending"

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
	_paused = {} :: { [Player]: ShiftState }, -- loaded shift kept across a clock out (session only)
	_customers = nil :: any,
	_capsuleNudged = {} :: { [Player]: boolean },
	_streaks = {} :: { [Player]: number }, -- session-only consecutive shifts completed
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
		Tips = 0,
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

-- Stored personal bests (BestCombo, BestShiftPay); nil when unreadable.
function ShiftService:_readBests(player: Player): (number?, number?)
	local data = Knit.GetService("DataService")
	local pcallOk, awaitOk, profile = pcall(function()
		return data:GetDataAsync(player):timeout(READ_TIMEOUT_SECONDS):await()
	end)
	if pcallOk and awaitOk and typeof(profile) == "table" then
		local combo = (profile :: any).BestCombo
		local pay = (profile :: any).BestShiftPay
		return if typeof(combo) == "number" then combo else nil, if typeof(pay) == "number" then pay else nil
	end
	warn(`[ShiftService] Could not read personal bests for {player.Name}; no new-best lines.`)
	return nil, nil
end

-- Lowest capsule price from the definitions (Price strings such as " 75"); nil when none parse.
function ShiftService.CheapestCapsulePrice(): number?
	local cheapest: number? = nil
	for _, capsule in pairs(InventoryItemDefinitions.Capsules :: any) do
		if typeof(capsule) == "table" and typeof(capsule.Price) == "string" then
			local price = tonumber((capsule.Price:gsub("%s", "")))
			if price ~= nil and price > 0 and (cheapest == nil or price < cheapest) then
				cheapest = price
			end
		end
	end
	return cheapest
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
			local bestCombo, bestPay = self:_readBests(player)
			if self._states[player] ~= state then
				return
			end
			state.PrevBestCombo = bestCombo
			state.PrevBestShiftPay = bestPay
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
		Pay = state.Pay - state.Tips, -- base pay; Tips is the boost extra (DEC-036 B1)
		Tips = state.Tips,
		Bonus = bonus,
		BestCombo = state.BestCombo,
		First = first,
		NewBestCombo = false,
		NewBestShiftPay = false,
		Seconds = if first then ShiftConfig.CARD_SECONDS_FIRST else ShiftConfig.CARD_SECONDS_LATER,
		Xp = nil :: number?,
		LevelBefore = nil :: number?,
		LevelAfter = nil :: number?,
	}

	-- New-best flags need a stored best above 0, so a first-ever shift never shows them.
	local prevCombo, prevPay = state.PrevBestCombo, state.PrevBestShiftPay
	if prevCombo ~= nil and prevCombo > 0 and state.BestCombo >= NEW_BEST_MIN_COMBO and state.BestCombo > prevCombo then
		summary.NewBestCombo = true
	end
	if prevPay ~= nil and prevPay > 0 and state.Pay > prevPay then
		summary.NewBestShiftPay = true
	end

	-- Reset first so a failure below never leaves the shift stuck.
	local nextState = newState(ShiftConfig.SHIFT_SIZE, state.Completed + 1, true)
	if prevCombo ~= nil then
		nextState.PrevBestCombo = math.max(prevCombo, state.BestCombo)
	end
	if prevPay ~= nil then
		nextState.PrevBestShiftPay = math.max(prevPay, state.Pay)
	end
	self._states[player] = nextState
	self:_publish(player, self._states[player])

	pcall(function()
		self.ShiftEnding:Fire(player, summary)
	end)
	if bonus > 0 then
		pcall(function()
			Knit.GetService("CurrencyService"):Modify(player, "BobaBucks", bonus, "Gameplay")
		end)
	end
	-- Session streak (H6-STREAK, PROPOSED): consecutive shifts completed this session.
	-- No clean server-side chest grant exists (TreasureHuntService only grants via a
	-- physical ClaimChest with distance/cooldown/badge side effects), so every
	-- STREAK_LENGTH-th shift end grants the chest's average BB value instead.
	-- TAKEOVER-REVIEW-FIX P3-9: a shift with no serve (all walkouts) breaks the streak instead of advancing it.
	local streak = if state.Served > 0 then (self._streaks[player] or 0) + 1 else 0
	self._streaks[player] = streak
	local streakBonus = 0
	if streak % ShiftConfig.STREAK_LENGTH == 0 then
		streakBonus = ShiftConfig.STREAK_BONUS_BB
	end
	summary.ShiftStreak = streak
	summary.StreakBonus = streakBonus
	if streakBonus > 0 then
		pcall(function()
			Knit.GetService("CurrencyService"):Modify(player, "BobaBucks", streakBonus, "ShiftStreak")
		end)
	end
	pcall(function()
		Knit.GetService("StatisticsService"):IncrementStat(player, "ShiftsCompleted")
	end)
	-- Spawned: AdvanceQuest awaits the profile (and a pass lookup on rollover); the card must not wait.
	task.spawn(function()
		pcall(function()
			Knit.GetService("QuestService"):AdvanceQuest(player, "ShiftsCompleted", 1)
		end)
	end)
	-- Card-open flag for the nickname prompt (ONBOARD-NICK); the card is client-timed.
	pcall(function()
		player:SetAttribute(CARD_OPEN_ATTRIBUTE, true)
		task.delay(summary.Seconds, function()
			pcall(function()
				if player.Parent ~= nil then
					player:SetAttribute(CARD_OPEN_ATTRIBUTE, nil)
				end
			end)
		end)
	end)
	self.Client.ShiftEnded:Fire(player, summary)

	-- After the card is sent: monotonic best writes, then the capsule nudge.
	local bestCombo, bestPay = state.BestCombo, state.Pay
	task.spawn(function()
		pcall(function()
			self:_writeBests(player, bestCombo, bestPay)
		end)
	end)
	task.spawn(function()
		pcall(function()
			self:_capsuleNudge(player)
		end)
	end)
end

-- Raises the stored bests; never lowers them.
function ShiftService:_writeBests(player: Player, combo: number, pay: number)
	local ok, awaitOk, proxy = pcall(function()
		return Knit.GetService("DataService"):GetDataAsync(player):timeout(READ_TIMEOUT_SECONDS):await()
	end)
	if not ok or not awaitOk or typeof(proxy) ~= "table" then
		return
	end
	local data: any = proxy
	if combo >= NEW_BEST_MIN_COMBO and combo > (tonumber(data.BestCombo) or 0) then
		data:SetValue({ "BestCombo" }, combo)
	end
	if pay > (tonumber(data.BestShiftPay) or 0) then
		data:SetValue({ "BestShiftPay" }, pay)
	end
end

-- One capsule-affordable toast per session, after the nickname prompt (if any) has closed.
function ShiftService:_capsuleNudge(player: Player)
	if self._capsuleNudged[player] then
		return
	end
	local price = ShiftService.CheapestCapsulePrice()
	if price == nil then
		return
	end
	task.wait(NUDGE_DELAY_SECONDS)
	local waited = 0
	while player:GetAttribute(NICK_PENDING_ATTRIBUTE) == true and waited < NUDGE_NICK_WAIT_SECONDS do
		task.wait(NUDGE_POLL_SECONDS)
		waited += NUDGE_POLL_SECONDS
	end
	if player:GetAttribute(NICK_PENDING_ATTRIBUTE) == true then
		return -- still choosing a nickname: never toast under the prompt; the next shift end tries again
	end
	task.wait(NUDGE_DRAIN_SECONDS)
	if player.Parent == nil or self._capsuleNudged[player] or not self:IsClockedIn(player) then
		return
	end
	local ok, awaitOk, proxy = pcall(function()
		return Knit.GetService("DataService"):GetDataAsync(player):timeout(READ_TIMEOUT_SECONDS):await()
	end)
	if not ok or not awaitOk or typeof(proxy) ~= "table" then
		return
	end
	local currency = (proxy :: any).Currency
	local bucks = if typeof(currency) == "table" then currency.BobaBucks else nil
	if typeof(bucks) ~= "number" or bucks < price then
		return
	end
	self._capsuleNudged[player] = true
	Knit.GetService("DialogService"):Notify(player, { Text = NUDGE_TEXT } :: any)
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
		local paused = self._paused[player]
		self._paused[player] = nil
		if paused ~= nil and paused.Loaded then
			-- Resume where the barista left off (progress, stars and bests intact).
			self._states[player] = paused
			self:_publish(player, paused)
		else
			self:_beginShift(player)
		end
	else
		-- Shift paused, not reset: the state waits for the next clock in this session.
		self._paused[player] = self._states[player]
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
		state.Tips += math.floor(result.Tip or 0)
		state.BestCombo = math.max(state.BestCombo, result.Combo)
	else
		state.Walkouts += 1
	end
	self:_publish(player, state)
	self:_checkEnd(player, state)
end

-- Adds boost BB from a real-player order, which has no CustomerResolved. The BB is
-- already paid; this only feeds the summary Tips line.
function ShiftService:AddTip(player: Player, amount: number)
	local state = self._states[player]
	if state == nil or amount <= 0 then
		return
	end
	local tip = math.floor(amount)
	state.Tips += tip
	state.Pay += tip
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
	self._paused[player] = nil
	self._toggleDebounces[player.UserId] = nil
	self._capsuleNudged[player] = nil
	self._streaks[player] = nil
end

return ShiftService

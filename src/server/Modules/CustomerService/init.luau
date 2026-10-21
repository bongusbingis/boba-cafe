--!strict
--[[
	Module: CustomerService
	Description: NPC customers (REVIVAL-001 M1.4core). Spawns NPCs at the authored
	             Entry, walks them along Path into the Queue and on to a free Counter
	             spot, lets their patience run down, then sends them out through Exit.
	             The number of NPCs follows the number of clocked-in baristas
	             (Rules.PacingTarget). Each NPC is given one order from the slice
	             pool and shows it in a bubble above its head.

	World contract (authored in the place, resolved in KnitStart; the service
	disables itself with one warning when it is missing):
	  workspace.Assets.NPC.Entry    BasePart, where NPCs spawn
	  workspace.Assets.NPC.Exit     BasePart, where they leave
	  workspace.Assets.NPC.Path     Folder of BaseParts named 1..n, walked in order
	  workspace.Assets.NPC.Queue    BaseParts named 1..k, 1 is the front of the line
	  workspace.Assets.NPC.Counter  BaseParts named 1..m, facing the kitchen

	API for the later serve and assignment work:
	  CustomerService:GetWaitingCustomers()  NPCs standing at a counter spot, by spot
	  CustomerService.CustomerLeft           GoodSignal (npc, reason); once per NPC when
	                                         it stops waiting: "PatienceOut" or "Despawned"
	  CustomerService.Enabled                false when the world contract is missing

	NPC fields other code may read: Model, Order, Spec, State, PatienceTotal,
	CounterSpot. The model's PatienceEnd attribute is server time.

	Assignment and Rescue (Q1), Serve at the NPC (Q2), the first-session script (Q4)
	and payout (Q5/Q6) are built (M1.4e). Still PENDING JACK: Q25 the NPC look.
--]]

---> services

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies

local Knit = require(Packages.Knit)
local GoodSignal = require(Packages.GoodSignal)
local CustomerConfig = require(Shared.Configuration.CustomerConfig)
local RatingConfig = require(Shared.Configuration.RatingConfig)
local SeatingConfig = require(Shared.Configuration.SeatingConfig)
local TeamComboConfig = require(Shared.Configuration.TeamComboConfig)
local Progression = require(Shared.Configuration.Progression)
local OrderSpec = require(Shared.Ordering.OrderSpec)
local WorldPath = require(Shared.Utility.WorldPath)
local Npc = require(script.Npc)
local Rules = require(script.Rules)
local Seats = require(script.Seats)
local Styles = require(Shared.UI.Styles)

---> constants

local WORLD_WAIT_SECONDS = 10 -- total budget for resolving the authored world in KnitStart
local PACING_TICK_SECONDS = 1
local COMBO_MILESTONES = { [3] = true, [5] = true, [10] = true } -- TUNING: combo values that get a callout toast
local TEAM_PROGRESS_FROM = 5 -- TUNING: show Team N/10 on the serve toast from this chain length
local SERVED_COUNT_TIMEOUT_SECONDS = 5 -- budget for reading Statistics.CustomersServed
local CUSTOMERS_FOLDER_NAME = "Customers"
-- Players get their own group so NPCs can pass through them. NPCs still collide
-- with the Default group (the floor and walls).
local PLAYER_COLLISION_GROUP = "CafePlayers"

---> private

local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(message)
	end
end

-- Like warnOnce, but repeats at most once per WARN_THROTTLE_SECONDS, so a fault that
-- persists stays visible in the log without flooding it.
local WARN_THROTTLE_SECONDS = 60
local lastWarned: { [string]: number } = {}

local function warnThrottled(key: string, message: string)
	local now = os.clock()
	local last = lastWarned[key]
	if last == nil or now - last >= WARN_THROTTLE_SECONDS then
		lastWarned[key] = now
		warn(message)
	end
end

-- The BaseParts of `folder` named with numbers, in numeric order.
local function numberedParts(folder: Instance?): { BasePart }
	local found: { { Number: number, Part: BasePart } } = {}
	if folder ~= nil then
		for _, child in folder:GetChildren() do
			local number = tonumber(child.Name)
			if number ~= nil and child:IsA("BasePart") then
				table.insert(found, { Number = number, Part = child })
			end
		end
	end
	table.sort(found, function(a, b)
		return a.Number < b.Number
	end)

	local parts: { BasePart } = {}
	for _, entry in found do
		table.insert(parts, entry.Part)
	end
	return parts
end

local function ensureCollisionGroup(name: string)
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end

local function setCollisionGroup(root: Instance, group: string)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
end

---> service

local CustomerService = Knit.CreateService({
	Name = "CustomerService",
	Client = {
		-- The M1.4f contract: fires (player, ticket) on assignment and
		-- (player, nil) to clear (serve, walkout, reassignment). A 3rd argument is the
		-- ticket slot index (1, or 1-2 from level 5); ticket.Slot carries it too.
		TicketChanged = Knit.CreateSignal(),
		-- Fired to open the Ordering Tablet screen on the barista's client with NPC order data.
		OpenOrderingTablet = Knit.CreateSignal(),
	},

	-- Server-side signal: fires (npc: Npc.Npc, reason: string) once per NPC when it stops waiting.
	CustomerLeft = GoodSignal.new(),

	-- Server-side signal: fires (player, result) once per resolved customer for the barista.
	-- result = { Kind: "Served" | "Walkout", Grade: string?, Pay: number, Fast: boolean, Combo: number, Tip: number? }
	-- Tip = extra BB from the pass/pet tip boost, already included in Pay.
	CustomerResolved = GoodSignal.new(),

	--- True only after KnitStart found the whole world contract. When false nothing spawns.
	Enabled = false,

	_shift = nil :: any,
	_context = nil :: Npc.Context?,
	_npcs = {} :: { [Npc.Npc]: boolean },
	_npcCount = 0,
	_line = {} :: { Npc.Npc }, -- NPCs waiting for a counter spot, front first
	_counter = {} :: { [number]: Npc.Npc }, -- counter spot -> the NPC that holds it
	_pickupNodes = {} :: { BasePart }, -- pickup spots from workspace["Ordering System"]["Pick Up"]
	_pickupHolders = {} :: { [BasePart]: Npc.Npc }, -- pickup spot -> the NPC that holds it
	_npcPickupSpot = {} :: { [Npc.Npc]: BasePart }, -- NPC -> claimed pickup spot
	_activeOrderingNpc = {} :: { [Player]: Npc.Npc }, -- barista -> NPC whose order is currently being taken
	_baristas = 0, -- clocked-in players, refreshed every pacing tick
	_lastSpawnClock = 0,
	_characterConnections = {} :: { [Player]: RBXScriptConnection },
	_tickets = {} :: { [Player]: { [number]: { [string]: any } } }, -- barista -> slot -> live ticket (at most Progression.SlotsFor(level))
	_assignee = {} :: { [Npc.Npc]: Player }, -- NPC -> the barista holding its ticket
	_idleSince = {} :: { [Player]: number }, -- os.clock() at clock-in and at ticket clear
	_combo = {} :: { [Player]: number }, -- consecutive Perfect serves (session memory only)
	_sessionShifts = {} :: { [Player]: number }, -- shifts completed this session, memory only
	_lastOrder = {} :: { [Player]: Rules.OrderItem }, -- last order per barista (no repeats)
	_teamChain = 0, -- consecutive successful serves server-wide (session memory only)
	_firstServe = {} :: { [Player]: boolean }, -- barista -> served 0 customers when last assigned (session memory)
	_teamComboUntil = 0, -- os.clock() deadline of the active Team Combo (0 = none)
	_npcSeq = 0, -- makes ticket Ids unique per NPC
	_stressSeen = {} :: { [Npc.Npc]: number }, -- BIG-B4-P1: first-seen clock per unassigned counter NPC (Studio stress only)
	_seats = nil :: Seats.SeatsPool?,
	_order = nil :: any,
	_currency = nil :: any,
	_stats = nil :: any,
	_dialog = nil :: any,
	_data = nil :: any,
})

---> public

-- NPCs standing at a counter spot with their patience running, in spot order.
function CustomerService:GetWaitingCustomers(): { Npc.Npc }
	local waiting: { Npc.Npc } = {}
	local context = self._context
	if context == nil then
		return waiting
	end

	for spot = 1, #context.Nodes.Counter do
		local npc = self._counter[spot]
		if npc ~= nil and npc.State == "AtCounter" then
			table.insert(waiting, npc)
		end
	end
	return waiting
end

---> private

-- Resolves the world contract. Returns nil after one warning naming what is missing.
function CustomerService:_resolveNodes(): Npc.Nodes?
	local deadline = os.clock() + WORLD_WAIT_SECONDS
	local function find(name: string): Instance?
		return WorldPath.waitFor(workspace, { "Assets", "NPC", name }, deadline - os.clock())
	end

	local entry = find("Entry")
	local exit = find("Exit")
	local path = numberedParts(find("Path"))
	local queue = numberedParts(find("Queue"))
	local counter = numberedParts(find("Counter"))

	local missing: { string } = {}
	if entry == nil or not entry:IsA("BasePart") then
		table.insert(missing, "workspace.Assets.NPC.Entry (BasePart)")
	end
	if exit == nil or not exit:IsA("BasePart") then
		table.insert(missing, "workspace.Assets.NPC.Exit (BasePart)")
	end
	if #path == 0 then
		table.insert(missing, "workspace.Assets.NPC.Path (BaseParts named 1..n)")
	end
	if #queue == 0 then
		table.insert(missing, "workspace.Assets.NPC.Queue (BaseParts named 1..k)")
	end
	if #counter == 0 then
		table.insert(missing, "workspace.Assets.NPC.Counter (BaseParts named 1..m)")
	end

	if #missing > 0 or entry == nil or exit == nil then
		warn(`[CustomerService] NPC customers disabled; missing authored content: {table.concat(missing, ", ")}`)
		return nil
	end
	return {
		Entry = entry :: BasePart,
		Exit = exit :: BasePart,
		Path = path,
		Queue = queue,
		Counter = counter,
	}
end

-- NPCs get their own collision group that ignores players and other NPCs. Returns
-- false (after a warning) when the groups cannot be set up, since NPCs that block
-- the counter are worse than no NPCs.
function CustomerService:_setUpCollisionGroups(): boolean
	local ok, err = pcall(function()
		ensureCollisionGroup(Npc.COLLISION_GROUP)
		ensureCollisionGroup(PLAYER_COLLISION_GROUP)
		PhysicsService:CollisionGroupSetCollidable(Npc.COLLISION_GROUP, PLAYER_COLLISION_GROUP, false)
		PhysicsService:CollisionGroupSetCollidable(Npc.COLLISION_GROUP, Npc.COLLISION_GROUP, false)
		-- Players pass through each other so nobody body-blocks the counter.
		PhysicsService:CollisionGroupSetCollidable(PLAYER_COLLISION_GROUP, PLAYER_COLLISION_GROUP, false)
		-- Set explicitly: an authored NPC group that does not collide with Default would
		-- drop the NPCs through the floor.
		PhysicsService:CollisionGroupSetCollidable(Npc.COLLISION_GROUP, "Default", true)
	end)
	if not ok then
		warn(`[CustomerService] NPC customers disabled; collision groups failed: {err}`)
	end
	return ok
end

-- Keeps a player's character in the player collision group, including accessories and
-- tools added later.
function CustomerService:_watchPlayer(player: Player)
	if self._characterConnections[player] ~= nil then
		return
	end

	local function onCharacter(character: Model)
		setCollisionGroup(character, PLAYER_COLLISION_GROUP)
		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = PLAYER_COLLISION_GROUP
			end
		end)
	end

	self._characterConnections[player] = player.CharacterAdded:Connect(onCharacter)
	if player.Character ~= nil then
		onCharacter(player.Character)
	end
end

function CustomerService:_makeContext(nodes: Npc.Nodes, folder: Folder): Npc.Context
	return {
		Nodes = nodes,
		Parent = folder,
		QueueIndex = function(npc)
			return table.find(self._line, npc) or 1
		end,
		TryTakeCounter = function(npc)
			if self._line[1] ~= npc then
				return nil
			end
			for spot = 1, #nodes.Counter do
				if self._counter[spot] == nil then
					self._counter[spot] = npc
					table.remove(self._line, 1)
					return spot
				end
			end
			return nil
		end,
		Release = function(npc)
			local index = table.find(self._line, npc)
			if index ~= nil then
				table.remove(self._line, index)
			end
			for spot, holder in self._counter do
				if holder == npc then
					self._counter[spot] = nil
				end
			end
			local spot = self._npcPickupSpot[npc]
			if spot ~= nil then
				if self._pickupHolders[spot] == npc then
					self._pickupHolders[spot] = nil
				end
				self._npcPickupSpot[npc] = nil
			end
		end,
		ReleaseCounter = function(npc)
			for spot, holder in self._counter do
				if holder == npc then
					self._counter[spot] = nil
				end
			end
			npc.CounterSpot = nil
		end,
		ClaimPickupSpot = function(npc)
			for _, node in self._pickupNodes do
				if self._pickupHolders[node] == nil then
					self._pickupHolders[node] = npc
					self._npcPickupSpot[npc] = node
					return node
				end
			end
			local fallback = self._pickupNodes[1]
			if fallback ~= nil then
				self._npcPickupSpot[npc] = fallback
				return fallback
			end
			return nil
		end,
		ReleasePickupSpot = function(npc)
			local spot = self._npcPickupSpot[npc]
			if spot ~= nil then
				if self._pickupHolders[spot] == npc then
					self._pickupHolders[spot] = nil
				end
				self._npcPickupSpot[npc] = nil
			end
		end,
		IsPaused = function()
			return self._baristas == 0
		end,
		OnLeft = function(npc, reason)
			self.CustomerLeft:Fire(npc, reason)
		end,
		OnAtCounter = function(npc)
			self:_onAtCounter(npc)
		end,
		OnAtPickup = function(npc)
			self:_onAtPickup(npc)
		end,
		OnDestroyed = function(npc)
			if self._npcs[npc] then
				self._npcs[npc] = nil
				self._npcCount -= 1
			end
			if self._seats ~= nil then
				self._seats:Forget(npc.Id)
			end
		end,
		TryClaimSeat = function(npcId, originPos, maxDist)
			if self._seats == nil then
				return nil
			end
			return self._seats:TryClaim(npcId, originPos, maxDist)
		end,
		ReleaseSeat = function(seat, npcId)
			if self._seats ~= nil then
				self._seats:Release(seat, npcId)
			end
		end,
	}
end

function CustomerService:_countBaristas(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		if self._shift:IsClockedIn(player) then
			count += 1
		end
	end
	return count
end

-- Spawns one NPC when fewer are present than the pacing target, the line has room and
-- the spawn gap has passed. Yields while the NPC is built.
function CustomerService:_spawnIfNeeded()
	local context = self._context
	if context == nil then
		return
	end
	local activeCount = self._npcCount - (if self._seats ~= nil then self._seats:BudgetUsed() else 0)
	if activeCount >= self:_pacingTarget() then
		return
	end
	local maxLine = if self:IsRushHour() then (RatingConfig.RUSH_QUEUE_CAP or 35) else #context.Nodes.Queue
	if #self._line >= maxLine then
		return -- never spawn into a full queue
	end
	local gap = if self:IsRushHour()
		then (RatingConfig.RUSH_SPAWN_GAP_SECONDS or 0.2)
		else CustomerConfig.SPAWN_GAP_SECONDS
	if os.clock() - self._lastSpawnClock < gap then
		return
	end
	self._lastSpawnClock = os.clock()

	local order = Rules.PickOrder()
	local spec, reason = OrderSpec.FromOrderItem(order)
	if spec == nil then
		warnOnce(
			"order",
			`[CustomerService] Pool order rejected by OrderSpec ({reason}): {order.Category}/{order.Item}`
		)
		return
	end

	local variant = self:_rollVariant()
	local npc = Npc.new(context, order, spec, Rules.PatienceSeconds({ order }), variant)
	if npc == nil then
		return
	end
	self._npcs[npc] = true
	self._npcCount += 1
	table.insert(self._line, npc)
	npc:Start()
end

-- True while the server-wide Rush Hour runs (set by CafeRatingService).
function CustomerService:IsRushHour(): boolean
	return workspace:GetAttribute("RushHour") == true
end

-- BIG-B4-P1: true when seating is on (flag or Studio-only force). P2 calls it; P1 only adds it.
function CustomerService:_seatingOn(): boolean
	return SeatingConfig.ENABLED or (RunService:IsStudio() and workspace:GetAttribute("B4SeatingForce") == true)
end

-- BIG-B4-P1: Studio-only B4SeatBudgetOverride (number >= 0), else SEATED_BUDGET.
function CustomerService:_seatBudget(): number
	if RunService:IsStudio() then
		local override = workspace:GetAttribute("B4SeatBudgetOverride")
		if typeof(override) == "number" and override >= 0 then
			return override
		end
	end
	return SeatingConfig.SEATED_BUDGET
end

-- BIG-B4-P1: "Run" or "Drain" only in Studio when B4Stress says so; else nil.
function CustomerService:_stressMode(): string?
	if not RunService:IsStudio() then
		return nil
	end
	local mode = workspace:GetAttribute("B4Stress")
	if mode == "Run" then
		return "Run"
	elseif mode == "Drain" then
		return "Drain"
	end
	return nil
end

-- BIG-B4-P1: Studio perf-check hook (non-yielding). Run forces baristas and
-- auto-serves unassigned counter NPCs after STRESS_SERVE_AFTER_SECONDS (4 s);
-- Drain serves them immediately. Serves skip pay on purpose: Leave("Served")
-- fires CustomerLeft (not PatienceOut) and _onCustomerLeft only clears a
-- ticket that does not exist, so there is no payout, stats or quest change.
function CustomerService:_stressTick(mode: string)
	if not RunService:IsStudio() then
		return
	end
	if mode == "Run" then
		self._baristas = math.max(self._baristas, SeatingConfig.STRESS_BARISTAS)
	end
	local wait = if mode == "Drain" then 0 else SeatingConfig.STRESS_SERVE_AFTER_SECONDS
	local now = os.clock()
	for _, npc in self:GetWaitingCustomers() do
		if npc.AssignedUserId ~= nil then
			continue
		end
		if npc.Left then
			self._stressSeen[npc] = nil
			continue
		end
		local seen = self._stressSeen[npc]
		if seen == nil then
			self._stressSeen[npc] = now
			continue
		end
		if now - seen >= wait then
			self._stressSeen[npc] = nil
			npc:Leave("Served", "Perfect")
		end
	end
	for npc in self._stressSeen do
		if npc.Left then
			self._stressSeen[npc] = nil
		end
	end
	workspace:SetAttribute("B4NpcCount", self._npcCount)
	local seatBudgetUsed = if self._seats ~= nil then self._seats:BudgetUsed() else 0
	workspace:SetAttribute("B4SeatBudgetUsed", seatBudgetUsed)
	workspace:SetAttribute("B4SeatsReserved", seatBudgetUsed)
	workspace:SetAttribute("B4SeatEntries", 0)
	local existing = workspace:GetAttribute("B4SeatBudgetMax")
	local maxSoFar = if typeof(existing) == "number" then existing else 0
	workspace:SetAttribute("B4SeatBudgetMax", math.max(maxSoFar, 0))
end

-- Rules.PacingTarget, scaled by Rush Hour (x NPC mult, cap + bonus).
function CustomerService:_pacingTarget(): number
	local target = Rules.PacingTarget(self._baristas)
	if self:IsRushHour() or (self:_stressMode() == "Run" and workspace:GetAttribute("B4StressRush") == true) then
		local rushMin = RatingConfig.RUSH_MIN_TARGET or 25
		local rushScaled = math.max(rushMin, math.ceil(target * RatingConfig.RUSH_NPC_MULT))
		target = math.min(CustomerConfig.SERVER_CAP + RatingConfig.RUSH_CAP_BONUS, rushScaled)
	end
	return target
end

-- True while a Team Combo window is open (DEC-028 E23). A plain clock read: safe on the serve path.
function CustomerService:IsTeamComboActive(): boolean
	return os.clock() < self._teamComboUntil
end

-- `pay` with the Team Combo bonus applied while the window is open (x1.10 rounded).
function CustomerService:ApplyTeamCombo(pay: number): number
	return Rules.TeamComboPay(pay, self:IsTeamComboActive(), TeamComboConfig.PAY_BONUS)
end

-- Tells every player something about the combo, through the same Notify path as Rush Hour.
-- Deferred so a serve never waits on it.
function CustomerService:_notifyTeamCombo(text: string)
	task.defer(function()
		for _, player in Players:GetPlayers() do
			pcall(function()
				self._dialog:Notify(player, { Title = "Team Combo", Description = text, Text = text } :: any)
			end)
		end
	end)
end

-- One more successful serve (NPC or real-player) or, with `grade` nil, a walkout. Completing a chain
-- opens the window, or refreshes it to a full window when one is already open (DEC-036 C4).
-- No yield: the end timer and the announcement are deferred.
function CustomerService:RecordTeamServe(grade: Rules.ServeGrade?, server: Player?): boolean
	local chain, triggered = Rules.NextTeamChain(self._teamChain, grade, TeamComboConfig.CHAIN_TARGET)
	self._teamChain = chain
	if not triggered then
		return false
	end

	local deadline = os.clock() + TeamComboConfig.DURATION_SECONDS
	self._teamComboUntil = deadline
	local bonusText =
		`+{math.round(TeamComboConfig.PAY_BONUS * 100)}% pay for {TeamComboConfig.DURATION_SECONDS} seconds!`
	if server ~= nil then
		self:_notifyTeamCombo(`{server.DisplayName} completed the Team Combo! {bonusText}`)
	else
		self:_notifyTeamCombo(`Team Combo! {bonusText}`)
	end
	task.delay(TeamComboConfig.DURATION_SECONDS, function()
		if self._teamComboUntil ~= deadline then
			return -- refreshed by a newer chain, whose own timer ends it
		end
		self._teamComboUntil = 0
		self:_notifyTeamCombo("Team Combo is over.")
	end)
	return true
end

-- The variant for a new NPC: Rules.PickVariant at the highest clocked-in level. Contained:
-- any failure means a normal NPC.
function CustomerService:_rollVariant(): Rules.Variant?
	local ok, variant = pcall(function()
		local top = 0
		for _, player in Players:GetPlayers() do
			if self._shift:IsClockedIn(player) then
				top = math.max(top, self:_levelOf(player))
			end
		end
		if top <= 0 then
			return nil
		end
		-- First-session (scripted) NPCs are always friendly: no variant, no Karen look. The look is
		-- built at spawn, before an NPC is assigned, so hold variants back while any barista is new.
		for _, player in Players:GetPlayers() do
			if
				self._shift:IsClockedIn(player)
				and self:_readServedCount(player) < CustomerConfig.FIRST_SESSION_COUNT
			then
				return nil
			end
		end
		return Rules.PickVariant(top, math.random())
	end)
	if not ok then
		warnThrottled("variant", `[CustomerService] Variant roll failed; normal NPC: {variant}`)
		return nil
	end
	return variant
end

-- _watchPlayer for one player, contained: a failure for one player is warned about
-- and never stops the others or the start-up that follows.
function CustomerService:_safeWatchPlayer(player: Player)
	local ok, err = pcall(self._watchPlayer, self, player)
	if not ok then
		warnThrottled("watch", `[CustomerService] Could not watch {player.Name}'s collision group: {err}`)
	end
end

function CustomerService:_pacingLoop()
	while true do
		-- The barista count asks ShiftService, so it can throw too: one failure skips
		-- this tick and never ends the loop.
		local ok, err = pcall(function()
			self._baristas = self:_countBaristas()
			local stress = self:_stressMode()
			if stress ~= nil then
				self:_stressTick(stress)
			end
			local burst = if self:IsRushHour() then (RatingConfig.RUSH_SPAWN_BURST or 3) else 1
			for _ = 1, burst do
				self:_spawnIfNeeded()
			end
			if CustomerConfig.ASSIGNMENT_MODE ~= "Dedicated" then
				self:_assignAll()
			end
		end)
		if not ok then
			warnThrottled("pacing", `[CustomerService] Pacing step failed: {err}`)
		end
		task.wait(PACING_TICK_SECONDS)
	end
end

-- CustomersServed for the player, from their profile. Missing data means
-- normal pool orders, never the scripted ones.
function CustomerService:_readServedCount(player: Player): number
	if self._data == nil then
		return CustomerConfig.FIRST_SESSION_COUNT
	end
	local pcallOk, awaitOk, profile = pcall(function()
		return self._data:GetDataAsync(player):timeout(SERVED_COUNT_TIMEOUT_SECONDS):await()
	end)
	if pcallOk and awaitOk and typeof(profile) == "table" then
		local stats = (profile :: any).Statistics
		if typeof(stats) == "table" and typeof(stats.CustomersServed) == "number" then
			return stats.CustomersServed
		end
	end
	warnOnce("served", `[CustomerService] Could not read CustomersServed for {player.Name}; using pool orders.`)
	return CustomerConfig.FIRST_SESSION_COUNT
end

-- The same spec is never dealt to one barista twice in a row: compares the
-- order fields that make a serve (category, item, size and options).
function CustomerService:_sameOrder(a: Rules.OrderItem, b: Rules.OrderItem): boolean
	if a.Category ~= b.Category or a.Item ~= b.Item then
		return false
	end
	local older = a.CustomInfo
	local newer = b.CustomInfo
	if typeof(older) ~= "table" or typeof(newer) ~= "table" then
		return older == newer
	end
	for _, key in { "Size", "Syrup Flavor", "Tapioca Flavor", "Iced", "Sugar" } do
		if older[key] ~= newer[key] then
			return false
		end
	end
	return true
end

-- The order this NPC carries: the first-session script while the barista is
-- new, else a pool pick that avoids the barista's last spec (re-roll up to
-- 5 times). Returns the order and whether it is scripted.
function CustomerService:_pickOrderFor(player: Player): (Rules.OrderItem, boolean)
	local served = self:_readServedCount(player)
	self._firstServe[player] = if served == 0 then true else nil
	if served < CustomerConfig.FIRST_SESSION_COUNT then
		local scripted = CustomerConfig.FIRST_SESSION_ORDERS[served + 1]
		return {
			Category = scripted.Category,
			Item = scripted.Item,
			CustomInfo = table.clone(scripted.CustomInfo),
		},
			true
	end
	local level = self:_levelOf(player)
	local order = Rules.PickOrder(nil, nil, level)
	for _ = 1, 5 do
		local last = self._lastOrder[player]
		if last == nil or not self:_sameOrder(order, last) then
			break
		end
		order = Rules.PickOrder(nil, nil, level)
	end
	return order, false
end

-- The barista's level (1 when ProgressionService is unavailable).
function CustomerService:_levelOf(player: Player): number
	local ok, level = pcall(function()
		return Knit.GetService("ProgressionService"):GetLevel(player)
	end)
	return if ok and typeof(level) == "number" then level else 1
end

-- True while the barista holds fewer tickets than their level allows.
function CustomerService:_hasFreeSlot(player: Player): boolean
	local slots = Progression.SlotsFor(self:_levelOf(player))
	local held = 0
	for _ in self._tickets[player] or {} do
		held += 1
	end
	return held < slots
end

-- The ticket table (the M1.4f contract, copied exactly; Slot is added by _assign).
function CustomerService:_makeTicket(npc: Npc.Npc): { [string]: any }
	local customInfo = table.clone(npc.Order.CustomInfo)
	local items = {}
	for _, item in npc.Orders do
		table.insert(items, { Category = item.Category, Item = item.Item, CustomInfo = table.clone(item.CustomInfo) })
	end
	return {
		Id = npc.Model.Name,
		NpcModel = npc.Model,
		Label = npc.LabelText,
		Items = items, -- every item of a multi-item order; Spec is the first
		Variant = npc.Variant,
		Spec = {
			Category = npc.Order.Category,
			Item = npc.Order.Item,
			CustomInfo = customInfo,
			Size = customInfo.Size,
		},
		PatienceEnd = npc.Model:GetAttribute("PatienceEnd"),
		PatienceTotal = npc.PatienceTotal,
		Scripted = npc.Scripted,
		Rescue = false,
	}
end

-- `slot` is the ticket slot index; it rides as the 2nd argument so a nil ticket (clear) still names its slot.
function CustomerService:_fireTicket(player: Player, ticket: { [string]: any }?, slot: number)
	local ok, err = pcall(function()
		self.Client.TicketChanged:Fire(player, ticket, slot)
	end)
	if not ok then
		warnOnce("ticket", `[CustomerService] TicketChanged failed: {err}`)
	end
end

-- The session shift number for the player: shifts completed plus the current one.
function CustomerService:_sessionShiftOf(player: Player): number
	return (self._sessionShifts[player] or 0) + 1
end

-- Assigns one waiting NPC to a free barista (design 4.3-4.5). No-ops when the
-- NPC is gone or taken, while a player order is pending, or when nobody
-- qualifies: the NPC keeps waiting and the next pacing tick tries again.
function CustomerService:_assign(npc: Npc.Npc)
	if self._context == nil or npc.Left or npc.State ~= "AtCounter" or npc.AssignedUserId ~= nil then
		return
	end
	if self._order:GetPendingCount() > 0 then
		return -- real-player orders go first (design 4.9)
	end
	local candidates: { Player } = {}
	for _, player in Players:GetPlayers() do
		if self._shift:IsClockedIn(player) and self:_hasFreeSlot(player) and not self._order:HasActiveOrder(player) then
			table.insert(candidates, player)
		end
	end
	local player = Rules.PickAssignee(candidates, self._idleSince)
	if player == nil then
		return
	end

	local order, scripted = self:_pickOrderFor(player)
	local spec, reason = OrderSpec.FromOrderItem(order)
	if spec == nil then
		warnOnce("order", `[CustomerService] Order rejected by OrderSpec ({reason}): {order.Category}/{order.Item}`)
		return
	end

	-- The ticket Id is the model name, unique per NPC.
	self._npcSeq += 1
	if npc.Model.Name == "Customer" then
		npc.Model.Name = `Customer_{self._npcSeq}`
	end
	local orders: { Rules.OrderItem } = { order }
	local specs: { OrderSpec.OrderSpec } = { spec }
	if scripted then
		npc:ClearVariant() -- first-session NPCs are always normal
	else
		for _ = 2, Rules.ItemCountForLevel(self:_levelOf(player)) do
			local extra = Rules.PickOrder(nil, nil, self:_levelOf(player))
			local extraSpec = OrderSpec.FromOrderItem(extra)
			if extraSpec ~= nil then
				table.insert(orders, extra)
				table.insert(specs, extraSpec)
			end
		end
	end
	npc:SetOrders(orders, specs)
	npc:SetAssignment(
		player.UserId,
		Rules.VariantPatience(
			Rules.PatienceSeconds(orders, nil, if scripted then nil else self:_sessionShiftOf(player)),
			npc.Variant
		),
		scripted
	)
	self._lastOrder[player] = order
	local held = self._tickets[player]
	if held == nil then
		held = {}
		self._tickets[player] = held
	end
	local slot = 1
	while held[slot] ~= nil do
		slot += 1
	end
	local ticket = self:_makeTicket(npc)
	ticket.Slot = slot
	held[slot] = ticket
	self._assignee[npc] = player
	self:_ensureServePrompt(npc)
	self:_fireTicket(player, ticket, slot)
end

-- Retries every unassigned NPC at the counter (the 1 s pacing tick).
function CustomerService:_assignAll()
	if self._context == nil then
		return
	end
	for _, npc in self:GetWaitingCustomers() do
		if npc.AssignedUserId == nil then
			self:_assign(npc)
		end
	end
end

-- The first NPC on a fresh profile assigns without waiting for the next tick.
function CustomerService:_onAtCounter(npc: Npc.Npc)
	if not self.Enabled then
		return
	end
	if CustomerConfig.ASSIGNMENT_MODE == "Dedicated" then
		self:_ensureNpcPrompt(npc, "Take Order", "Customer")
	else
		self:_assign(npc)
	end
end

function CustomerService:_onAtPickup(npc: Npc.Npc)
	if not self.Enabled then
		return
	end
	self:_ensureNpcPrompt(npc, "Serve", npc.LabelText)
end

function CustomerService:_ensureNpcPrompt(npc: Npc.Npc, actionText: string, objectText: string)
	local root: BasePart = npc.Root
	local head = npc.Model:FindFirstChild("HumanoidRootPart")
	if head ~= nil and head:IsA("BasePart") then
		root = head
	end
	local prompt = root:FindFirstChildOfClass("ProximityPrompt")
	if prompt == nil then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "CustomerPrompt"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(player)
			local ok, err = pcall(self._onCustomerPromptTriggered, self, npc, player)
			if not ok then
				warnOnce("prompt", `[CustomerService] Customer prompt failed: {err}`)
			end
		end)
	end
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.Enabled = true
	npc.Model:SetAttribute("PromptAction", actionText)
end

function CustomerService:_ensureServePrompt(npc: Npc.Npc)
	self:_ensureNpcPrompt(npc, "Serve", npc.LabelText)
end

function CustomerService:_onCustomerPromptTriggered(npc: Npc.Npc, player: Player)
	if npc.State == "AtCounter" then
		self:_onTakeOrderTriggered(npc, player)
	elseif npc.State == "AtPickup" then
		self:_onServeTriggered(npc, player)
	end
end

function CustomerService:_onTakeOrderTriggered(npc: Npc.Npc, player: Player)
	if self._context == nil or npc.Left or npc.State ~= "AtCounter" then
		return
	end
	if not self._shift:IsClockedIn(player) then
		self._dialog:Notify(player, {
			Title = "Clock In Required",
			Description = "You must be clocked in to take orders!",
		})
		return
	end
	local character = player.Character
	local primary = if character ~= nil then character.PrimaryPart else nil
	if primary == nil or (primary.Position - npc.Root.Position).Magnitude > 12 then
		return
	end
	if not self:_hasFreeSlot(player) then
		self._dialog:Notify(player, {
			Title = "Slots Full",
			Description = "You already have an active order ticket!",
		})
		return
	end

	local order, scripted = self:_pickOrderFor(player)
	local spec, reason = OrderSpec.FromOrderItem(order)
	if spec == nil then
		warnOnce("order", `[CustomerService] Order rejected by OrderSpec ({reason}): {order.Category}/{order.Item}`)
		return
	end

	self._npcSeq += 1
	if npc.Model.Name == "Customer" then
		npc.Model.Name = `Customer_{self._npcSeq}`
	end
	local orders: { Rules.OrderItem } = { order }
	local specs: { OrderSpec.OrderSpec } = { spec }
	if scripted then
		npc:ClearVariant()
	else
		for _ = 2, Rules.ItemCountForLevel(self:_levelOf(player)) do
			local extra = Rules.PickOrder(nil, nil, self:_levelOf(player))
			local extraSpec = OrderSpec.FromOrderItem(extra)
			if extraSpec ~= nil then
				table.insert(orders, extra)
				table.insert(specs, extraSpec)
			end
		end
	end
	npc:SetOrders(orders, specs)
	self._lastOrder[player] = order

	local requestedText = Rules.FormatOrderForNotepad(orders, specs)
	npc.RequestedDrinkText = requestedText
	self._activeOrderingNpc[player] = npc

	self.Client.OpenOrderingTablet:Fire(player, {
		NpcId = npc.Id,
		RequestedText = requestedText,
		Orders = orders,
		Specs = specs,
	})
end

function CustomerService:_submitNpcOrder(
	player: Player,
	npcId: string,
	submittedOrderItems: any
): { Success: boolean, Message: string? }
	if not self.Enabled or self._context == nil then
		return { Success = false, Message = "CustomerService is disabled." }
	end
	if not self._shift:IsClockedIn(player) then
		return { Success = false, Message = "You must be clocked in." }
	end
	if typeof(npcId) ~= "string" or typeof(submittedOrderItems) ~= "table" then
		return { Success = false, Message = "Invalid order submission." }
	end

	local npc = self._activeOrderingNpc[player]
	if npc == nil or npc.Id ~= npcId then
		for activeNpc in self._npcs do
			if activeNpc.Id == npcId and not activeNpc.Left and activeNpc.State == "AtCounter" then
				npc = activeNpc
				break
			end
		end
	end
	if npc == nil or npc.Left or npc.State ~= "AtCounter" then
		return { Success = false, Message = "Customer is no longer waiting at the counter." }
	end

	local matches = Rules.ValidateSubmittedOrder(submittedOrderItems, npc.Orders)
	if not matches then
		return { Success = false, Message = "That doesn't match what the customer asked for!" }
	end

	-- Dedicated mode ticket generation & assignment
	local scripted = npc.Scripted
	local patienceSeconds = Rules.VariantPatience(
		Rules.PatienceSeconds(npc.Orders, nil, if scripted then nil else self:_sessionShiftOf(player)),
		npc.Variant
	)
	npc:SetAssignment(player.UserId, patienceSeconds, scripted)

	local held = self._tickets[player]
	if held == nil then
		held = {}
		self._tickets[player] = held
	end
	local slot = 1
	while held[slot] ~= nil do
		slot += 1
	end
	local ticket = self:_makeTicket(npc)
	ticket.Slot = slot
	held[slot] = ticket
	self._assignee[npc] = player
	self:_fireTicket(player, ticket, slot)

	-- Free counter spot so next in queue can step up
	self._context.ReleaseCounter(npc)

	-- Claim pickup spot and move NPC there
	local pickupSpot = self._context.ClaimPickupSpot(npc)
	self._activeOrderingNpc[player] = nil
	if pickupSpot ~= nil then
		npc:GoToPickup(pickupSpot)
	end

	return { Success = true }
end

function CustomerService.Client:SubmitNpcOrder(player: Player, npcId: string, submittedOrderItems: any)
	return self.Server:_submitNpcOrder(player, npcId, submittedOrderItems)
end

-- The Serve prompt, in design 4.6 order. The tip bonus is resolved first (it may
-- yield on a cold pass cache); after that there is no yield from the checks through
-- the FindServeTools pick, the tool destroy and the payout.
function CustomerService:_onServeTriggered(npc: Npc.Npc, player: Player)
	if self._context == nil then
		return
	end
	local okTip, tipBonus = pcall(function()
		return Knit.GetService("PerkService"):GetTipBonus(player)
	end)
	if not okTip or typeof(tipBonus) ~= "number" then
		tipBonus = 0
	end
	-- (1) clocked in.
	if not self._shift:IsClockedIn(player) then
		return
	end
	-- (2) close enough.
	local character = player.Character
	local primary = if character ~= nil then character.PrimaryPart else nil
	if primary == nil or (primary.Position - npc.Root.Position).Magnitude > 10 then
		return
	end
	-- (3) still waiting.
	if npc.Left or (npc.State ~= "AtPickup" and npc.State ~= "AtCounter") then
		return
	end
	-- (4) assigned, or a Rescue below 30% patience.
	local fractionLeft = npc:FractionLeft()
	local assigned = npc.AssignedUserId == player.UserId
	if not Rules.CanServe(assigned, fractionLeft) then
		return
	end
	-- (5) a matching unserved tool. FindServeTools already skips Served tools.
	local tools, grade, reasons = self._order:FindServeTools(player, npc.Specs)
	if tools == nil then
		pcall(function()
			Knit.GetService("AnalyticsEvents"):Custom(player, "WrongOrderRejected", 1)
		end)
		npc:PlayConfused()
		npc:SayWrong()
		self._dialog:Notify(player, {
			Title = "Wrong drink",
			Description = reasons[1] or "That isn't what they ordered.",
		})
		return
	end
	if grade ~= "Perfect" and grade ~= "Close" then
		return
	end
	-- BIG-B7 skill moment: flat pour tip, read before the tools are destroyed (guarded; serve never breaks).
	local pourTip = 0
	local okPour, pourResult = pcall(function()
		return Knit.GetService("KitchenService"):GetPourTip(tools)
	end)
	if okPour and typeof(pourResult) == "number" then
		pourTip = pourResult
	end
	if #tools > 0 and npc.Model ~= nil and npc.Model.Parent ~= nil then
		pcall(function()
			local carried = tools[1]:Clone()
			carried.Parent = npc.Model
		end)
	end
	for _, tool in tools do
		tool:Destroy()
	end

	local rescue = not assigned
	local combo = self._combo[player] or 0
	local pay = Rules.Payout(npc.Orders, grade, fractionLeft, combo, npc.Scripted, rescue)
	pay = Rules.PayoutVariant(pay, npc.Variant, grade)
	if self:IsRushHour() then
		pay = math.round(pay * RatingConfig.RUSH_PAY_MULT)
	end
	-- Team Combo stacks on Rush Hour (DEC-036 C2); the tip boost below is applied on the result.
	pay = self:ApplyTeamCombo(pay)
	-- Pass/pet tip boost (DEC-036 B1): base pay stays, the whole-BB extra is added on top.
	local tip = 0
	if tipBonus > 0 then
		local okExtra, extra = pcall(function()
			return Knit.GetService("PerkService"):TakeTipExtra(player, pay, tipBonus)
		end)
		if okExtra and typeof(extra) == "number" then
			tip = extra
			pay += extra
		end
	end
	if pourTip > 0 then
		tip += pourTip
		pay += pourTip
	end
	self._currency:Modify(player, "BobaBucks", pay, "Gameplay")
	pcall(function()
		local a = Knit.GetService("AnalyticsEvents")
		a:Funnel(player, 4, "FirstServe")
		a:Custom(player, "NpcServed", 1)
		a:Custom(player, "ServeSeconds", (npc.Model:GetAttribute("PatienceTotal") or 0) * (1 - fractionLeft))
	end)
	self._stats:IncrementStat(player, "CustomersServed")
	pcall(function()
		Knit.GetService("LeaderboardService"):IncrementStat(player, "OrdersServed", 1)
	end)
	-- AdvanceQuest can yield (data, pass lookups); spawned so the serve path never waits on it.
	task.spawn(function()
		pcall(function()
			Knit.GetService("QuestService"):AdvanceQuest(player, "CustomersServed", 1)
		end)
	end)
	local newCombo = Rules.NextCombo(combo, grade)
	self._combo[player] = newCombo
	local teamDone = self:RecordTeamServe(grade, player)
	local teamChain = self._teamChain
	local isFirstServe = self._firstServe[player] == true and npc.Scripted
	self._firstServe[player] = nil

	local text = `+{pay} · {grade}`
	if npc.Variant ~= nil then
		text ..= ` · {npc.Variant}`
	end
	if npc.Scripted or fractionLeft >= CustomerConfig.FAST_FRACTION then
		text ..= " · Fast"
	end
	if newCombo >= 2 then
		text ..= ` · Combo ×{newCombo}`
	end
	if teamChain >= TEAM_PROGRESS_FROM then
		text ..= ` · Team {teamChain}/{TeamComboConfig.CHAIN_TARGET}`
	end
	self._dialog:Notify(player, { Title = "Order served!", Description = text })
	task.defer(function()
		pcall(function()
			if COMBO_MILESTONES[newCombo] and not teamDone and not isFirstServe then
				local nextBonus =
					math.round(math.min(newCombo * CustomerConfig.COMBO_STEP, CustomerConfig.COMBO_CAP) * 100)
				local comboText = `Combo ×{newCombo}! Next serve +{nextBonus}% pay`
				self._dialog:Notify(player, { Title = "Combo", Description = comboText, Text = comboText } :: any)
			end
			if isFirstServe then
				task.delay(0.2, function()
					pcall(function()
						local firstText = `Your first order! +{pay} Boba Bucks`
						self._dialog:Notify(
							player,
							{ Title = "First order", Description = firstText, Text = firstText } :: any
						)
					end)
				end)
			end
		end)
	end)
	self:_showServePay(npc, pay, grade)

	npc.Rescue = rescue
	local holder = self._assignee[npc]
	self:_clearTicket(npc)
	if self._context ~= nil then
		self._context.ReleasePickupSpot(npc)
	end
	if rescue and holder ~= nil and holder ~= player then
		self._dialog:Notify(holder, {
			Title = "Customer rescued",
			Description = `{player.Name} rescued your customer!`,
		})
	end
	local variantConfig = if npc.Variant ~= nil then CustomerConfig.VARIANTS[npc.Variant] else nil
	if variantConfig ~= nil and variantConfig.StompOnClose == true and grade == "Close" then
		npc:PlayConfused() -- Karen stomps out (Confused is the approved angry animation, DEC-015)
	end
	npc:Leave("Served", grade)
	pcall(function()
		self.CustomerResolved:Fire(player, {
			Kind = "Served",
			Grade = grade,
			Pay = pay,
			Fast = npc.Scripted or fractionLeft >= CustomerConfig.FAST_FRACTION,
			Combo = newCombo,
			Items = #npc.Orders,
			Tip = tip,
		})
	end)
end

-- True while the player holds an open ticket.
function CustomerService:HasTicket(player: Player): boolean
	return next(self._tickets[player] or {}) ~= nil
end

-- A floating "+N" over the NPC for 1.5 s. Styles tokens only (DEC-013).
function CustomerService:_showServePay(npc: Npc.Npc, pay: number, grade: Rules.ServeGrade)
	local head = npc.Model:FindFirstChild("Head")
	if head == nil then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "ServePay"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(120, 40)
	gui.StudsOffset = Vector3.new(0, 4.5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui:SetAttribute("Grade", grade)
	local payLabel = Instance.new("TextLabel")
	payLabel.Size = UDim2.fromScale(1, 1)
	payLabel.BackgroundTransparency = 1
	payLabel.FontFace = Styles.FONT_FREDOKA
	payLabel.TextColor3 = Styles.GOLD
	payLabel.TextScaled = true
	payLabel.Text = `+{pay} BB`
	local payStroke = Instance.new("UIStroke")
	payStroke.Color = Styles.GOLD:Lerp(Color3.new(0, 0, 0), 0.3)
	payStroke.Thickness = 1
	payStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	payStroke.Parent = payLabel
	payLabel.Parent = gui
	gui.Parent = npc.Model
	task.delay(1.5, function()
		pcall(function()
			gui:Destroy()
		end)
	end)
end

-- Clears the ticket for the NPC's holder: fires nil, frees the slot and
-- restarts the holder's idle clock. Idempotent.
function CustomerService:_clearTicket(npc: Npc.Npc)
	local holder = self._assignee[npc]
	if holder == nil then
		return
	end
	self._assignee[npc] = nil
	local held = self._tickets[holder]
	if held ~= nil then
		for slot, ticket in held do
			if ticket.Id == npc.Model.Name then
				held[slot] = nil
				self._idleSince[holder] = os.clock()
				self:_fireTicket(holder, nil, slot)
				break
			end
		end
		if next(held) == nil then
			self._tickets[holder] = nil
		end
	end
end

-- The holder clocked out or left: frees their slot and hands the NPC to the
-- next free barista. Patience keeps running (PatienceEnd unchanged).
function CustomerService:_releaseTicket(player: Player)
	local npc: Npc.Npc? = nil
	for waiting, holder in self._assignee do
		if holder == player then
			npc = waiting
			break
		end
	end
	if npc == nil then
		return
	end
	npc:ClearAssignment()
	self:_clearTicket(npc)
	if not npc.Left and npc.State == "AtCounter" then
		self:_assign(npc)
	end
end

-- Walkouts clear the ticket and reset the combo (design 3.4, 4.8). A served
-- or despawned NPC only frees the slot. Never stops the pacing thread.
function CustomerService:_onCustomerLeft(npc: Npc.Npc, reason: string)
	if self._context ~= nil then
		self._context.ReleasePickupSpot(npc)
	end
	if reason ~= "PatienceOut" then
		self:_clearTicket(npc)
		return
	end
	self:RecordTeamServe(nil) -- any walkout breaks the server-wide chain, assigned or not
	local holder = self._assignee[npc]
	self:_clearTicket(npc)
	if holder == nil then
		return
	end
	self._combo[holder] = 0
	pcall(function()
		Knit.GetService("AnalyticsEvents"):Custom(holder, "NpcTimeout", 1)
	end)
	self._dialog:Notify(holder, { Title = "Customer left", Description = "Customer left. Combo lost." })
	pcall(function()
		self.CustomerResolved:Fire(holder, { Kind = "Walkout", Pay = 0, Fast = false, Combo = 0 })
	end)
end

---> lifecycle

function CustomerService:KnitStart()
	self._shift = Knit.GetService("ShiftService")
	self._order = Knit.GetService("OrderService")
	self._currency = Knit.GetService("CurrencyService")
	self._stats = Knit.GetService("StatisticsService")
	self._dialog = Knit.GetService("DialogService")
	self._data = Knit.GetService("DataService")

	local nodes = self:_resolveNodes()
	if nodes == nil or not self:_setUpCollisionGroups() then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = CUSTOMERS_FOLDER_NAME
	folder.Parent = workspace
	self._seats = Seats.new(nil, function()
		return self:_seatBudget()
	end)

	local orderingSystem = workspace:FindFirstChild("Ordering System")
	local pickUp = if orderingSystem ~= nil then orderingSystem:FindFirstChild("Pick Up") else nil
	if pickUp ~= nil then
		for _, child in pickUp:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(self._pickupNodes, child)
			end
		end
	end
	if #self._pickupNodes == 0 then
		for _, part in nodes.Counter do
			table.insert(self._pickupNodes, part)
		end
	end

	self._context = self:_makeContext(nodes, folder)
	self.Enabled = true

	-- Walkouts clear the ticket and reset the combo; every other stop only
	-- frees the slot. One NPC failing never stops the pacing thread.
	self.CustomerLeft:Connect(function(npc, reason)
		local ok, err = pcall(self._onCustomerLeft, self, npc, reason)
		if not ok then
			warnThrottled("left", `[CustomerService] Walkout step failed: {err}`)
		end
	end)

	-- Each ended shift advances the player's session shift count (memory only).
	self._shift.ShiftEnding:Connect(function(player)
		local ok, err = pcall(function()
			self._sessionShifts[player] = (self._sessionShifts[player] or 0) + 1
		end)
		if not ok then
			warnThrottled("shift", `[CustomerService] Session shift step failed: {err}`)
		end
	end)

	-- Clock-in restarts the idle clock; clock-out hands the ticket on.
	self._shift.ClockedInChanged:Connect(function(player, clockedIn)
		local ok, err = pcall(function()
			if not self.Enabled then
				return
			end
			if clockedIn then
				self._idleSince[player] = os.clock()
			else
				self:_releaseTicket(player)
			end
		end)
		if not ok then
			warnThrottled("clock", `[CustomerService] Clock change failed: {err}`)
		end
	end)

	for _, player in Players:GetPlayers() do
		self._idleSince[player] = os.clock()
	end

	-- Players who joined while the world was being resolved.
	for _, player in Players:GetPlayers() do
		self:_safeWatchPlayer(player)
	end
	task.spawn(self._pacingLoop, self)
end

function CustomerService:PlayerAdded(player: Player)
	if self.Enabled then
		self:_safeWatchPlayer(player)
	end
end

function CustomerService:PlayerRemoving(player: Player)
	self._activeOrderingNpc[player] = nil
	self._firstServe[player] = nil
	self._sessionShifts[player] = nil
	local connection = self._characterConnections[player]
	if connection ~= nil then
		connection:Disconnect()
		self._characterConnections[player] = nil
	end
	if self.Enabled then
		local ok, err = pcall(self._releaseTicket, self, player)
		if not ok then
			warnThrottled("leaving", `[CustomerService] Release step failed: {err}`)
		end
	end
end

return CustomerService

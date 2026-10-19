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

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies

local Knit = require(Packages.Knit)
local GoodSignal = require(Packages.GoodSignal)
local CustomerConfig = require(Shared.Configuration.CustomerConfig)
local RatingConfig = require(Shared.Configuration.RatingConfig)
local Progression = require(Shared.Configuration.Progression)
local OrderSpec = require(Shared.Ordering.OrderSpec)
local WorldPath = require(Shared.Utility.WorldPath)
local Npc = require(script.Npc)
local Rules = require(script.Rules)
local Styles = require(Shared.UI.Styles)

---> constants

local WORLD_WAIT_SECONDS = 10 -- total budget for resolving the authored world in KnitStart
local PACING_TICK_SECONDS = 1
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
	},

	-- Server-side signal: fires (npc: Npc.Npc, reason: string) once per NPC when it stops waiting.
	CustomerLeft = GoodSignal.new(),

	-- Server-side signal: fires (player, result) once per resolved customer for the barista.
	-- result = { Kind: "Served" | "Walkout", Grade: string?, Pay: number, Fast: boolean, Combo: number }
	CustomerResolved = GoodSignal.new(),

	--- True only after KnitStart found the whole world contract. When false nothing spawns.
	Enabled = false,

	_shift = nil :: any,
	_context = nil :: Npc.Context?,
	_npcs = {} :: { [Npc.Npc]: boolean },
	_npcCount = 0,
	_line = {} :: { Npc.Npc }, -- NPCs waiting for a counter spot, front first
	_counter = {} :: { [number]: Npc.Npc }, -- counter spot -> the NPC that holds it
	_baristas = 0, -- clocked-in players, refreshed every pacing tick
	_lastSpawnClock = 0,
	_characterConnections = {} :: { [Player]: RBXScriptConnection },
	_tickets = {} :: { [Player]: { [number]: { [string]: any } } }, -- barista -> slot -> live ticket (at most Progression.SlotsFor(level))
	_assignee = {} :: { [Npc.Npc]: Player }, -- NPC -> the barista holding its ticket
	_idleSince = {} :: { [Player]: number }, -- os.clock() at clock-in and at ticket clear
	_combo = {} :: { [Player]: number }, -- consecutive Perfect serves (session memory only)
	_lastOrder = {} :: { [Player]: Rules.OrderItem }, -- last order per barista (no repeats)
	_npcSeq = 0, -- makes ticket Ids unique per NPC
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
		OnDestroyed = function(npc)
			if self._npcs[npc] then
				self._npcs[npc] = nil
				self._npcCount -= 1
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
	if self._npcCount >= self:_pacingTarget() then
		return
	end
	if #self._line >= #context.Nodes.Queue then
		return -- never spawn into a full queue
	end
	if os.clock() - self._lastSpawnClock < CustomerConfig.SPAWN_GAP_SECONDS then
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

-- Rules.PacingTarget, scaled by Rush Hour (x NPC mult, cap + bonus).
function CustomerService:_pacingTarget(): number
	local target = Rules.PacingTarget(self._baristas)
	if self:IsRushHour() then
		target = math.min(
			CustomerConfig.SERVER_CAP + RatingConfig.RUSH_CAP_BONUS,
			math.ceil(target * RatingConfig.RUSH_NPC_MULT)
		)
	end
	return target
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
			self:_spawnIfNeeded()
			self:_assignAll()
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
	npc:SetAssignment(player.UserId, Rules.VariantPatience(Rules.PatienceSeconds(orders), npc.Variant), scripted)
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
	self:_assign(npc)
end

function CustomerService:_ensureServePrompt(npc: Npc.Npc)
	local root: BasePart = npc.Root
	local head = npc.Model:FindFirstChild("HumanoidRootPart")
	if head ~= nil and head:IsA("BasePart") then
		root = head
	end
	if root:FindFirstChild("ServePrompt") ~= nil then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ServePrompt"
	prompt.ActionText = "Serve"
	prompt.ObjectText = npc.LabelText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	npc.Model:SetAttribute("PromptAction", "Serve")
	prompt.Triggered:Connect(function(player)
		local ok, err = pcall(self._onServeTriggered, self, npc, player)
		if not ok then
			warnOnce("serve", `[CustomerService] Serve failed: {err}`)
		end
	end)
end

-- The Serve prompt, in design 4.6 order. No yield between the FindServeTools
-- pick and the tool destroy.
function CustomerService:_onServeTriggered(npc: Npc.Npc, player: Player)
	if self._context == nil then
		return
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
	if npc.Left or npc.State ~= "AtCounter" then
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
	pcall(function()
		Knit.GetService("QuestService"):AdvanceQuest(player, "CustomersServed", 1)
	end)
	local newCombo = Rules.NextCombo(combo, grade)
	self._combo[player] = newCombo

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
	self._dialog:Notify(player, { Title = "Order served!", Description = text })
	self:_showServePay(npc, pay)

	npc.Rescue = rescue
	local holder = self._assignee[npc]
	self:_clearTicket(npc)
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
	npc:Leave("Served")
	pcall(function()
		self.CustomerResolved:Fire(player, {
			Kind = "Served",
			Grade = grade,
			Pay = pay,
			Fast = npc.Scripted or fractionLeft >= CustomerConfig.FAST_FRACTION,
			Combo = newCombo,
			Items = #npc.Orders,
		})
	end)
end

-- True while the player holds an open ticket.
function CustomerService:HasTicket(player: Player): boolean
	return next(self._tickets[player] or {}) ~= nil
end

-- A floating "+N" over the NPC for 1.5 s. Styles tokens only (DEC-013).
function CustomerService:_showServePay(npc: Npc.Npc, pay: number)
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
	local payLabel = Instance.new("TextLabel")
	payLabel.Size = UDim2.fromScale(1, 1)
	payLabel.BackgroundTransparency = 1
	payLabel.FontFace = Styles.FONT_FREDOKA
	payLabel.TextColor3 = Styles.GREEN_DEEP
	payLabel.TextScaled = true
	payLabel.Text = `+{pay}`
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
	if reason ~= "PatienceOut" then
		self:_clearTicket(npc)
		return
	end
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

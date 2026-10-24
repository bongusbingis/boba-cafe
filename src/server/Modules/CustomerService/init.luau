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
	  workspace.Assets.NPC.OrderPickup BasePart plane where NPCs stand and wait

	API for the later serve and assignment work:
	  CustomerService:GetWaitingCustomers()  NPCs standing at a counter spot, by spot
	  CustomerService.CustomerLeft           GoodSignal (npc, reason); once per NPC when
	                                         it stops waiting: "PatienceOut", "LineGaveUp",
	                                         "Served" or "Despawned"
	  CustomerService.CustomerResolved       GoodSignal (player?, result). player is nil for
	                                         a walkout nobody held (register or orphan, TAKEOVER-FIX 2)
	  CustomerService.Enabled                false when the world contract is missing

	NPC fields other code may read: Model, Order, Spec, State, PatienceTotal,
	CounterSpot. The model's PatienceEnd attribute is server time.

	Assignment and Rescue (Q1), Serve at the NPC (Q2), the first-session script (Q4)
	and payout (Q5/Q6) are built (M1.4e). Still PENDING JACK: Q25 the NPC look.
--]]

---> services

local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

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
local MistakeText = require(Shared.Ordering.MistakeText)
local WorldPath = require(Shared.Utility.WorldPath)
local Npc = require(script.Npc)
local Rules = require(script.Rules)
local Seats = require(script.Seats)
local CounterLock = require(script.CounterLock)
local Styles = require(Shared.UI.Styles)

---> constants

local WORLD_WAIT_SECONDS = 10 -- total budget for resolving the authored world in KnitStart
local PACING_TICK_SECONDS = 1
local SUBMIT_MAX_DISTANCE_STUDS = 20 -- DEC-058 agent-set, Jack to tune: tablet submit range (Take Order is 12; slack to step back)
local COMBO_MILESTONES = { [3] = true, [5] = true, [10] = true } -- TUNING: combo values that get a callout toast
local TEAM_PROGRESS_FROM = 5 -- TUNING: show Team N/10 on the serve toast from this chain length
local SERVED_COUNT_TIMEOUT_SECONDS = 5 -- budget for reading Statistics.CustomersServed
local CUSTOMERS_FOLDER_NAME = "Customers"
-- Counter ordering (DEC-059): real players at workspace["Ordering System"].CustomerAreas.
local COUNTER_TICK_SECONDS = 0.3
local COUNTER_TAKE_DISTANCE_STUDS = 12 -- same as the NPC Take Order check
local COUNTER_SUBMIT_DEBOUNCE_SECONDS = 1
local COUNTER_PROMPT_NAME = "CounterOrderPrompt"
local COUNTER_PROMPT_TAG = "CounterOrderPrompt" -- the client hides it for the customer and non-takers
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

-- Picks a random position on the top surface of a plane Part, with clearance from already-waiting NPCs.
local function getRandomPointOnPlane(part: BasePart, occupiedPositions: { Vector3 }?): (Vector3, CFrame)
	local size = part.Size
	local marginX = math.min(1, size.X * 0.1)
	local marginZ = math.min(1, size.Z * 0.1)
	local halfX = math.max(0, (size.X / 2) - marginX)
	local halfZ = math.max(0, (size.Z / 2) - marginZ)

	local bestPos: Vector3? = nil
	local bestDist = -1

	for _ = 1, 8 do
		local ox = (math.random() * 2 - 1) * halfX
		local oz = (math.random() * 2 - 1) * halfZ
		local localPos = Vector3.new(ox, size.Y / 2, oz)
		local worldPos = (part.CFrame * CFrame.new(localPos)).Position

		if occupiedPositions == nil or #occupiedPositions == 0 then
			return worldPos, part.CFrame.Rotation
		end

		local minDist = math.huge
		for _, occ in occupiedPositions do
			local d = (worldPos - occ).Magnitude
			if d < minDist then
				minDist = d
			end
		end

		if minDist >= 2.5 then
			return worldPos, part.CFrame.Rotation
		end

		if minDist > bestDist then
			bestDist = minDist
			bestPos = worldPos
		end
	end

	return bestPos or part.Position, part.CFrame.Rotation
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
		-- Fired to close the Ordering Tablet screen on the barista's client.
		CloseOrderingTablet = Knit.CreateSignal(),
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
	_registerLines = {} :: { [number]: { Npc.Npc } }, -- register spot -> NPCs waiting in line, front first
	_npcRegister = {} :: { [Npc.Npc]: number }, -- NPC -> assigned register spot
	_counter = {} :: { [number]: Npc.Npc }, -- counter spot -> the NPC that holds it
	_pickupNodes = {} :: { BasePart }, -- pickup spots from workspace["Ordering System"]["Pick Up"]
	_pickupHolders = {} :: { [BasePart]: Npc.Npc }, -- pickup spot -> the NPC that holds it
	_npcPickupSpot = {} :: { [Npc.Npc]: Vector3 }, -- NPC -> claimed pickup position
	_activeOrderingNpc = {} :: { [Player]: Npc.Npc }, -- barista -> NPC whose order is currently being taken
	-- AUDIT-FIX submit: NPC -> baristas who pressed its Take Order. Submit falls back to this when the
	-- single binding above went stale, so a tablet for a still-waiting NPC never fails.
	_orderTakers = setmetatable({}, { __mode = "k" }) :: { [Npc.Npc]: { [Player]: boolean } },
	_rollingOrders = setmetatable({}, { __mode = "k" }) :: { [Npc.Npc]: boolean },
	_baristas = 0, -- clocked-in players, refreshed every pacing tick
	_emptySince = nil :: number?, -- os.clock() when the barista count last dropped to 0 (P2-3 dismiss)
	_lastSpawnClock = 0,
	_characterConnections = {} :: { [Player]: RBXScriptConnection },
	_baristaInventoryWatchers = {} :: { [Player]: { RBXScriptConnection } },
	_tickets = {} :: { [Player]: { [number]: { [string]: any } } }, -- barista -> slot -> live ticket (NPC or real order; at most Progression.SlotsFor(level))
	_counterAreas = {} :: { { Part: BasePart, Spot: number? } }, -- CustomerArea parts, each with its NPC Counter spot
	_counterSpotsMapped = false,
	_counterCustomers = {} :: { [Player]: { Area: number, Prompt: ProximityPrompt, Lock: CounterLock.Lock? } },
	_realOccupied = {} :: { [number]: boolean }, -- NPC counter spot -> a clocked-out player stands in its area
	_counterLockSeq = 0,
	_counterSubmitAt = {} :: { [Player]: number }, -- taker -> os.clock() of the last counter submit
	_clockInPromptOpen = {} :: { [Player]: boolean }, -- clock-in upsell dialog already asking this player
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
	local orderPickup = find("OrderPickup")

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
	if orderPickup == nil or not orderPickup:IsA("BasePart") then
		table.insert(missing, "workspace.Assets.NPC.OrderPickup (BasePart)")
	end

	if #missing > 0 or entry == nil or exit == nil or orderPickup == nil then
		warn(`[CustomerService] NPC customers disabled; missing authored content: {table.concat(missing, ", ")}`)
		return nil
	end
	return {
		Entry = entry :: BasePart,
		Exit = exit :: BasePart,
		Path = path,
		Queue = queue,
		Counter = counter,
		OrderPickup = orderPickup :: BasePart,
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
		-- Custom overheads come from PlayerOverheads.client; hide the default
		-- Roblox name/health overhead on the player's own Humanoid.
		local function hideDefaultOverhead(descendant: Instance)
			if descendant:IsA("Humanoid") then
				descendant.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
		for _, descendant in character:GetDescendants() do
			hideDefaultOverhead(descendant)
		end
		character.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = PLAYER_COLLISION_GROUP
			end
			hideDefaultOverhead(descendant)
		end)
	end

	self._characterConnections[player] = player.CharacterAdded:Connect(onCharacter)
	if player.Character ~= nil then
		onCharacter(player.Character)
	end
end

function CustomerService:_pickRegisterSpot(): number
	local nodes = if self._context ~= nil then self._context.Nodes else nil
	local count = if nodes ~= nil and nodes.Counter ~= nil then #nodes.Counter else 12
	if count <= 1 then
		return 1
	end

	-- DEC-059: a register where a real player is standing is skipped.
	local minLength = math.huge
	for spot = 1, count do
		local line = self._registerLines[spot]
		local len = if line ~= nil then #line else 0
		if len < minLength and not self._realOccupied[spot] then
			minLength = len
		end
	end

	local candidates = {}
	for spot = 1, count do
		local line = self._registerLines[spot]
		local len = if line ~= nil then #line else 0
		if len <= minLength + 1 and not self._realOccupied[spot] then
			table.insert(candidates, spot)
		end
	end

	if #candidates > 0 then
		return candidates[math.random(1, #candidates)]
	end

	return math.random(1, count)
end

function CustomerService:_makeContext(nodes: Npc.Nodes, folder: Folder): Npc.Context
	return {
		Nodes = nodes,
		Parent = folder,
		GetRegisterSpot = function(npc)
			local spot = self._npcRegister[npc]
			if spot == nil then
				spot = self:_pickRegisterSpot()
				self._npcRegister[npc] = spot
				if self._registerLines[spot] == nil then
					self._registerLines[spot] = {}
				end
				table.insert(self._registerLines[spot], npc)
			end
			return spot
		end,
		QueueIndex = function(npc)
			local spot = self._npcRegister[npc]
			if spot == nil then
				spot = self:_pickRegisterSpot()
				self._npcRegister[npc] = spot
				if self._registerLines[spot] == nil then
					self._registerLines[spot] = {}
				end
				table.insert(self._registerLines[spot], npc)
			end
			local line = self._registerLines[spot]
			return if line ~= nil then (table.find(line, npc) or 1) else 1
		end,
		TryTakeCounter = function(npc)
			local spot = self._npcRegister[npc]
			if spot == nil then
				return nil
			end
			local line = self._registerLines[spot]
			if line == nil or line[1] ~= npc then
				return nil
			end
			if self:_counterCustomerAtSpot(spot) then
				return nil -- a real player is ordering at this register (DEC-059)
			end
			if self._counter[spot] == nil or self._counter[spot] == npc then
				self._counter[spot] = npc
				return spot
			end
			return nil
		end,
		Release = function(npc)
			local spot = self._npcRegister[npc]
			if spot ~= nil and self._registerLines[spot] ~= nil then
				local index = table.find(self._registerLines[spot], npc)
				if index ~= nil then
					table.remove(self._registerLines[spot], index)
				end
			end
			self._npcRegister[npc] = nil

			local index = table.find(self._line, npc)
			if index ~= nil then
				table.remove(self._line, index)
			end
			for s, holder in self._counter do
				if holder == npc then
					self._counter[s] = nil
				end
			end
			self._npcPickupSpot[npc] = nil
			for s, holder in self._pickupHolders do
				if holder == npc then
					self._pickupHolders[s] = nil
				end
			end
		end,
		ReleaseCounter = function(npc)
			local spot = self._npcRegister[npc] or npc.CounterSpot
			if spot ~= nil and self._registerLines[spot] ~= nil then
				local index = table.find(self._registerLines[spot], npc)
				if index ~= nil then
					table.remove(self._registerLines[spot], index)
				end
			end
			for s, holder in self._counter do
				if holder == npc then
					self._counter[s] = nil
				end
			end
			npc.CounterSpot = nil
		end,
		ClaimPickupSpot = function(npc)
			local orderPickup = if self._context ~= nil then self._context.Nodes.OrderPickup else nil
			if orderPickup == nil and nodes ~= nil then
				orderPickup = nodes.OrderPickup
			end
			if orderPickup ~= nil and orderPickup:IsA("BasePart") then
				local occupied: { Vector3 } = {}
				for otherNpc, pos in self._npcPickupSpot do
					if otherNpc ~= npc and otherNpc.State == "AtPickup" and not otherNpc.Left then
						table.insert(occupied, pos)
					end
				end
				local targetPos, targetRot = getRandomPointOnPlane(orderPickup, occupied)
				self._npcPickupSpot[npc] = targetPos
				return targetPos, targetRot
			end
			for _, node in self._pickupNodes do
				if self._pickupHolders[node] == nil then
					self._pickupHolders[node] = npc
					self._npcPickupSpot[npc] = node.Position
					return node.Position, node.CFrame.Rotation
				end
			end
			local fallback = self._pickupNodes[1]
			if fallback ~= nil then
				self._npcPickupSpot[npc] = fallback.Position
				return fallback.Position, fallback.CFrame.Rotation
			end
			return nil, nil
		end,
		ReleasePickupSpot = function(npc)
			self._npcPickupSpot[npc] = nil
			for spot, holder in self._pickupHolders do
				if holder == npc then
					self._pickupHolders[spot] = nil
				end
			end
		end,
		IsPaused = function()
			return self._baristas == 0
		end,
		RegisterPatience = function(npc)
			return self:_registerPatience(npc)
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
	local totalQueued = 0
	for _, line in self._registerLines do
		totalQueued += #line
	end
	local maxLine = if self:IsRushHour()
		then (RatingConfig.RUSH_QUEUE_CAP or 35)
		else math.max(6, #context.Nodes.Counter * 3)
	if totalQueued >= maxLine then
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
	local regular = self:_regulars("RollSpawn", variant ~= nil) -- BIG-B5 hook: maybe a named regular
	local look = if regular ~= nil then regular.Look else nil
	local npc = Npc.new(context, order, spec, Rules.PatienceSeconds({ order }), variant, look)
	if npc == nil then
		return
	end
	if regular ~= nil then
		self:_regulars("Attach", npc, regular) -- BIG-B5 hook
	end
	self._npcs[npc] = true
	self._npcCount += 1
	local spot = self:_pickRegisterSpot()
	self._npcRegister[npc] = spot
	if self._registerLines[spot] == nil then
		self._registerLines[spot] = {}
	end
	table.insert(self._registerLines[spot], npc)
	table.insert(self._line, npc)
	npc:Start()
end

-- BIG-B5 hook: calls RegularsService[method]; any failure means a normal customer (nil).
function CustomerService:_regulars(method: string, ...: any): any
	local ok, result = pcall(function(...)
		local regulars = Knit.GetService("RegularsService") :: any
		return regulars[method](regulars, ...)
	end, ...)
	if not ok then
		warnThrottled("regulars", `[CustomerService] Regulars {method} failed: {result}`)
		return nil
	end
	return result
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
	if self._baristas <= 0 then
		return 0 -- TAKEOVER-REVIEW-FIX P2-3: no rush crowd into an empty cafe
	end
	if self:IsRushHour() or (self:_stressMode() == "Run" and workspace:GetAttribute("B4StressRush") == true) then
		local rushMin =
			math.min(RatingConfig.RUSH_MIN_TARGET or 25, (RatingConfig.RUSH_MIN_PER_BARISTA or 8) * self._baristas)
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

-- TAKEOVER-REVIEW-FIX P2-3: patience is paused while nobody is clocked in. After EMPTY_CAFE_DISMISS_SECONDS of
-- that, every waiting NPC leaves quietly ("LineGaveUp": no walkout, no rating change). Non-yielding.
function CustomerService:_dismissIfEmpty()
	if self._baristas > 0 then
		self._emptySince = nil
		return
	end
	local now = os.clock()
	if self._emptySince == nil then
		self._emptySince = now
		return
	end
	if now - self._emptySince < (CustomerConfig.EMPTY_CAFE_DISMISS_SECONDS or 60) then
		return
	end
	for npc in self._npcs do
		if not npc.Left then
			npc:Leave("LineGaveUp")
		end
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
			self:_dismissIfEmpty()
			local burst = if self:IsRushHour() then (RatingConfig.RUSH_SPAWN_BURST or 3) else 1
			for _ = 1, burst do
				self:_spawnIfNeeded()
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

-- The ticket table (the M1.4f contract, copied exactly; Slot is added by _issueTicket).
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

-- Display name of another NPC this player holds a ticket for (nil when none),
-- so a handoff to the wrong customer can name the right one instead of failing
-- silently. `npc` is the handoff target being excluded.
function CustomerService:_heldCustomerName(player: Player, npc: Npc.Npc): string?
	local held = self._tickets[player]
	if held == nil then
		return nil
	end
	for _, ticket in held do
		if ticket.NpcModel ~= npc.Model then
			for other in self._npcs do
				if other.Model == ticket.NpcModel then
					local regular = other.Model:GetAttribute("RegularName")
					local name = Rules.DisplayNames(other.Variant, if typeof(regular) == "string" then regular else nil)
					return name
				end
			end
			return "another customer"
		end
	end
	return nil
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

-- Register patience (TAKEOVER-FIX 2): the order's own patience with the same session ramp,
-- using the most-trimmed clocked-in barista, times REGISTER_PATIENCE_MULT. No yield.
function CustomerService:_registerPatience(npc: Npc.Npc): number
	local shift = 1
	for _, player in Players:GetPlayers() do
		if self._shift:IsClockedIn(player) then
			shift = math.max(shift, self:_sessionShiftOf(player))
		end
	end
	local seconds = Rules.VariantPatience(Rules.PatienceSeconds(npc.Orders, nil, shift), npc.Variant)
	return seconds * CustomerConfig.REGISTER_PATIENCE_MULT
end

function CustomerService:_checkOrderReadiness(npc: Npc.Npc)
	if npc.Left or self._order == nil or typeof(self._order.UpdateCustomerOrderStatus) ~= "function" then
		return
	end
	local holder = self._assignee[npc]
	if holder == nil or not holder:IsDescendantOf(Players) then
		return
	end
	local tools = self._order:FindServeTools(holder, npc.Specs)
	if tools ~= nil then
		self._order:UpdateCustomerOrderStatus(npc.Id, "Ready for Pick Up")
	else
		self._order:UpdateCustomerOrderStatus(npc.Id, "Being Prepared")
	end
end

function CustomerService:_watchBaristaInventory(player: Player)
	if self._baristaInventoryWatchers[player] ~= nil then
		return
	end

	local conns: { RBXScriptConnection } = {}
	self._baristaInventoryWatchers[player] = conns

	local function onInventoryChanged()
		local held = self._tickets[player]
		if not held then
			return
		end
		for _, ticket in held do
			for npc in self._npcs do
				if npc.Model ~= nil and npc.Model.Name == ticket.Id then
					self:_checkOrderReadiness(npc)
					break
				end
			end
		end
	end

	local function hookBackpack(backpack: Instance?)
		if not backpack then
			return
		end
		table.insert(conns, backpack.ChildAdded:Connect(onInventoryChanged))
		table.insert(conns, backpack.ChildRemoved:Connect(onInventoryChanged))
	end

	local function hookCharacter(char: Model?)
		if not char then
			return
		end
		table.insert(conns, char.ChildAdded:Connect(onInventoryChanged))
		table.insert(conns, char.ChildRemoved:Connect(onInventoryChanged))
	end

	hookBackpack(player:FindFirstChildOfClass("Backpack"))
	hookCharacter(player.Character)

	table.insert(
		conns,
		player.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then
				hookBackpack(child)
			end
		end)
	)

	table.insert(
		conns,
		player.CharacterAdded:Connect(function(char)
			hookCharacter(char)
		end)
	)
end

function CustomerService:_unwatchBaristaInventory(player: Player)
	local conns = self._baristaInventoryWatchers[player]
	if conns ~= nil then
		for _, conn in conns do
			conn:Disconnect()
		end
		self._baristaInventoryWatchers[player] = nil
	end
end

-- Puts a ticket for `npc` in the player's first free slot and tells their client.
function CustomerService:_issueTicket(player: Player, npc: Npc.Npc)
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
	self:_watchBaristaInventory(player)
	self:_checkOrderReadiness(npc)
end

-- The holder left or clocked out: hands an accepted order to the longest-idle clocked-in
-- barista with a free slot. Nobody free: it stays unassigned (any barista can Rescue it
-- below RESCUE_FRACTION) and walks out when its pickup patience runs out.
function CustomerService:_handOff(npc: Npc.Npc, exclude: Player?)
	if self._context == nil or npc.Left or npc.State == "AtCounter" then
		return
	end
	local candidates: { Player } = {}
	for _, player in Players:GetPlayers() do
		if
			player ~= exclude
			and self._shift:IsClockedIn(player)
			and not self._shift:IsWrappingUp(player)
			and self:_hasFreeSlot(player)
		then
			table.insert(candidates, player)
		end
	end
	local player = Rules.PickAssignee(candidates, self._idleSince)
	if player == nil then
		return
	end
	npc:Reassign(player.UserId)
	self:_issueTicket(player, npc)
end

-- Re-dispatches any unassigned NPCs waiting at pick-up to free baristas.
function CustomerService:_dispatchUnassignedNpcs()
	if self._context == nil then
		return
	end
	for npc in self._npcs do
		if not npc.Left and npc.State == "AtPickup" and self._assignee[npc] == nil then
			self:_handOff(npc, nil)
		end
	end
end

-- Dedicated is the only mode (TAKEOVER-FIX 2): the barista who takes the order serves it.
function CustomerService:_onAtCounter(npc: Npc.Npc)
	if not self.Enabled then
		return
	end
	self:_ensureNpcPrompt(npc, "Take Order", "Customer")
end

function CustomerService:_onAtPickup(npc: Npc.Npc)
	if not self.Enabled then
		return
	end
	self:_ensureNpcPrompt(npc, "Serve", npc.LabelText)
	-- TAKEOVER-REVIEW-FIX P3-3: the ticket was built at submit, before pickup patience started, so it had no
	-- PatienceEnd and the bar stayed hidden. Re-send it now that StartPatience has run.
	local holder = self._assignee[npc]
	local held = if holder ~= nil then self._tickets[holder] else nil
	if holder ~= nil and held ~= nil then
		for slot, ticket in held do
			if ticket.NpcModel == npc.Model then
				ticket.PatienceEnd = npc.Model:GetAttribute("PatienceEnd")
				ticket.PatienceTotal = npc.PatienceTotal
				self:_fireTicket(holder, ticket, slot)
				break
			end
		end
	end
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
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 15
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

-- Clock-in upsell: the player tried a barista action while clocked out. Ask them
-- to clock in (ButtonPrompt, DEC-013) instead of only toasting; confirming clocks
-- them in through ShiftService, declining just dismisses. Returns true when the
-- player ends up clocked in. Never yields when already clocked in.
function CustomerService:_ensureClockedIn(player: Player): boolean
	if self._shift:IsClockedIn(player) then
		return true
	end
	if player.Parent == nil or self._clockInPromptOpen[player] then
		return false
	end
	self._clockInPromptOpen[player] = true
	local okChoice, choice = self._dialog
		:CreateDialog(player, "ButtonPrompt", {
			Title = "Clock In Required",
			Text = "You need to be clocked in for this. Do you want to clock in?",
			Buttons = {
				{ Text = "Clock In", Color = Styles.GREEN },
				{ Text = "Cancel", Color = Styles.RED },
			},
		})
		:await()
	self._clockInPromptOpen[player] = nil
	if player.Parent == nil then
		return false
	end
	if okChoice and choice == "Clock In" and not self._shift:IsClockedIn(player) then
		-- Same state transition as the HUD clock-in button: ShiftService owns the
		-- attribute, resumes the paused shift and fires ClockedInChanged.
		self._shift:SetClockedIn(player, true)
	end
	return self._shift:IsClockedIn(player)
end

function CustomerService:_onTakeOrderTriggered(npc: Npc.Npc, player: Player)
	if self._context == nil or npc.Left or npc.State ~= "AtCounter" then
		return
	end
	if not self:_ensureClockedIn(player) then
		return
	end
	if npc.Left or npc.State ~= "AtCounter" then
		return
	end
	local character = player.Character
	local primary = if character ~= nil then character.PrimaryPart else nil
	-- Matches the prompt's MaxActivationDistance (15) so an offered Take Order
	-- never fails silently just outside this check (same fix as Serve).
	if primary == nil or (primary.Position - npc.Root.Position).Magnitude > 15 then
		return
	end
	if self._shift:IsWrappingUp(player) then
		self._dialog:Notify(
			player,
			{ Title = "Shift complete", Description = "Finish your open order to end the shift." }
		)
		return
	end
	if not self:_hasFreeSlot(player) then
		self._dialog:Notify(player, {
			Title = "Slots Full",
			Description = "You already have an active order ticket!",
		})
		return
	end

	-- The order is rolled once per NPC (TAKEOVER-FIX 3): a re-press or a second barista
	-- sees the same order, so an open tablet always still matches.
	if not npc.OrderRolled then
		if self._rollingOrders[npc] then
			while self._rollingOrders[npc] and not npc.OrderRolled and not npc.Left do
				task.wait()
			end
		end
		if not npc.OrderRolled and not npc.Left then
			self._rollingOrders[npc] = true
			local okRoll, errRoll = pcall(function()
				local order, scripted = self:_pickOrderFor(player)
				order = self:_regulars("OrderFor", npc, player, order, scripted) or order -- BIG-B5 hook: a regular's favourite
				local spec, reason = OrderSpec.FromOrderItem(order)
				if spec == nil then
					warnOnce(
						"order",
						`[CustomerService] Order rejected by OrderSpec ({reason}): {order.Category}/{order.Item}`
					)
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
				npc.OrderRolled = true
				npc.RolledScriptedFor = if scripted then player.UserId else nil
				self._lastOrder[player] = order
				npc.RequestedDrinkText = Rules.FormatOrderForNotepad(orders, specs)
			end)
			self._rollingOrders[npc] = nil
			if not okRoll then
				warn(`[CustomerService] Order roll failed: {errRoll}`)
				return
			end
		end
	end
	npc:ExtendRegisterPatience(CustomerConfig.REGISTER_TAKE_ORDER_GRACE_SECONDS)
	self._activeOrderingNpc[player] = npc
	local takers = self._orderTakers[npc]
	if takers == nil then
		takers = setmetatable({}, { __mode = "k" }) :: any
		self._orderTakers[npc] = takers
	end
	takers[player] = true

	-- The NPC order always rides in the tablet notepad; the worker punches it
	-- into the ordering pages. No prefill: the scripted first-session tablet
	-- guides the worker through each step instead (Guided).
	self.Client.OpenOrderingTablet:Fire(player, {
		NpcId = npc.Id,
		RequestedText = npc.RequestedDrinkText,
		Orders = npc.Orders,
		Specs = npc.Specs,
		Guided = npc.RolledScriptedFor == player.UserId,
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

	-- The NPC whose tablet this player opened last. AUDIT-FIX submit: when that binding is stale (another
	-- Take Order since, or it was cleared), the NPC with this Id is accepted only if this player pressed
	-- its Take Order (so they saw its order); TAKEOVER-FIX 3's "no blind Id fallback" still holds.
	local npc = self._activeOrderingNpc[player]
	if npc == nil or npc.Id ~= npcId then
		npc = nil
		for candidate in self._npcs do
			local takers = self._orderTakers[candidate]
			if candidate.Id == npcId and takers ~= nil and takers[player] then
				npc = candidate
				break
			end
		end
	end
	if npc == nil or npc.Left or npc.State ~= "AtCounter" then
		return { Success = false, Message = "Customer is no longer waiting at the counter." }
	end
	-- Re-checked at submit: another tablet may have filled the slot since Take Order.
	if self._shift:IsWrappingUp(player) then
		return { Success = false, Message = "Shift complete. Finish your open order to end it." }
	end
	if not self:_hasFreeSlot(player) then
		return { Success = false, Message = "Your order slots are full. Serve a customer first!" }
	end
	local character = player.Character
	local primary = if character ~= nil then character.PrimaryPart else nil
	if primary == nil or (primary.Position - npc.Root.Position).Magnitude > SUBMIT_MAX_DISTANCE_STUDS then
		return { Success = false, Message = "Stand by the customer to place their order." }
	end

	local matches = Rules.ValidateSubmittedOrder(submittedOrderItems, npc.Orders)
	if not matches then
		local isOnboarding = (self:_readServedCount(player) < CustomerConfig.FIRST_SESSION_COUNT)
			or (npc.RolledScriptedFor == player.UserId)

		if isOnboarding then
			return { Success = false, Message = "That doesn't match what the customer asked for!" }
		end

		self:_playAngrySound(npc)
		self:_showAngryEffect(npc)

		local isKaren = npc.Variant == "Karen"
		local regularAttr = npc.Model:GetAttribute("RegularName")
		local isRegular = (typeof(regularAttr) == "string" and #regularAttr > 0)

		npc._wrongAttempts = (npc._wrongAttempts or 0) + 1
		local maxAttempts = if isKaren then 1 else 2

		if not isKaren then
			local remaining = npc:ReduceRegisterPatience(0.25)
			if remaining <= 0 then
				npc._wrongAttempts = maxAttempts
			end
		end

		if (npc._wrongAttempts :: number) >= maxAttempts then
			if isRegular then
				npc._walkoutRatingMult = 1.5
			end
			npc._lastTaker = player
			npc:PlayConfused()
			npc:Leave("WrongOrder")
			return { Success = false, Message = "The customer was fed up and left!" }
		end

		return { Success = false, Message = "That doesn't match what the customer asked for!" }
	end

	-- Dedicated mode ticket generation & assignment
	local scripted = npc.RolledScriptedFor == player.UserId
	local patienceSeconds = Rules.VariantPatience(
		Rules.PatienceSeconds(npc.Orders, nil, if scripted then nil else self:_sessionShiftOf(player)),
		npc.Variant
	)
	npc:SetAssignment(player.UserId, patienceSeconds, scripted)
	self:_issueTicket(player, npc)

	if self._order and typeof(self._order.RegisterCustomerOrder) == "function" then
		local regularName = npc.Model:GetAttribute("RegularName")
		local customerName = if typeof(regularName) == "string" and #regularName > 0 then regularName else "Customer"
		self._order:RegisterCustomerOrder(npc.Id, customerName, #npc.Orders, "Being Prepared", npc.Model)
	end

	-- Free counter spot so next in queue can step up
	self._context.ReleaseCounter(npc)

	-- Claim pickup spot and move NPC there
	local pickupPos, pickupRot = self._context.ClaimPickupSpot(npc)
	for taker, ordering in self._activeOrderingNpc do
		if ordering == npc then
			self._activeOrderingNpc[taker] = nil
			if taker ~= player then
				self.Client.CloseOrderingTablet:Fire(taker)
			end
		end
	end
	local takers = self._orderTakers[npc]
	if takers ~= nil then
		for taker in takers do
			if taker ~= player then
				self.Client.CloseOrderingTablet:Fire(taker)
			end
		end
		self._orderTakers[npc] = nil
	end
	if pickupPos ~= nil then
		npc:GoToPickup(pickupPos, pickupRot)
	else
		npc:GoToPickup()
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
	-- (2) close enough: matches the prompt's MaxActivationDistance (15) so an
	-- offered Serve never fails silently just outside this check.
	local character = player.Character
	local primary = if character ~= nil then character.PrimaryPart else nil
	if primary == nil or (primary.Position - npc.Root.Position).Magnitude > 15 then
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
		-- Wrong-customer handoff QOL: name the correct customer instead of failing silently.
		local correct = self:_heldCustomerName(player, npc)
		if correct ~= nil then
			self._dialog:Notify(player, {
				Title = "Wrong customer",
				Description = `That order is for {correct}!`,
			})
		end
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
		-- AUDIT-FIX D1.3: plain words for the reason ("Wrong size: they wanted Medium").
		self._dialog:Notify(player, {
			Title = "Wrong drink",
			Description = MistakeText.FromSpec(reasons[1], if #npc.Specs == 1 then npc.Specs[1] else nil),
		})
		return
	end
	if grade ~= "Perfect" and grade ~= "Close" then
		return
	end
	-- AUDIT-FIX D1.3: what made a Close serve Close, read before the tools are destroyed.
	local closeText: string? = nil
	if grade == "Close" then
		for index, tool in tools do
			local spec = npc.Specs[index]
			if spec ~= nil then
				local toolGrade, toolReasons = OrderSpec.Match(spec, tool:GetAttributes())
				if toolGrade == "Close" and toolReasons[1] ~= nil then
					closeText = MistakeText.FromSpec(toolReasons[1], spec)
					break
				end
			end
		end
	end
	-- BIG-B7 skill moment: flat pour tip, read before the tools are destroyed (guarded; serve never breaks).
	local pourTip = 0
	local okPour, pourResult = pcall(function()
		return Knit.GetService("KitchenService"):GetPourTip(tools)
	end)
	if okPour and typeof(pourResult) == "number" then
		pourTip = pourResult
	end
	-- The NPC carries the drink only when it may sit with it (TAKEOVER-FIX 5); with seating
	-- off, no clone (and none of the tool's scripts) is made on every serve.
	if self:_seatingOn() and #tools > 0 and npc.Model ~= nil and npc.Model.Parent ~= nil then
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
		a:OnboardingFunnel(player, 4, "FirstOrderServed")
		a:Funnel(player, 4, "FirstServe")

		local servedBefore = self:_readServedCount(player)
		if (servedBefore + 1) >= CustomerConfig.FIRST_SESSION_COUNT then
			a:OnboardingFunnel(player, 5, "OnboardingCompleted")
			a:Funnel(player, 5, "OnboardingCompleted")
		end

		a:Custom(player, "NpcServed", 1)
		a:Custom(player, "ServeSeconds", (npc.Model:GetAttribute("PatienceTotal") or 0) * (1 - fractionLeft))
		a:Custom(player, "PourAccuracy", if grade == "Perfect" then 3 elseif pourTip > 0 then 2 else 1)
	end)
	self._stats:IncrementStat(player, "CustomersServed")
	pcall(function()
		Knit.GetService("LeaderboardService"):IncrementStat(player, "OrdersServed", 1)
	end)
	-- TAKEOVER-REVIEW-FIX P3-8: "Prepare N Boba Drinks" also counts the boba a barista serves, not only pickups.
	local bobaServed = 0
	for _, order in npc.Orders do
		if typeof(order.Item) == "string" and string.find(order.Item, "Boba", 1, true) then
			bobaServed += 1
		end
	end
	-- AdvanceQuest can yield (data, pass lookups); spawned so the serve path never waits on it.
	task.spawn(function()
		pcall(function()
			local quests = Knit.GetService("QuestService")
			quests:AdvanceQuest(player, "CustomersServed", 1)
			if bobaServed > 0 then
				quests:AdvanceQuest(player, "BobaOrdered", bobaServed)
			end
		end)
	end)
	local newCombo = Rules.NextCombo(combo, grade)
	self._combo[player] = newCombo
	local teamDone = self:RecordTeamServe(grade, player)
	local teamChain = self._teamChain
	local isFirstServe = self._firstServe[player] == true and npc.Scripted
	self._firstServe[player] = nil

	local text = `+{pay} · {grade}`
	if closeText ~= nil then
		text ..= ` ({closeText})`
	end
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
	if self._order and typeof(self._order.RemoveCustomerOrder) == "function" then
		self._order:RemoveCustomerOrder(npc.Id)
	end
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

-- True while the player holds an open NPC ticket (ShiftService waits on these before
-- ending a shift; real-order tickets do not hold a shift open).
function CustomerService:HasTicket(player: Player): boolean
	for _, ticket in self._tickets[player] or {} do
		if ticket.Real ~= true then
			return true
		end
	end
	return false
end

-- True while the barista has a free ticket slot (NPC and real tickets share slots).
function CustomerService:HasFreeSlot(player: Player): boolean
	return self:_hasFreeSlot(player)
end

-- OrderService: puts a real-player order in the barista's first free slot as a normal
-- ticket tagged Real ("Real customer" on the HUD). `order` = { Id, CustomerName, Items }.
-- Never yields.
function CustomerService:IssueRealTicket(player: Player, order: { Id: string, CustomerName: string, Items: { any } })
	local held = self._tickets[player]
	if held == nil then
		held = {}
		self._tickets[player] = held
	end
	for slot, ticket in held do
		if ticket.Id == order.Id then
			self:_fireTicket(player, ticket, slot)
			return
		end
	end
	local slot = 1
	while held[slot] ~= nil do
		slot += 1
	end
	local items = {}
	for _, item in order.Items do
		local customInfo = if typeof(item.CustomInfo) == "table" then table.clone(item.CustomInfo) else {}
		table.insert(items, { Category = item.Category, Item = item.Item, CustomInfo = customInfo })
	end
	local first = items[1] or {}
	local ticket = {
		Id = order.Id,
		Real = true,
		CustomerName = order.CustomerName,
		Label = `{order.CustomerName}'s order`,
		Items = items,
		Spec = {
			Category = first.Category,
			Item = first.Item,
			CustomInfo = first.CustomInfo,
			Size = if first.CustomInfo then first.CustomInfo.Size else nil,
		},
		Scripted = false,
		Rescue = false,
		Slot = slot,
	}
	held[slot] = ticket
	self:_fireTicket(player, ticket, slot)
end

-- OrderService: frees the slot a real order held (deposited, released, customer gone).
-- Idempotent; never yields.
function CustomerService:ClearRealTicket(player: Player, ticketId: string)
	local held = self._tickets[player]
	if held == nil then
		return
	end
	for slot, ticket in held do
		if ticket.Id == ticketId then
			held[slot] = nil
			self._idleSince[player] = os.clock()
			self:_fireTicket(player, nil, slot)
			break
		end
	end
	if next(held) == nil then
		self._tickets[player] = nil
		self:_unwatchBaristaInventory(player)
	end
end

-- A slot freed: let OrderService hand a waiting real order out. Deferred, so the serve
-- path (which clears tickets after the payout) never waits on it.
function CustomerService:_dispatchRealOrders()
	task.defer(function()
		local ok, err = pcall(function()
			if self._order ~= nil then
				self._order:DispatchPending()
			end
		end)
		if not ok then
			warnThrottled("dispatch", `[CustomerService] Real-order dispatch failed: {err}`)
		end
	end)
end

---> counter ordering (DEC-059)

local function liveRoot(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root
end

-- True while a counter customer is standing at this NPC counter spot.
function CustomerService:_counterCustomerAtSpot(spot: number): boolean
	for _, state in self._counterCustomers do
		local area = self._counterAreas[state.Area]
		if area ~= nil and area.Spot == spot then
			return true
		end
	end
	return false
end

-- True while an NPC holds, or is queued for, this counter spot.
function CustomerService:_npcAtSpot(spot: number?): boolean
	if spot == nil then
		return false
	end
	local line = self._registerLines[spot]
	return self._counter[spot] ~= nil or (line ~= nil and #line > 0)
end

-- workspace["Ordering System"].CustomerAreas: every BasePart child is one register's
-- customer area. Missing: warn once; counter ordering stays off (phones still work).
function CustomerService:_resolveCounterAreas(): boolean
	local folder = WorldPath.waitFor(workspace, { "Ordering System", "CustomerAreas" }, WORLD_WAIT_SECONDS)
	if folder == nil then
		warn('[CustomerService] workspace["Ordering System"].CustomerAreas missing; counter ordering disabled.')
		return false
	end
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(self._counterAreas, { Part = child, Spot = nil })
		end
	end
	if #self._counterAreas == 0 then
		warn('[CustomerService] workspace["Ordering System"].CustomerAreas has no parts; counter ordering disabled.')
		return false
	end
	return true
end

-- Each area's NPC Counter spot, once the NPC world is known (nearest Counter part in XZ).
function CustomerService:_mapCounterSpots()
	if self._counterSpotsMapped or self._context == nil then
		return
	end
	self._counterSpotsMapped = true
	local positions: { Vector3 } = {}
	for index, part in self._context.Nodes.Counter do
		positions[index] = part.Position
	end
	for _, area in self._counterAreas do
		area.Spot = CounterLock.MatchSpot(area.Part.Position, positions, CounterLock.SPOT_MATCH_STUDS)
	end
end

-- The customer became eligible: a Take Order prompt on them. The server keeps it
-- Enabled; each client hides it for the customer, clocked-out players and every
-- barista but the lock holder (OrderController). The server checks everything again.
function CustomerService:_startCounterCustomer(customer: Player, areaIndex: number)
	local root = liveRoot(customer)
	if root == nil then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = COUNTER_PROMPT_NAME
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Take Order"
	prompt.ObjectText = customer.DisplayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = COUNTER_TAKE_DISTANCE_STUDS
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("CustomerUserId", customer.UserId)
	prompt:SetAttribute("TakerUserId", 0)
	prompt:SetAttribute("BuiltBy", "REVIVAL-001-ORDER-FLOW-REWORK")
	CollectionService:AddTag(prompt, COUNTER_PROMPT_TAG)
	prompt.Triggered:Connect(function(barista: Player)
		local ok, err = pcall(self._onCounterTakeOrder, self, customer, barista)
		if not ok then
			warnThrottled("counterTake", `[CustomerService] Counter Take Order failed: {err}`)
		end
	end)
	prompt.Parent = root
	self._counterCustomers[customer] = { Area = areaIndex, Prompt = prompt, Lock = nil }
end

-- Drops the lock (prompt shows to every barista again). `reason` is told to the taker.
function CustomerService:_releaseCounterLock(customer: Player, reason: string?)
	local state = self._counterCustomers[customer]
	if state == nil or state.Lock == nil then
		return
	end
	local taker = state.Lock.Taker
	state.Lock = nil
	pcall(function()
		state.Prompt:SetAttribute("TakerUserId", 0)
	end)
	if taker ~= nil and taker.Parent ~= nil then
		self.Client.CloseOrderingTablet:Fire(taker)
		if reason ~= nil then
			pcall(function()
				self._dialog:Notify(taker, { Title = "Order cancelled", Description = reason })
			end)
		end
	end
end

-- The customer is no longer a counter customer (moved, ordered, clocked in, left).
function CustomerService:_endCounterCustomer(customer: Player, reason: string?)
	local state = self._counterCustomers[customer]
	if state == nil then
		return
	end
	self:_releaseCounterLock(customer, reason)
	self._counterCustomers[customer] = nil
	pcall(function()
		state.Prompt:Destroy()
	end)
end

-- One counter pass: who stands where, who is eligible, and whether each lock still holds.
-- Never yields.
function CustomerService:_counterTick()
	self:_mapCounterSpots()

	local occupants: { [number]: { Player } } = {}
	for _, player in Players:GetPlayers() do
		if self._shift:IsClockedIn(player) then
			continue
		end
		local root = liveRoot(player)
		if root == nil then
			continue
		end
		for index, area in self._counterAreas do
			if CounterLock.InArea(area.Part.CFrame, area.Part.Size, root.Position, CounterLock.DEPTH_MARGIN) then
				local list = occupants[index]
				if list == nil then
					list = {}
					occupants[index] = list
				end
				table.insert(list, player)
				break
			end
		end
	end

	table.clear(self._realOccupied)
	for index in occupants do
		local spot = self._counterAreas[index].Spot
		if spot ~= nil then
			self._realOccupied[spot] = true
		end
	end

	local eligible: { [Player]: number } = {}
	for index, list in occupants do
		local customer = CounterLock.EligibleCustomer(
			list,
			self:_npcAtSpot(self._counterAreas[index].Spot),
			function(player: Player): boolean
				return self._order:HasOpenOrder(player.UserId)
			end
		)
		if customer ~= nil then
			eligible[customer] = index
		end
	end

	for customer, state in self._counterCustomers do
		if eligible[customer] ~= state.Area or state.Prompt.Parent == nil then
			self:_endCounterCustomer(customer, "The customer left the counter.")
		end
	end
	for customer, index in eligible do
		if self._counterCustomers[customer] == nil then
			self:_startCounterCustomer(customer, index)
		end
	end

	local now = os.clock()
	for customer, state in self._counterCustomers do
		local lock = state.Lock
		if lock == nil then
			continue
		end
		local taker: Player = lock.Taker
		local reason: string? = nil
		if now >= lock.Expires then
			reason = "You took too long to take the order."
		elseif taker.Parent == nil or not self._shift:IsClockedIn(taker) then
			reason = "" -- the taker left or clocked out: nothing to tell
		else
			local takerRoot = liveRoot(taker)
			local customerRoot = liveRoot(customer)
			if
				takerRoot == nil
				or customerRoot == nil
				or (takerRoot.Position - customerRoot.Position).Magnitude > SUBMIT_MAX_DISTANCE_STUDS
			then
				reason = "You moved away from the customer."
			end
		end
		if reason ~= nil then
			self:_releaseCounterLock(customer, if reason ~= "" then reason else nil)
		end
	end
end

function CustomerService:_counterLoop()
	if not self:_resolveCounterAreas() then
		return
	end
	while true do
		local ok, err = pcall(self._counterTick, self)
		if not ok then
			warnThrottled("counter", `[CustomerService] Counter step failed: {err}`)
		end
		task.wait(COUNTER_TICK_SECONDS)
	end
end

-- Take Order on a real customer: the first eligible barista takes the lock.
function CustomerService:_onCounterTakeOrder(customer: Player, barista: Player)
	local state = self._counterCustomers[customer]
	if state == nil or barista == customer then
		return
	end
	if not self:_ensureClockedIn(barista) then
		return
	end
	local baristaRoot = liveRoot(barista)
	local customerRoot = liveRoot(customer)
	if
		baristaRoot == nil
		or customerRoot == nil
		or (baristaRoot.Position - customerRoot.Position).Magnitude > COUNTER_TAKE_DISTANCE_STUDS
	then
		return
	end
	local now = os.clock()
	if not CounterLock.CanTake(state.Lock, barista, now) then
		self._dialog:Notify(barista, {
			Title = "Order taken",
			Description = "Another barista is taking this order.",
		})
		return
	end
	if self._shift:IsWrappingUp(barista) then
		self._dialog:Notify(
			barista,
			{ Title = "Shift complete", Description = "Finish your open order to end the shift." }
		)
		return
	end
	if not self:_hasFreeSlot(barista) then
		self._dialog:Notify(barista, {
			Title = "Slots Full",
			Description = "You already have an active order ticket!",
		})
		return
	end
	-- One counter customer per barista at a time.
	for other, otherState in self._counterCustomers do
		if other ~= customer and otherState.Lock ~= nil and otherState.Lock.Taker == barista then
			self:_releaseCounterLock(other)
		end
	end
	self._counterLockSeq += 1
	state.Lock = CounterLock.Take(barista, self._counterLockSeq, now)
	state.Prompt:SetAttribute("TakerUserId", barista.UserId)

	self.Client.OpenOrderingTablet:Fire(barista, {
		CounterCustomerId = customer.UserId,
		LockId = self._counterLockSeq,
		CustomerName = customer.DisplayName,
		RequestedText = `Ask {customer.DisplayName} what they'd like.`,
	})
end

function CustomerService:_submitCounterOrder(
	player: Player,
	customerUserId: any,
	lockId: any,
	orderItems: any
): { Success: boolean, Message: string? }
	if typeof(customerUserId) ~= "number" or typeof(lockId) ~= "number" or typeof(orderItems) ~= "table" then
		return { Success = false, Message = "Invalid order submission." }
	end
	local now = os.clock()
	local last = self._counterSubmitAt[player]
	if last ~= nil and now - last < COUNTER_SUBMIT_DEBOUNCE_SECONDS then
		return { Success = false, Message = "Please wait a moment." }
	end
	self._counterSubmitAt[player] = now

	local customer = Players:GetPlayerByUserId(customerUserId)
	local state = if customer ~= nil then self._counterCustomers[customer] else nil
	if customer == nil or state == nil then
		return { Success = false, Message = "The customer is no longer at the counter." }
	end
	if not CounterLock.Holds(state.Lock, player, lockId, now) then
		return { Success = false, Message = "This order isn't yours to take anymore." }
	end
	if not self._shift:IsClockedIn(player) then
		return { Success = false, Message = "You must be clocked in." }
	end
	local takerRoot = liveRoot(player)
	local customerRoot = liveRoot(customer)
	if
		takerRoot == nil
		or customerRoot == nil
		or (takerRoot.Position - customerRoot.Position).Magnitude > SUBMIT_MAX_DISTANCE_STUDS
	then
		return { Success = false, Message = "Stand by the customer to place their order." }
	end
	-- Still standing at their register, with no NPC there (the last tick is at most 0.3 s old).
	local area = self._counterAreas[state.Area]
	if
		area == nil
		or not CounterLock.InArea(area.Part.CFrame, area.Part.Size, customerRoot.Position, CounterLock.DEPTH_MARGIN)
		or self:_npcAtSpot(area.Spot)
	then
		return { Success = false, Message = "The customer is no longer at the counter." }
	end

	local result = self._order:CreateCounterOrder(player, customer, orderItems)
	if typeof(result) == "table" and result.Success == true then
		self:_endCounterCustomer(customer)
	end
	return result
end

function CustomerService.Client:SubmitCounterOrder(player: Player, customerUserId: any, lockId: any, orderItems: any)
	return self.Server:_submitCounterOrder(player, customerUserId, lockId, orderItems)
end

-- The taker closed the tablet. Only the lock with this Id is released, so a stale
-- tablet closing after a newer Take Order changes nothing.
function CustomerService.Client:CancelCounterOrder(player: Player, customerUserId: any, lockId: any)
	if typeof(customerUserId) ~= "number" or typeof(lockId) ~= "number" then
		return
	end
	local server = self.Server
	local customer = Players:GetPlayerByUserId(customerUserId)
	local state = if customer ~= nil then server._counterCustomers[customer] else nil
	if state ~= nil and state.Lock ~= nil and state.Lock.Taker == player and state.Lock.Id == lockId then
		server:_releaseCounterLock(customer)
	end
end

-- A floating "+N" over the NPC for 1.5 s. Styles tokens only (DEC-013).
function CustomerService:_showServePay(npc: Npc.Npc, pay: number, grade: Rules.ServeGrade)
	local head = npc.Model:FindFirstChild("Head")
	if head == nil then
		return
	end
	-- UI-REVISION: appears where the (now hidden) order card was, under the leaving
	-- line, then rises a stud and a half and fades, like the pour feedback.
	local startOffset = Vector3.new(0, 3.5, 0)
	local gui = Instance.new("BillboardGui")
	gui.Name = "ServePay"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(120, 40)
	gui.StudsOffset = startOffset
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
	local rise = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local fade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1)
	TweenService:Create(gui, rise, { StudsOffset = startOffset + Vector3.new(0, 1.5, 0) }):Play()
	TweenService:Create(payLabel, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(payStroke, fade, { Transparency = 1 }):Play()
	task.delay(1.5, function()
		pcall(function()
			gui:Destroy()
		end)
	end)
end

function CustomerService:_playAngrySound(npc: Npc.Npc)
	pcall(function()
		local template = WorldPath.find(SoundService, { "SFX", "Angry" })
		if template == nil or not template:IsA("Sound") then
			return
		end
		local anchor = npc.Root
			or (npc.Model and npc.Model:FindFirstChild("HumanoidRootPart"))
			or (npc.Model and npc.Model:FindFirstChild("Head"))
		if anchor == nil or not anchor:IsA("BasePart") then
			return
		end
		local sound = template:Clone()
		sound.Parent = anchor
		sound:Play()
		task.delay(math.max(sound.TimeLength, 3), function()
			pcall(function()
				sound:Destroy()
			end)
		end)
	end)
end

function CustomerService:_showAngryEffect(npc: Npc.Npc)
	pcall(function()
		local head = npc.Model and npc.Model:FindFirstChild("Head")
		local anchor = if head ~= nil and head:IsA("BasePart") then head else npc.Root
		if anchor == nil then
			return
		end
		local startOffset = Vector3.new(0, 3.5, 0)
		local gui = Instance.new("BillboardGui")
		gui.Name = "AngryEffect"
		gui.Adornee = anchor
		gui.Size = UDim2.fromOffset(60, 60)
		gui.StudsOffset = startOffset
		gui.AlwaysOnTop = true
		gui.MaxDistance = 80

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.Text = "💢"
		label.Parent = gui
		gui.Parent = npc.Model

		local rise = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local fade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1)
		TweenService:Create(gui, rise, { StudsOffset = startOffset + Vector3.new(0, 1.5, 0) }):Play()
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		task.delay(1.5, function()
			pcall(function()
				gui:Destroy()
			end)
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
				if typeof(holder) ~= "Instance" or holder:IsDescendantOf(Players) then
					self._idleSince[holder] = os.clock()
				end
				self:_fireTicket(holder, nil, slot)
				self:_dispatchRealOrders() -- a waiting real order may take the freed slot
				self:_dispatchUnassignedNpcs() -- an unassigned pickup NPC may take the freed slot
				-- Deferred so the serve's CustomerResolved is recorded before a due shift ends.
				task.defer(function()
					pcall(self._shift.Recheck, self._shift, holder)
				end)
				break
			end
		end
		if next(held) == nil then
			self._tickets[holder] = nil
			self:_unwatchBaristaInventory(holder)
		end
	end
end

-- The holder clocked out or left: frees every slot they held and hands each NPC to
-- the next free barista. Patience keeps running (PatienceEnd unchanged).
function CustomerService:_releaseTicket(player: Player)
	self._activeOrderingNpc[player] = nil
	local held: { Npc.Npc } = {}
	for waiting, holder in self._assignee do
		if holder == player then
			table.insert(held, waiting)
		end
	end
	for _, npc in held do
		npc:ClearAssignment()
		self:_clearTicket(npc)
		self:_handOff(npc, player)
	end
end

-- Walkouts clear the ticket and reset the combo (design 3.4, 4.8). A served
-- or despawned NPC only frees the slot. Never stops the pacing thread.
function CustomerService:_onCustomerLeft(npc: Npc.Npc, reason: string)
	if self._order and typeof(self._order.RemoveCustomerOrder) == "function" then
		self._order:RemoveCustomerOrder(npc.Id)
	end
	if self._context ~= nil then
		self._context.ReleasePickupSpot(npc)
	end

	-- Auto-close ordering UI for any barista currently serving this customer
	for taker, ordering in self._activeOrderingNpc do
		if ordering == npc then
			self._activeOrderingNpc[taker] = nil
			self.Client.CloseOrderingTablet:Fire(taker)
		end
	end
	local takers = self._orderTakers[npc]
	if takers ~= nil then
		for taker in takers do
			self.Client.CloseOrderingTablet:Fire(taker)
		end
		self._orderTakers[npc] = nil
	end

	if reason ~= "PatienceOut" and reason ~= "WrongOrder" then
		self:_clearTicket(npc)
		return
	end
	self:RecordTeamServe(nil) -- any walkout breaks the server-wide chain, assigned or not
	local holder = self._assignee[npc] or npc._lastTaker
	self:_clearTicket(npc)
	local ratingMult = npc._walkoutRatingMult or 1
	if holder == nil then
		-- Nobody held it (register walkout or orphan): the cafe rating still drops (TAKEOVER-FIX 2).
		pcall(function()
			self.CustomerResolved:Fire(
				nil,
				{ Kind = "Walkout", Pay = 0, Fast = false, Combo = 0, RatingMultiplier = ratingMult }
			)
		end)
		return
	end
	self._combo[holder] = 0
	pcall(function()
		Knit.GetService("AnalyticsEvents"):Custom(holder, "NpcTimeout", 1)
	end)
	self._dialog:Notify(holder, { Title = "Customer left", Description = "Customer left. Combo lost." })
	pcall(function()
		self.CustomerResolved:Fire(
			holder,
			{ Kind = "Walkout", Pay = 0, Fast = false, Combo = 0, RatingMultiplier = ratingMult }
		)
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

	-- Counter ordering does not need the NPC world (it maps register spots once it exists).
	task.spawn(self._counterLoop, self)

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
				self:_dispatchUnassignedNpcs()
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
	self:_unwatchBaristaInventory(player)
	self._counterSubmitAt[player] = nil
	self._clockInPromptOpen[player] = nil
	pcall(function()
		self:_endCounterCustomer(player)
		for customer, state in self._counterCustomers do
			if state.Lock ~= nil and state.Lock.Taker == player then
				self:_releaseCounterLock(customer)
			end
		end
	end)
	self._activeOrderingNpc[player] = nil
	self._firstServe[player] = nil
	self._sessionShifts[player] = nil
	self._idleSince[player] = nil
	self._combo[player] = nil
	self._lastOrder[player] = nil
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
	-- Real-order tickets are released by OrderService; drop whatever is left.
	self._tickets[player] = nil
	self._idleSince[player] = nil
end

return CustomerService

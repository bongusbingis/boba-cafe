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

	PENDING JACK (nothing built): Q1 assignment and Rescue, Q2 where to serve, Q4 the
	first-session script, Q5/Q6 payout, Q25 the NPC look.
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
local OrderSpec = require(Shared.Ordering.OrderSpec)
local WorldPath = require(Shared.Utility.WorldPath)
local Npc = require(script.Npc)
local Rules = require(script.Rules)

---> constants

local WORLD_WAIT_SECONDS = 10 -- total budget for resolving the authored world in KnitStart
local PACING_TICK_SECONDS = 1
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
	Client = {},

	-- Server-side signal: fires (npc: Npc.Npc, reason: string) once per NPC when it stops waiting.
	CustomerLeft = GoodSignal.new(),

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
	if self._npcCount >= Rules.PacingTarget(self._baristas) then
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

	local npc = Npc.new(context, order, spec, Rules.PatienceSeconds({ order }))
	if npc == nil then
		return
	end
	self._npcs[npc] = true
	self._npcCount += 1
	table.insert(self._line, npc)
	npc:Start()
end

function CustomerService:_pacingLoop()
	while true do
		self._baristas = self:_countBaristas()
		local ok, err = pcall(self._spawnIfNeeded, self)
		if not ok then
			warnOnce("pacing", `[CustomerService] Pacing step failed: {err}`)
		end
		task.wait(PACING_TICK_SECONDS)
	end
end

---> lifecycle

function CustomerService:KnitStart()
	self._shift = Knit.GetService("ShiftService")

	local nodes = self:_resolveNodes()
	if nodes == nil or not self:_setUpCollisionGroups() then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = CUSTOMERS_FOLDER_NAME
	folder.Parent = workspace
	self._context = self:_makeContext(nodes, folder)
	self.Enabled = true

	-- Players who joined while the world was being resolved.
	for _, player in Players:GetPlayers() do
		self:_watchPlayer(player)
	end
	task.spawn(self._pacingLoop, self)
end

function CustomerService:PlayerAdded(player: Player)
	if self.Enabled then
		self:_watchPlayer(player)
	end
end

function CustomerService:PlayerRemoving(player: Player)
	local connection = self._characterConnections[player]
	if connection ~= nil then
		connection:Disconnect()
		self._characterConnections[player] = nil
	end
end

return CustomerService

--!strict
--[[
	Npc
	One NPC customer (REVIVAL-001 M1.4d): the model, its order bubble, and the walk
	Entry -> Path -> Queue -> Counter -> Exit. CustomerService owns the line and the
	counter spots and hands them in through the Context table.

	Lifecycle (State attribute): Walking -> Queued -> Walking -> AtCounter -> Leaving.
	Patience starts when the NPC reaches its counter spot and ticks down through the
	`PatienceEnd` (server time) and `PatienceTotal` attributes. It pauses while nobody
	is clocked in. When it runs out the NPC just leaves: no penalty, no payout.

	Not here yet (PENDING JACK Q1/Q2/Q4/Q5): assignment, Serve prompt, payout.
--]]

---> services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies

local Shared = ReplicatedStorage:WaitForChild("Shared")
local OrderSpec = require(Shared.Ordering.OrderSpec)
local Styles = require(Shared.UI.Styles)
local Rules = require(script.Parent.Rules)

---> types

export type State = "Walking" | "Queued" | "AtCounter" | "Leaving"

-- The authored world contract, resolved by CustomerService. Path, Queue and Counter
-- are in numeric order; Queue[1] is the front of the line.
export type Nodes = {
	Entry: BasePart,
	Exit: BasePart,
	Path: { BasePart },
	Queue: { BasePart },
	Counter: { BasePart },
}

-- What an NPC needs from CustomerService. All of these run on the server thread
-- without yielding.
export type Context = {
	Nodes: Nodes,
	Parent: Instance, -- folder the NPC models live in
	QueueIndex: (npc: Npc) -> number, -- 1 = front of the line
	TryTakeCounter: (npc: Npc) -> number?, -- a counter spot, only for the front NPC when one is free
	Release: (npc: Npc) -> (), -- free the NPC's place in line and its counter spot
	IsPaused: () -> boolean, -- true while nobody is clocked in
	OnLeft: (npc: Npc, reason: string) -> (), -- the NPC stopped waiting (once)
	OnDestroyed: (npc: Npc) -> (),
}

type NpcFields = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Order: Rules.OrderItem, -- the assigned order, as picked from the pool
	Spec: OrderSpec.OrderSpec, -- Order resolved by OrderSpec.FromOrderItem
	State: State,
	PatienceTotal: number,
	CounterSpot: number?,
	Left: boolean, -- true once the NPC stopped waiting
	_ctx: Context,
	_bar: Frame,
	_patienceEnd: number,
	_fallbacks: number, -- PivotTo fallbacks in a row
	_destroyed: boolean,
}

---> constants

local BUILT_BY = "REVIVAL-001-M1.4core"
local SEGMENT_TIMEOUT_SECONDS = 6 -- a walk that takes longer is finished with PivotTo (design 4.1)
local MAX_FALLBACKS_IN_A_ROW = 3 -- then the NPC is despawned (design 4.8)
local ARRIVE_RADIUS_STUDS = 3 -- close enough counts as arrived when MoveToFinished is late
local WALK_POLL_SECONDS = 0.1
local WAIT_POLL_SECONDS = 0.25 -- queue shuffling and patience updates
local ROOT_HEIGHT_STUDS = 3 -- default R15 root part centre above the floor
local BUBBLE_SIZE = UDim2.fromOffset(200, 64)
local BUBBLE_OFFSET = Vector3.new(0, 3.5, 0) -- above the head
local BUBBLE_MAX_DISTANCE_STUDS = 80

---> private

local buildWarned = false

-- PENDING JACK Q25: NPC look. This is a plain default R15 rig until Jack decides
-- how customers look. Returns nil (after one warning) when the rig cannot be built.
local function buildNpcModel(): Model?
	local description = Instance.new("HumanoidDescription")
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()

	local model = if ok and typeof(result) == "Instance" and result:IsA("Model") then result else nil
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	if model == nil or humanoid == nil or model.PrimaryPart == nil then
		if not buildWarned then
			buildWarned = true
			warn(`[CustomerService] Could not build the NPC rig; no customers will spawn until it works: {result}`)
		end
		return nil
	end

	model.Name = "Customer"
	model:SetAttribute("BuiltBy", BUILT_BY)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	return model
end

-- "Medium Custom Boba", plus a second line for the flavour so the order can be read.
local function describeOrder(spec: OrderSpec.OrderSpec): string
	local details: { string } = {}
	if spec.Syrup ~= nil then
		table.insert(details, spec.Syrup)
	end
	if spec.Tapioca ~= nil then
		table.insert(details, spec.Tapioca .. " tapioca")
	end
	if spec.Iced == true then
		table.insert(details, "Iced")
	end
	if spec.Sugar == true then
		table.insert(details, "Sugar")
	end
	if #details == 0 then
		return spec.Label
	end
	return spec.Label .. "\n" .. table.concat(details, ", ")
end

-- The order label with a patience bar under it. Returns the bar's fill frame.
local function buildBubble(model: Model, spec: OrderSpec.OrderSpec): Frame
	local gui = Instance.new("BillboardGui")
	gui.Name = "OrderBubble"
	gui.Adornee = model:FindFirstChild("Head") or model.PrimaryPart
	gui.Size = BUBBLE_SIZE
	gui.StudsOffset = BUBBLE_OFFSET
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = BUBBLE_MAX_DISTANCE_STUDS

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Styles.CREAM
	card.BorderSizePixel = 0
	card.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Styles.CORNER_BUTTON
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Styles.GREEN
	stroke.Thickness = 2
	stroke.Parent = card

	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(8, 4)
	label.Size = UDim2.new(1, -16, 1, -24)
	label.BackgroundTransparency = 1
	label.FontFace = Styles.FONT_FREDOKA
	label.TextColor3 = Styles.GREEN_DEEP
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = describeOrder(spec)
	label.Parent = card

	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 8, 1, -16)
	track.Size = UDim2.new(1, -16, 0, 8)
	track.BackgroundColor3 = Styles.GRAY
	track.BorderSizePixel = 0
	track.Parent = card

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = Styles.CORNER_FULL
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Styles.GREEN
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = Styles.CORNER_FULL
	fillCorner.Parent = fill

	gui.Parent = model
	return fill
end

local PATIENCE_COLORS = {
	Green = Styles.GREEN,
	Yellow = Styles.GOLD_MID,
	Red = Styles.RED,
}

---> public

local Npc = {}
Npc.__index = Npc

-- Collision group NPC parts are in. CustomerService registers it and keeps it from
-- colliding with players.
Npc.COLLISION_GROUP = "NPC"

export type Npc = typeof(setmetatable({} :: NpcFields, Npc))

-- Builds an NPC for `order` (a pool order item) and its resolved `spec`. Yields while
-- the rig is built. Returns nil when the rig could not be built. Call Start to send
-- it on its way.
function Npc.new(ctx: Context, order: Rules.OrderItem, spec: OrderSpec.OrderSpec, patienceSeconds: number): Npc?
	local model = buildNpcModel()
	if model == nil then
		return nil
	end

	local root = model.PrimaryPart :: BasePart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = Npc.COLLISION_GROUP
		end
	end
	model:SetAttribute("PatienceTotal", patienceSeconds)

	local fields: NpcFields = {
		Model = model,
		Humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		Root = root,
		Order = order,
		Spec = spec,
		State = "Walking",
		PatienceTotal = patienceSeconds,
		CounterSpot = nil,
		Left = false,
		_ctx = ctx,
		_bar = buildBubble(model, spec),
		_patienceEnd = 0,
		_fallbacks = 0,
		_destroyed = false,
	}
	return setmetatable(fields, Npc)
end

function Npc.Start(self: Npc)
	task.spawn(function()
		local ok, err = pcall(Npc._run, self)
		if not ok and not self._destroyed then
			warn(`[CustomerService] NPC despawned: {err}`)
		end
		self:Destroy()
	end)
end

-- The NPC stops waiting: it frees its spots and CustomerService is told once with
-- the reason ("PatienceOut" or "Despawned"). Does not walk or destroy; _run does.
function Npc.Leave(self: Npc, reason: string)
	if self.Left then
		return
	end
	self.Left = true
	self:_setState("Leaving")
	self._ctx.Release(self)
	self._ctx.OnLeft(self, reason)
end

-- Idempotent. An NPC destroyed before it finished leaving counts as "Despawned".
function Npc.Destroy(self: Npc)
	if self._destroyed then
		return
	end
	self:Leave("Despawned")
	self._destroyed = true
	self.Model:Destroy()
	self._ctx.OnDestroyed(self)
end

function Npc._setState(self: Npc, state: State)
	self.State = state
	self.Model:SetAttribute("State", state)
end

-- Walks to `target` with MoveTo. After SEGMENT_TIMEOUT_SECONDS the NPC is moved
-- straight there with PivotTo; MAX_FALLBACKS_IN_A_ROW of those in a row is an error
-- (Start despawns the NPC).
function Npc._walkTo(self: Npc, target: BasePart)
	local goal = target.Position
	local finished = false
	local reached = false
	local connection = self.Humanoid.MoveToFinished:Connect(function(didReach: boolean)
		finished = true
		reached = didReach
	end)

	self.Humanoid:MoveTo(goal)
	local deadline = os.clock() + SEGMENT_TIMEOUT_SECONDS
	while not finished and os.clock() < deadline and not self._destroyed do
		task.wait(WALK_POLL_SECONDS)
	end
	connection:Disconnect()
	if self._destroyed then
		return
	end

	local flatOffset = (self.Root.Position - goal) * Vector3.new(1, 0, 1)
	if reached or flatOffset.Magnitude <= ARRIVE_RADIUS_STUDS then
		self._fallbacks = 0
		return
	end

	-- Stalled: move the NPC to the node and let it drop to the floor.
	self._fallbacks += 1
	local lifted = goal + Vector3.new(0, ROOT_HEIGHT_STUDS, 0)
	self.Model:PivotTo(CFrame.new(lifted) * self.Model:GetPivot().Rotation)
	if self._fallbacks >= MAX_FALLBACKS_IN_A_ROW then
		error(`stuck: {self._fallbacks} walks in a row needed PivotTo (last target {target:GetFullName()})`)
	end
end

function Npc._setPatienceBar(self: Npc, fractionLeft: number)
	local fraction = math.clamp(fractionLeft, 0, 1)
	self._bar.Size = UDim2.fromScale(fraction, 1)
	self._bar.BackgroundColor3 = PATIENCE_COLORS[Rules.PatienceState(fraction)]
end

-- Ticks patience down until it runs out or the NPC is made to leave.
function Npc._waitOutPatience(self: Npc)
	self._patienceEnd = workspace:GetServerTimeNow() + self.PatienceTotal
	self.Model:SetAttribute("PatienceEnd", self._patienceEnd)

	local last = os.clock()
	while self.State == "AtCounter" and not self._destroyed do
		task.wait(WAIT_POLL_SECONDS)
		local now = os.clock()
		if self._ctx.IsPaused() then
			self._patienceEnd += now - last
			self.Model:SetAttribute("PatienceEnd", self._patienceEnd)
		end
		last = now

		local remaining = self._patienceEnd - workspace:GetServerTimeNow()
		self:_setPatienceBar(remaining / self.PatienceTotal)
		if remaining <= 0 then
			return
		end
	end
end

function Npc._run(self: Npc)
	local ctx = self._ctx
	local nodes = ctx.Nodes

	-- Spawn at Entry, in its orientation.
	local entry = nodes.Entry
	self.Model:PivotTo(CFrame.new(entry.Position + Vector3.new(0, ROOT_HEIGHT_STUDS, 0)) * entry.CFrame.Rotation)
	self.Model.Parent = ctx.Parent
	pcall(function()
		self.Root:SetNetworkOwner(nil) -- server owns the physics
	end)

	for _, node in nodes.Path do
		self:_walkTo(node)
	end

	-- Wait in line. The front NPC takes the next free counter spot; everyone else
	-- walks forward to the queue spot for their place.
	self:_setState("Queued")
	local spot: number? = nil
	local standingAt = 0
	while spot == nil and not self._destroyed do
		local index = math.min(ctx.QueueIndex(self), #nodes.Queue)
		spot = ctx.TryTakeCounter(self)
		if spot ~= nil then
			break
		elseif standingAt ~= index then
			self:_walkTo(nodes.Queue[index])
			standingAt = index
		else
			task.wait(WAIT_POLL_SECONDS)
		end
	end
	if spot == nil then
		return
	end

	self.CounterSpot = spot
	self:_setState("Walking")
	local counter = nodes.Counter[spot]
	self:_walkTo(counter)
	-- Counter parts face the kitchen; the customer faces the same way.
	self.Model:PivotTo(CFrame.new(self.Model:GetPivot().Position) * counter.CFrame.Rotation)
	self:_setState("AtCounter")

	self:_waitOutPatience()
	self:Leave("PatienceOut")
	self:_walkTo(nodes.Exit)
end

return Npc

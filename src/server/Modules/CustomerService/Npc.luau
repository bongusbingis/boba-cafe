--!strict
--[[
	Npc
	One NPC customer (REVIVAL-001 M1.4d): the model, its order bubble, and the walk
	Entry -> Path -> Queue -> Counter -> Exit. CustomerService owns the line and the
	counter spots and hands them in through the Context table.

	Lifecycle (State attribute): Walking -> Queued -> Walking -> AtCounter -> Walking
	-> AtPickup -> Leaving.
	Three clocks, all paused while nobody is clocked in (TAKEOVER-FIX 2):
	- line: QUEUE_PATIENCE_SECONDS in the queue, then a quiet "LineGaveUp" leave;
	- register: the order's patience (same ramp) times REGISTER_PATIENCE_MULT at the
	  counter, then a "PatienceOut" walkout; "Take Order" grants a grace floor;
	- pickup: `PatienceEnd` (server time) / `PatienceTotal`, then "PatienceOut".

	Assignment, the Serve prompt and payout live here too (REVIVAL-001 M1.4e).
--]]

---> services

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> dependencies

local Shared = ReplicatedStorage:WaitForChild("Shared")
local OrderSpec = require(Shared.Ordering.OrderSpec)
local Styles = require(Shared.UI.Styles)
local Rules = require(script.Parent.Rules)
local Recipes = require(Shared.Kitchen.Recipes)
local CustomerDialogue = require(Shared.Configuration.CustomerDialogue)
local CustomerConfig = require(Shared.Configuration.CustomerConfig)
local SeatingConfig = require(Shared.Configuration.SeatingConfig)
local WorldPath = require(Shared.Utility.WorldPath)

---> types

export type State = "Walking" | "Queued" | "AtCounter" | "AtPickup" | "Leaving"

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
	Release: (npc: Npc) -> (), -- free the NPC's place in line, counter spot, and pickup spot
	ReleaseCounter: (npc: Npc) -> (), -- free only the counter spot (called on order submit)
	ClaimPickupSpot: (npc: Npc) -> BasePart?, -- claim an open spot at the pickup counter
	ReleasePickupSpot: (npc: Npc) -> (),
	IsPaused: () -> boolean, -- true while nobody is clocked in
	RegisterPatience: (npc: Npc) -> number, -- seconds the NPC waits at the register for its order to be taken
	OnLeft: (npc: Npc, reason: string) -> (), -- the NPC stopped waiting (once)
	OnAtCounter: (npc: Npc) -> (), -- the NPC reached its counter spot (greeting prompt)
	OnAtPickup: (npc: Npc) -> (), -- the NPC reached its pickup spot (serve prompt)
	OnDestroyed: (npc: Npc) -> (),
	TryClaimSeat: (npcId: string, originPos: Vector3, maxDist: number?) -> Seat?,
	ReleaseSeat: (seat: Seat, npcId: string) -> (),
}

export type BubbleUI = {
	Fill: Frame,
	Track: Frame,
	Chip: Frame,
	Label: TextLabel,
	Detail: TextLabel,
	Card: Frame,
}

type NpcFields = {
	Id: string,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Order: Rules.OrderItem, -- the assigned order, as picked from the pool
	Spec: OrderSpec.OrderSpec, -- Order resolved by OrderSpec.FromOrderItem
	Orders: { Rules.OrderItem }, -- every item of the NPC's order (Order is Orders[1])
	Specs: { OrderSpec.OrderSpec }, -- Orders resolved (Spec is Specs[1])
	LabelText: string, -- the item labels joined, for the prompt and speech
	Variant: Rules.Variant?, -- "VIP" or "Karen" (nil = normal)
	State: State,
	PatienceTotal: number,
	CounterSpot: number?,
	PickupSpot: BasePart?,
	RequestedDrinkText: string?,
	OrderRolled: boolean, -- the register order is fixed once the first "Take Order" rolls it (TAKEOVER-FIX 3)
	RolledScriptedFor: number?, -- UserId whose first-session script the rolled order is (nil = pool order)
	AssignedUserId: number?, -- the barista holding this NPC's ticket (nil while unassigned)
	Scripted: boolean, -- first-session order: patience does not tick, serve is always Fast
	Rescue: boolean, -- served by a non-assignee below RESCUE_FRACTION (set by CustomerService)
	Left: boolean, -- true once the NPC stopped waiting
	LeftReason: string?,
	Thanked: boolean?,
	_ctx: Context,
	_bar: Frame,
	_bubbleUI: BubbleUI?,
	_patienceEnd: number,
	_registerEnd: number, -- os.clock() deadline at the register (0 = not at the register)
	_fallbacks: number, -- PivotTo fallbacks in a row
	_destroyed: boolean,
	_tracks: { [string]: AnimationTrack },
	_speechToken: number,
}

---> constants

local BUILT_BY = "REVIVAL-001-M1.4core"
local SEGMENT_TIMEOUT_SECONDS = 6 -- a walk that takes longer is finished with PivotTo (design 4.1)
local MAX_FALLBACKS_IN_A_ROW = 3 -- then the NPC is despawned (design 4.8)
local ARRIVE_RADIUS_STUDS = 3 -- close enough counts as arrived when MoveToFinished is late
local WALK_POLL_SECONDS = 0.1
local WAIT_POLL_SECONDS = 0.25 -- queue shuffling and patience updates
local ROOT_HEIGHT_STUDS = 3 -- default R15 root part centre above the floor
-- UI-REVISION: the gui is tall enough for the speech card over the order card; the
-- order card keeps its 200 x 64 footprint at the bottom.
local BUBBLE_CARD_H = 64
local BUBBLE_SPEECH_H = 34
local BUBBLE_SIZE = UDim2.fromOffset(200, BUBBLE_CARD_H + BUBBLE_SPEECH_H + 6)
local BUBBLE_PAD = 8
local BUBBLE_TOP = 6
local BUBBLE_CHIP = 12
local BUBBLE_TITLE_H = 22
local BUBBLE_DETAIL_H = 16
local BUBBLE_TRACK_H = 6
local BUBBLE_OFFSET = Vector3.new(0, 3.5, 0) -- above the head
-- Lifts the gui so the order card's centre (not the gui's) sits on BUBBLE_OFFSET.
local BUBBLE_SIZE_OFFSET = Vector2.new(0, (BUBBLE_SPEECH_H + 6) / 2 / (BUBBLE_CARD_H + BUBBLE_SPEECH_H + 6))
local BUBBLE_MAX_DISTANCE_STUDS = 80

-- S9-SPARKLE: Perfect-serve burst, reusing the authored CleanlinessStorage.Sparkles
-- (same Emit count as Spill). Never build a substitute.
local SPARKLE_COUNT = 30
local SPARKLE_CLEANUP_SECONDS = 3
local sparkleWarned = false
local registerPatienceWarned = false

---> private

local SPEECH_SECONDS = 3
local ASSET_TIMEOUT_SECONDS = 5
local ANIMATION_NAMES = { "Wave", "Confused", "Idle" }

local buildWarned = false
local descriptions: { HumanoidDescription }? = nil -- SharedStorage.NPCs.Characters, resolved once
local animations: { [string]: Animation }? = nil -- SharedStorage.NPCStorage.Animations, resolved once
local assetWarned = false

local function warnAssetsOnce(message: string)
	if not assetWarned then
		assetWarned = true
		warn(`[CustomerService] {message}`)
	end
end

-- Looks up the imported look and animations once (yields the first time only).
local function resolveAssets()
	if descriptions ~= nil and animations ~= nil then
		return
	end
	local sharedStorage = ReplicatedStorage:FindFirstChild("SharedStorage")
	local looks: { HumanoidDescription } = {}
	local folder = WorldPath.waitFor(sharedStorage, { "NPCs", "Characters" }, ASSET_TIMEOUT_SECONDS)
	if folder ~= nil then
		for _, child in folder:GetChildren() do
			if child:IsA("HumanoidDescription") then
				table.insert(looks, child)
			end
		end
	end
	-- BIG-B5: a stable order so a regular's look index always names the same description.
	table.sort(looks, function(a, b)
		return a.Name < b.Name
	end)
	if #looks == 0 then
		warnAssetsOnce("SharedStorage.NPCs.Characters has no HumanoidDescription; customers use the default body.")
	end
	descriptions = looks

	local found: { [string]: Animation } = {}
	local animFolder = WorldPath.find(sharedStorage, { "NPCStorage", "Animations" })
	if animFolder ~= nil then
		for _, name in ANIMATION_NAMES do
			local animation = animFolder:FindFirstChild(name)
			if animation ~= nil and animation:IsA("Animation") then
				found[name] = animation
			end
		end
	end
	animations = found
end

-- Karen's imported look (SharedStorage.NPCStorage.Karen), or nil after one warning.
local karenWarned = false
local function karenDescription(): HumanoidDescription?
	local sharedStorage = ReplicatedStorage:FindFirstChild("SharedStorage")
	local found = WorldPath.find(sharedStorage, { "NPCStorage", "Karen" })
	if found ~= nil and found:IsA("HumanoidDescription") then
		return found
	end
	if not karenWarned then
		karenWarned = true
		warn("[CustomerService] SharedStorage.NPCStorage.Karen is missing; Karens use a normal NPC look.")
	end
	return nil
end

-- BIG-B5 regulars: a fixed look. `Base` indexes the name-sorted pool (wrapping); every
-- `Description` entry is a HumanoidDescription property set on top. 0 and "" are TODO
-- placeholders and are skipped. One bad property is skipped, never fatal.
export type Look = { Base: number, Description: { [string]: any }? }

local function lookDescription(pool: { HumanoidDescription }, look: Look): HumanoidDescription
	local description = if #pool > 0
		then pool[((math.floor(look.Base) - 1) % #pool) + 1]:Clone()
		else Instance.new("HumanoidDescription")
	for property, value in look.Description or {} do
		if value == 0 or value == "" then
			continue
		end
		pcall(function()
			(description :: any)[property] = value
		end)
	end
	return description
end

-- A random HumanoidDescription from SharedStorage.NPCs (Karen's own for the Karen variant),
-- or an empty one (the default body) when there are none. `look` (BIG-B5 regulars) builds a
-- fixed description instead (lookDescription). Returns nil (after one warning) when the rig
-- cannot be built.
local function buildNpcModel(variant: Rules.Variant?, look: Look?): Model?
	resolveAssets()
	local pool = descriptions or {}
	local description: HumanoidDescription
	local karen = if variant == "Karen" then karenDescription() else nil
	if karen ~= nil then
		description = karen:Clone()
	elseif look ~= nil then
		description = lookDescription(pool, look)
	elseif #pool > 0 then
		description = pool[math.random(#pool)]:Clone()
	else
		description = Instance.new("HumanoidDescription")
	end
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
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false) -- a Path that brushes a Seat must not sit the NPC
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	return model
end

-- The flavour line under the item name ("Classic Milk Tea · Normal tapioca"), or "".
local function describeDetails(spec: OrderSpec.OrderSpec): string
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
	return table.concat(details, " · ")
end

-- Bubble title and detail line. One item: its name, flavour underneath. More than one
-- item: the names, one per line, no detail line.
local function describeOrders(specs: { OrderSpec.OrderSpec }, variant: Rules.Variant?): (string, string)
	local title: string
	local detail = ""
	if #specs == 1 then
		title = specs[1].Label
		detail = describeDetails(specs[1])
	else
		local labels: { string } = {}
		for _, spec in specs do
			table.insert(labels, spec.Label)
		end
		title = table.concat(labels, "\n")
	end
	if variant == "VIP" then
		title = "VIP " .. title
	end
	return title, detail
end

local function joinLabels(specs: { OrderSpec.OrderSpec }): string
	local labels: { string } = {}
	for _, spec in specs do
		table.insert(labels, spec.Label)
	end
	return table.concat(labels, " + ")
end

-- The syrup colour of a boba order, the coffee colour for coffee, GRAY for Grab.
-- No new colour tokens (DEC-013).
local function chipColor(spec: OrderSpec.OrderSpec): Color3
	if spec.Syrup ~= nil then
		return Recipes.Syrups[spec.Syrup] or Styles.GRAY
	elseif spec.Kind == "Grab" then
		return Styles.GRAY
	end
	return Color3.fromRGB(204, 161, 135) -- coffee
end

local function addCorner(parent: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

local function addTextLimit(parent: TextLabel, minSize: number, maxSize: number)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = minSize
	limit.MaxTextSize = maxSize
	limit.Parent = parent
end

-- UI-REVISION: places the bubble's pieces for what it is showing. `chip` = a syrup
-- chip leads the title; `detail` = a flavour line sits under the title. Pixel layout
-- in a 200 x 64 card (billboards are offset-sized, STYLE 4.5).
local function layoutBubble(bubble: BubbleUI, chip: boolean, detail: boolean)
	local left = if chip then BUBBLE_PAD + BUBBLE_CHIP + 6 else BUBBLE_PAD
	local titleHeight = if detail then BUBBLE_TITLE_H else BUBBLE_TITLE_H + BUBBLE_DETAIL_H
	bubble.Chip.Visible = chip
	bubble.Chip.Position = UDim2.fromOffset(BUBBLE_PAD, BUBBLE_TOP + (titleHeight - BUBBLE_CHIP) // 2)
	bubble.Label.Position = UDim2.fromOffset(left, BUBBLE_TOP)
	bubble.Label.Size = UDim2.new(1, -(left + BUBBLE_PAD), 0, titleHeight)
	bubble.Label.TextXAlignment = if chip then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
	bubble.Detail.Visible = detail
	bubble.Detail.Position = UDim2.fromOffset(left, BUBBLE_TOP + BUBBLE_TITLE_H)
	bubble.Detail.Size = UDim2.new(1, -(left + BUBBLE_PAD), 0, BUBBLE_DETAIL_H)
end

-- The order card with a patience bar under it, and the speech bubble above it.
-- Returns the bubble UI components. Contract (RegularsService, KitchenController,
-- Npc._say): the gui is "OrderBubble", the card is "Card" and its only direct
-- TextLabel is the title, the speech line is the gui's "Speech" TextLabel.
local function buildBubble(model: Model, specs: { OrderSpec.OrderSpec }, variant: Rules.Variant?): BubbleUI
	local spec = specs[1]
	local gui = Instance.new("BillboardGui")
	gui.Name = "OrderBubble"
	gui.Adornee = model:FindFirstChild("Head") or model.PrimaryPart
	gui.Size = BUBBLE_SIZE
	gui.StudsOffset = BUBBLE_OFFSET
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = BUBBLE_MAX_DISTANCE_STUDS
	gui.SizeOffset = BUBBLE_SIZE_OFFSET

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0, 1)
	card.Position = UDim2.fromScale(0, 1)
	card.Size = UDim2.new(1, 0, 0, BUBBLE_CARD_H)
	card.BackgroundColor3 = if variant == "VIP" then Styles.GOLD else Styles.CREAM
	card.BorderSizePixel = 0
	card.Parent = gui
	addCorner(card, Styles.CORNER_BUTTON)

	local stroke = Instance.new("UIStroke")
	stroke.Color = if variant == "VIP" then Styles.GOLD_DEEP else Styles.GREEN
	stroke.Thickness = 2
	stroke.Parent = card

	local chip = Instance.new("Frame")
	chip.Name = "SyrupChip"
	chip.Size = UDim2.fromOffset(BUBBLE_CHIP, BUBBLE_CHIP)
	chip.BackgroundColor3 = chipColor(spec)
	chip.BorderSizePixel = 0
	chip.Parent = card
	addCorner(chip, Styles.CORNER_FULL)

	-- Light syrups (milk tea, taro) vanish on CREAM without an outline.
	local chipStroke = Instance.new("UIStroke")
	chipStroke.Color = Styles.GREEN_DEEP
	chipStroke.Thickness = 1
	chipStroke.Parent = chip

	local title, detailText = describeOrders(specs, variant)

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.FontFace = Styles.FONT_FREDOKA
	label.TextColor3 = Styles.GREEN_DEEP
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = title
	label.Parent = card
	addTextLimit(label, 9, 20)

	-- The flavour line lives one level down so the title stays Card's only TextLabel.
	local detailHolder = Instance.new("Frame")
	detailHolder.Name = "DetailHolder"
	detailHolder.BackgroundTransparency = 1
	detailHolder.Size = UDim2.fromScale(1, 1)
	detailHolder.Parent = card

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.FontFace = Styles.FONT_FREDOKA
	detail.TextColor3 = Styles.GREEN_DEEP
	detail.TextTransparency = 0.3
	detail.TextScaled = true
	detail.TextWrapped = true
	detail.TextXAlignment = Enum.TextXAlignment.Left
	detail.Text = detailText
	detail.Parent = detailHolder
	addTextLimit(detail, 8, 13)

	local track = Instance.new("Frame")
	track.Name = "Patience"
	track.Position = UDim2.new(0, BUBBLE_PAD, 1, -(BUBBLE_TRACK_H + 6))
	track.Size = UDim2.new(1, -2 * BUBBLE_PAD, 0, BUBBLE_TRACK_H)
	track.BackgroundColor3 = Styles.GRAY
	track.BorderSizePixel = 0
	track.Parent = card
	addCorner(track, Styles.CORNER_FULL)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Styles.GREEN
	fill.BorderSizePixel = 0
	fill.Parent = track
	addCorner(fill, Styles.CORNER_FULL)

	-- What the customer says (Greeting / WrongOrder / Leaving): its own small card with
	-- the same chrome, floating above the order card.
	local speech = Instance.new("TextLabel")
	speech.Name = "Speech"
	speech.Visible = false
	speech.AnchorPoint = Vector2.new(0.5, 1)
	speech.Position = UDim2.new(0.5, 0, 1, -(BUBBLE_CARD_H + 6))
	speech.Size = UDim2.new(1, -16, 0, BUBBLE_SPEECH_H)
	speech.BackgroundColor3 = Styles.CREAM
	speech.BorderSizePixel = 0
	speech.FontFace = Styles.FONT_FREDOKA
	speech.TextColor3 = Styles.GREEN_DEEP
	speech.TextScaled = true
	speech.TextWrapped = true
	speech.Text = ""
	speech.Parent = gui
	addCorner(speech, Styles.CORNER_BUTTON)
	addTextLimit(speech, 9, 15)

	local speechStroke = Instance.new("UIStroke")
	speechStroke.Color = Styles.GREEN
	speechStroke.Thickness = 2
	speechStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	speechStroke.Parent = speech

	local speechPadding = Instance.new("UIPadding")
	speechPadding.PaddingLeft = UDim.new(0, 6)
	speechPadding.PaddingRight = UDim.new(0, 6)
	speechPadding.PaddingTop = UDim.new(0, 3)
	speechPadding.PaddingBottom = UDim.new(0, 3)
	speechPadding.Parent = speech

	local bubble: BubbleUI = {
		Fill = fill,
		Track = track,
		Chip = chip,
		Label = label,
		Detail = detail,
		Card = card,
	}
	layoutBubble(bubble, true, detailText ~= "")

	gui.Parent = model
	return bubble
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

local npcSeq = 0

-- Builds an NPC for `order` (a pool order item) and its resolved `spec`. Yields while
-- the rig is built. Returns nil when the rig could not be built. Call Start to send
-- it on its way. `look` (optional, BIG-B5) fixes the appearance for a named regular; if that
-- rig cannot be built the NPC falls back to the normal random look.
function Npc.new(
	ctx: Context,
	order: Rules.OrderItem,
	spec: OrderSpec.OrderSpec,
	patienceSeconds: number,
	variant: Rules.Variant?,
	look: Look?
): Npc?
	local model: Model? = nil
	if look ~= nil then
		local ok, built = pcall(buildNpcModel, variant, look)
		model = if ok then built else nil
	end
	if model == nil then
		model = buildNpcModel(variant)
	end
	if model == nil then
		return nil
	end
	npcSeq += 1
	local id = `Customer_{npcSeq}`
	model.Name = id
	model:SetAttribute("Variant", variant)

	local root = model.PrimaryPart :: BasePart
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = Npc.COLLISION_GROUP
		end
	end
	model:SetAttribute("PatienceTotal", patienceSeconds)

	local bubble = buildBubble(model, { spec }, variant)
	local fields: NpcFields = {
		Id = id,
		Model = model,
		Humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		Root = root,
		Order = order,
		Spec = spec,
		Orders = { order },
		Specs = { spec },
		LabelText = spec.Label,
		Variant = variant,
		State = "Walking",
		PatienceTotal = patienceSeconds,
		CounterSpot = nil,
		PickupSpot = nil,
		RequestedDrinkText = nil,
		OrderRolled = false,
		RolledScriptedFor = nil,
		AssignedUserId = nil,
		Scripted = false,
		Rescue = false,
		Left = false,
		LeftReason = nil,
		Thanked = nil,
		_ctx = ctx,
		_bar = bubble.Fill,
		_bubbleUI = bubble,
		_patienceEnd = 0,
		_registerEnd = 0,
		_fallbacks = 0,
		_destroyed = false,
		_tracks = {},
		_speechToken = 0,
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
function Npc.Leave(self: Npc, reason: string, grade: string?)
	if self.Left then
		return
	end
	self.Left = true
	self.LeftReason = reason
	local thanked = reason == "Served" and (self.Variant ~= "Karen" or grade == "Perfect")
	self.Thanked = thanked
	self:_setState("Leaving")
	self:_stopTrack("Idle")
	if reason ~= "Despawned" then
		if thanked then
			self:_playTrack("Wave", false, Enum.AnimationPriority.Action)
		end
		-- UI-REVISION: the order and its patience bar are over; only the leaving line
		-- (and the "+N BB" popup, which takes the card's spot) stay above the head.
		local bubble = self._bubbleUI
		if bubble ~= nil then
			bubble.Card.Visible = false
		end
		self:_say(if thanked then "LeavingServed" else "Leaving")
	end
	if grade == "Perfect" then
		-- S9-SPARKLE: burst the shared Sparkles emitter at the NPC head.
		-- Synchronous: FindFirstChild only, no yield, no new thread.
		-- A missing template is skipped with one warning; never substituted.
		local template = WorldPath.find(ReplicatedStorage, { "SharedStorage", "CleanlinessStorage", "Sparkles" })
		local head = self.Model:FindFirstChild("Head")
		local anchor = if head ~= nil and head:IsA("BasePart") then head else self.Root
		if template ~= nil and template:IsA("ParticleEmitter") and anchor ~= nil then
			local burst = template:Clone() :: ParticleEmitter
			burst.Parent = anchor
			burst:Emit(SPARKLE_COUNT)
			Debris:AddItem(burst, SPARKLE_CLEANUP_SECONDS)
		elseif not sparkleWarned then
			sparkleWarned = true
			warn(
				"[CustomerService] CleanlinessStorage.Sparkles missing or not a ParticleEmitter; Perfect sparkle skipped."
			)
		end
	end
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
	for _, child in self.Model:GetChildren() do
		if child:IsA("Tool") then
			child:Destroy()
		end
	end
	self.Model:Destroy()
	self._ctx.OnDestroyed(self)
end

-- Swaps the NPC's order (first-session script or a re-roll) and rebuilds the
-- bubble for it. The Serve prompt lives on the root part, so it is kept.
function Npc.SetOrder(self: Npc, order: Rules.OrderItem, spec: OrderSpec.OrderSpec)
	self:SetOrders({ order }, { spec })
end

-- Same for a list of items (multi-item orders). The lists must be the same length and not empty.
function Npc.SetOrders(self: Npc, orders: { Rules.OrderItem }, specs: { OrderSpec.OrderSpec })
	self.Order = orders[1]
	self.Spec = specs[1]
	self.Orders = orders
	self.Specs = specs
	self.LabelText = joinLabels(specs)
	local old = self.Model:FindFirstChild("OrderBubble")
	if old ~= nil then
		old:Destroy()
	end
	local bubble = buildBubble(self.Model, specs, self.Variant)
	self._bubbleUI = bubble
	self._bar = bubble.Fill
	if self.State == "AtCounter" then
		self:ShowGreetingBubble()
	elseif self.State == "AtPickup" then
		self:ShowOrderBubble()
	end
end

function Npc.ShowGreetingBubble(self: Npc)
	local bubble = self._bubbleUI
	if bubble == nil then
		return
	end
	layoutBubble(bubble, false, false)
	bubble.Track.Visible = true -- register patience shows on the same bar (TAKEOVER-FIX 2)
	bubble.Label.Text = "Hi, can I order?"
	self:_setPatienceBar(1)
end

-- "Take Order": the register clock never ends sooner than `seconds` from now.
function Npc.ExtendRegisterPatience(self: Npc, seconds: number)
	if self.State ~= "AtCounter" or self._registerEnd <= 0 then
		return
	end
	self._registerEnd = math.max(self._registerEnd, os.clock() + seconds)
end

function Npc.ShowOrderBubble(self: Npc)
	local bubble = self._bubbleUI
	if bubble == nil then
		return
	end
	local title, detail = describeOrders(self.Specs, self.Variant)
	layoutBubble(bubble, true, detail ~= "")
	bubble.Track.Visible = true
	bubble.Chip.BackgroundColor3 = chipColor(self.Spec)
	bubble.Label.Text = title
	bubble.Detail.Text = detail
	self:_setPatienceBar(1)
end

function Npc.GoToPickup(self: Npc, pickupSpot: BasePart)
	self.PickupSpot = pickupSpot
	self:_setState("Walking")
end

function Npc.StartPatience(self: Npc)
	if self.PatienceTotal <= 0 then
		self.PatienceTotal = CustomerConfig.PATIENCE_BASE_SECONDS
	end
	self._patienceEnd = workspace:GetServerTimeNow() + self.PatienceTotal
	self.Model:SetAttribute("PatienceTotal", self.PatienceTotal)
	self.Model:SetAttribute("PatienceEnd", self._patienceEnd)
end

-- Assigns the NPC to a barista (dedicated mode).
function Npc.SetAssignment(self: Npc, userId: number, patienceSeconds: number, scripted: boolean)
	self.AssignedUserId = userId
	self.Scripted = scripted
	self.PatienceTotal = patienceSeconds
	self.Model:SetAttribute("PatienceTotal", patienceSeconds)
	self.Model:SetAttribute("AssignedUserId", userId)
end

-- Scripted first-session NPCs are always normal: drops the variant (the look stays).
function Npc.ClearVariant(self: Npc)
	self.Variant = nil
	self.Model:SetAttribute("Variant", nil)
end

-- Moves the ticket to another barista. The patience clock keeps running
-- (PatienceEnd unchanged, design 4.3).
function Npc.Reassign(self: Npc, userId: number)
	self.AssignedUserId = userId
	self.Model:SetAttribute("AssignedUserId", userId)
end

-- Drops the assignment without touching the clock: the NPC waits for the next
-- barista with a free slot while its patience keeps running.
function Npc.ClearAssignment(self: Npc)
	self.AssignedUserId = nil
	self.Model:SetAttribute("AssignedUserId", nil)
end

-- Fraction of patience left (1 = full, 0 = out). Unassigned NPCs count as full.
function Npc.FractionLeft(self: Npc): number
	if self._patienceEnd <= 0 or self.PatienceTotal <= 0 then
		return 1
	end
	return (self._patienceEnd - workspace:GetServerTimeNow()) / self.PatienceTotal
end

-- Plays the imported animation `name` on the NPC's Animator. Missing animations are
-- skipped silently (no substitutes); never errors.
function Npc._playTrack(self: Npc, name: string, looped: boolean, priority: Enum.AnimationPriority)
	pcall(function()
		local animation = if animations ~= nil then animations[name] else nil
		if animation == nil or self._destroyed then
			return
		end
		local track = self._tracks[name]
		if track == nil then
			local animator = self.Humanoid:FindFirstChildOfClass("Animator")
			if animator == nil then
				animator = Instance.new("Animator")
				animator.Parent = self.Humanoid
			end
			track = (animator :: Animator):LoadAnimation(animation)
			track.Looped = looped
			track.Priority = priority
			self._tracks[name] = track
		end
		(track :: AnimationTrack):Play()
	end)
end

function Npc._stopTrack(self: Npc, name: string)
	pcall(function()
		local track = self._tracks[name]
		if track ~= nil then
			track:Stop()
		end
	end)
end

-- Called by CustomerService on a Wrong serve.
function Npc.PlayConfused(self: Npc)
	self:_playTrack("Confused", false, Enum.AnimationPriority.Action)
end

-- Shows one random line of `kind` from CustomerDialogue (Karen's pool for Karens, else Default) in the bubble for
-- SPEECH_SECONDS. Greeting lines hold a %s for the drink name.
function Npc._say(self: Npc, kind: string)
	pcall(function()
		local pool = if self.Variant == "Karen" then CustomerDialogue.Karen else CustomerDialogue.Default
		local lines = (pool :: any)[kind]
		local gui = self.Model:FindFirstChild("OrderBubble")
		local speech = if gui ~= nil then gui:FindFirstChild("Speech") else nil
		if lines == nil or #lines == 0 or speech == nil then
			return
		end
		local line: string = lines[math.random(#lines)]
		line = line:gsub("%%s", function()
			return self.LabelText
		end)
		self._speechToken += 1
		local token = self._speechToken;
		(speech :: TextLabel).Text = line;
		(speech :: TextLabel).Visible = true
		task.delay(SPEECH_SECONDS, function()
			if self._speechToken == token and speech.Parent ~= nil then
				(speech :: TextLabel).Visible = false
			end
		end)
	end)
end

-- Called by CustomerService on a Wrong serve.
function Npc.SayWrong(self: Npc)
	self:_say("WrongOrder")
end

function Npc._setState(self: Npc, state: State)
	self.State = state
	self.Model:SetAttribute("State", state)
end

-- Walks to `target` with MoveTo. After SEGMENT_TIMEOUT_SECONDS the NPC is moved
-- straight there with PivotTo; MAX_FALLBACKS_IN_A_ROW of those in a row is an error
-- (Start despawns the NPC).
function Npc._walkTo(self: Npc, target: BasePart | Vector3)
	local goal = if typeof(target) == "Vector3" then target else target.Position
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
		local targetName = if typeof(target) == "Vector3" then tostring(target) else target:GetFullName()
		error(`stuck: {self._fallbacks} walks in a row needed PivotTo (last target {targetName})`)
	end
end

function Npc._setPatienceBar(self: Npc, fractionLeft: number)
	local fraction = math.clamp(fractionLeft, 0, 1)
	self._bar.Size = UDim2.fromScale(fraction, 1)
	self._bar.BackgroundColor3 = PATIENCE_COLORS[Rules.PatienceState(fraction)]
end

-- Ticks patience down until it runs out or the NPC is made to leave.
function Npc._waitOutPatience(self: Npc)
	local last = os.clock()
	local confusedPlayed = false
	while self.State == "AtPickup" and not self._destroyed and not self.Left do
		task.wait(WAIT_POLL_SECONDS)
		local now = os.clock()
		if self._patienceEnd > 0 and self._ctx.IsPaused() then
			self._patienceEnd += now - last
			self.Model:SetAttribute("PatienceEnd", self._patienceEnd)
		end
		last = now

		if self.Scripted or self._patienceEnd <= 0 then
			self:_setPatienceBar(1)
		else
			local remaining = self._patienceEnd - workspace:GetServerTimeNow()
			self:_setPatienceBar(remaining / self.PatienceTotal)
			if not confusedPlayed and Rules.PatienceState(remaining / self.PatienceTotal) ~= "Green" then
				confusedPlayed = true
				self:PlayConfused()
			end
			if remaining <= 0 then
				return
			end
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
	local lineLeft = CustomerConfig.QUEUE_PATIENCE_SECONDS
	local lineLast = os.clock()
	while spot == nil and not self._destroyed and not self.Left do
		local qIndex = ctx.QueueIndex(self)
		spot = ctx.TryTakeCounter(self)
		local lineNow = os.clock()
		if not ctx.IsPaused() then
			lineLeft -= lineNow - lineLast
		end
		lineLast = lineNow
		if spot ~= nil then
			break
		elseif lineLeft <= 0 then
			-- Gave up in line (TAKEOVER-FIX 2): quiet, no walkout. Clears a Rush backlog.
			self:Leave("LineGaveUp")
			break
		elseif standingAt ~= qIndex then
			if qIndex <= #nodes.Queue then
				self:_walkTo(nodes.Queue[qIndex])
				standingAt = qIndex
			else
				local last = nodes.Queue[#nodes.Queue]
				local prev = nodes.Queue[math.max(1, #nodes.Queue - 1)]
				local dir = if last and prev
					then (last.Position - prev.Position) * Vector3.new(1, 0, 1)
					else Vector3.new(-1, 0, 0)
				local dirUnit = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(-1, 0, 0)
				local overflowIndex = qIndex - #nodes.Queue
				local offsetGoal = last.Position + dirUnit * (overflowIndex * 2.8)
				self:_walkTo(offsetGoal)
				standingAt = qIndex
			end
		else
			task.wait(WAIT_POLL_SECONDS)
		end
	end
	if spot == nil then
		if self.Left and not self._destroyed then
			self:_walkTo(nodes.Exit)
		end
		return
	end

	self.CounterSpot = spot
	self:_setState("Walking")
	local counter = nodes.Counter[spot]
	self:_walkTo(counter)
	-- Counter parts face the kitchen; the customer faces the same way.
	self.Model:PivotTo(CFrame.new(self.Model:GetPivot().Position) * counter.CFrame.Rotation)
	self:_setState("AtCounter")
	self:ShowGreetingBubble()
	self:_playTrack("Wave", false, Enum.AnimationPriority.Action)
	self:_playTrack("Idle", true, Enum.AnimationPriority.Idle)

	local ok, err = pcall(self._ctx.OnAtCounter, self)
	if not ok then
		warn(`[CustomerService] NPC OnAtCounter failed: {err}`)
	end

	-- Register patience (TAKEOVER-FIX 2): the NPC waits for its order to be taken and
	-- submitted (which moves it to pickup); if nobody does, it walks out unhappy.
	-- Guarded: a context without RegisterPatience (a server that loaded a mismatched
	-- CustomerService, seen in Studio as "Npc:884: attempt to call a nil value") or a
	-- throwing callback used to despawn every NPC reaching the counter. Fall back instead.
	local registerTotal = CustomerConfig.PATIENCE_BASE_SECONDS * CustomerConfig.REGISTER_PATIENCE_MULT
	local okPatience, seconds = pcall(ctx.RegisterPatience, self)
	if okPatience and typeof(seconds) == "number" and seconds == seconds and seconds < math.huge then
		registerTotal = seconds
	elseif not registerPatienceWarned then
		registerPatienceWarned = true
		warn(`[CustomerService] RegisterPatience failed; using the base patience: {seconds}`)
	end
	registerTotal = math.max(1, registerTotal)
	self._registerEnd = os.clock() + registerTotal
	local registerLast = os.clock()
	while self.State == "AtCounter" and not self._destroyed and not self.Left do
		task.wait(WAIT_POLL_SECONDS)
		local now = os.clock()
		if ctx.IsPaused() then
			self._registerEnd += now - registerLast
		end
		registerLast = now
		if self.State ~= "AtCounter" or self.Left then
			break
		end
		local remaining = self._registerEnd - now
		self:_setPatienceBar(remaining / registerTotal)
		if remaining <= 0 then
			self:Leave("PatienceOut")
			break
		end
	end
	self._registerEnd = 0
	if self._destroyed then
		return
	end
	if self.Left then
		self:_walkTo(nodes.Exit)
		return
	end

	-- Walk from register to open pickup spot under workspace["Ordering System"]["Pick Up"]
	if self.PickupSpot ~= nil then
		self:_walkTo(self.PickupSpot)
		self.Model:PivotTo(CFrame.new(self.Model:GetPivot().Position) * self.PickupSpot.CFrame.Rotation)
	end

	-- Arrive at Pick Up: patience starts ticking down here, overhead shows order icons and bar
	self:_setState("AtPickup")
	self:ShowOrderBubble()
	self:StartPatience()

	local okPickup, errPickup = pcall(self._ctx.OnAtPickup, self)
	if not okPickup then
		warn(`[CustomerService] NPC OnAtPickup failed: {errPickup}`)
	end

	self:_waitOutPatience()
	self:Leave("PatienceOut")

	-- BIG-B4: living cafe seating for served customers
	-- B4SeatingForce is a Studio-only test switch (TAKEOVER-FIX 5); live servers follow ENABLED.
	local seatingForced = RunService:IsStudio() and workspace:GetAttribute("B4SeatingForce") == true
	local seatingOn = SeatingConfig.ENABLED or seatingForced
	if self.LeftReason == "Served" and self.Thanked and seatingOn and math.random() <= SeatingConfig.SIT_CHANCE then
		local seat = self._ctx.TryClaimSeat(self.Id, self.Root.Position, SeatingConfig.SEAT_MAX_DISTANCE_STUDS)
		if seat ~= nil then
			local prompt = self.Root:FindFirstChildOfClass("ProximityPrompt")
			if prompt ~= nil then
				prompt:Destroy()
			end
			self.Model:SetAttribute("PromptAction", nil)
			local bubble = self.Model:FindFirstChild("OrderBubble")
			if bubble ~= nil then
				local card = bubble:FindFirstChild("Card")
				if card ~= nil and card:IsA("GuiObject") then
					card.Visible = false
				end
			end

			self:_walkTo(seat)
			if seat.Occupant == nil and not self._destroyed then
				self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
				seat:Sit(self.Humanoid)

				local sitDuration = math.random(SeatingConfig.SIT_SECONDS_MIN, SeatingConfig.SIT_SECONDS_MAX)
				local deadline = os.clock() + sitDuration
				while os.clock() < deadline and not self._destroyed do
					task.wait(SeatingConfig.SEATED_POLL_SECONDS)
					if seat.Occupant ~= self.Humanoid then
						break
					end
				end

				self.Humanoid.Sit = false
				self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
			end

			for _, child in self.Model:GetChildren() do
				if child:IsA("Tool") then
					child:Destroy()
				end
			end
			self._ctx.ReleaseSeat(seat, self.Id)
		end
	end

	self:_walkTo(nodes.Exit)
end

return Npc

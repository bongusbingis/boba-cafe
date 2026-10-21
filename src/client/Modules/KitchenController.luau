---> Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local CustomerConfig = require(Shared.Configuration.CustomerConfig)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local WorldPath = require(Shared.Utility.WorldPath)
local OrderSpec = require(Shared.Ordering.OrderSpec)
local Styles = require(Shared.UI.Styles)
local KitchenGuidance = require(script.Parent.KitchenGuidance)

---> Constants

local INSTANT_BREW_HOLD_DURATION = 0.5
local INSTANT_BREW_PASS_NAME = "Instant Brew"
local KITCHEN_TIMEOUT_SECONDS = 30

local STATION_HINTS_SETTING = "SyrupHighlighting" -- key kept so no profile migration; label is "Station hints"
local CLOCKED_IN_ATTRIBUTE = "ClockedIn" -- owned by the server's ShiftService
local HIGHLIGHT_NAME = "StationHint"
local BEAM_NAME = "StationHintBeam"
local BEAM_ATTACHMENT_NAME = "StationHintAttachment"
local TOAST_COOLDOWN_SECONDS = 1.5
local RESCUE_BROADCAST_STUDS = 40
local RESCUE_TOAST_COOLDOWN_SECONDS = 20
local IMPATIENT_TEXT = "Your customer is getting impatient!"

-- TUNING
local GUIDANCE_INTERVAL_SECONDS = 0.2 -- how often the hint target is recomputed
local HIGHLIGHT_FILL_TRANSPARENCY = 0.65
local BEAM_WIDTH = 0.35
local BEAM_TRANSPARENCY = 0.35

---> Controller

local KitchenController = Knit.CreateController({
	Name = "KitchenController",
})

local function applyInstantBrew(kitchenFolder: Instance)
	for _, descendant in kitchenFolder:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant.HoldDuration = INSTANT_BREW_HOLD_DURATION
		end
	end

	kitchenFolder.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			descendant.HoldDuration = INSTANT_BREW_HOLD_DURATION
		end
	end)
end

---> Station hints (M1.5c/d)

type GuidanceRuntime = {
	Enabled: boolean,
	Index: { [string]: { Model } },
	Highlights: { Highlight },
	Beam: Beam?,
	BeamAttachments: { Attachment },
	LastKey: string?,
	LastChange: number,
	CustomersSeen: number,
	SeenItems: { [string]: boolean },
	CurrentOrder: any,
	Current: KitchenGuidance.Guidance?,
	LastToast: { [string]: number },
}

local runtime: GuidanceRuntime = {
	Enabled = true,
	Index = {},
	Highlights = {},
	Beam = nil,
	BeamAttachments = {},
	LastKey = nil,
	LastChange = os.clock(),
	CustomersSeen = 0,
	SeenItems = {},
	CurrentOrder = nil,
	Current = nil,
	LastToast = {},
}

local function toast(text: string)
	local ok, err = pcall(function()
		Knit.GetController("DialogController"):Toast(text)
	end)
	if not ok then
		warn("[KitchenController] Toast failed: " .. tostring(err))
	end
end

local function heldToolAttributes(): { [string]: any }?
	local character = Players.LocalPlayer.Character
	local tool = character and character:FindFirstChildWhichIsA("Tool")
	if tool == nil then
		return nil
	end
	return tool:GetAttributes()
end

local function isClockedOut(): boolean
	return Players.LocalPlayer:GetAttribute(CLOCKED_IN_ATTRIBUTE) == false
end

-- The model a hint points at: its PrimaryPart (set by the server's PromptBuilder) or any part.
local function anchorPart(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function indexModel(model: Model)
	local list = runtime.Index[model.Name]
	if list == nil then
		list = {}
		runtime.Index[model.Name] = list
	end
	if not table.find(list, model) then
		table.insert(list, model)
	end
end

local function unindexModel(model: Model)
	local list = runtime.Index[model.Name]
	local at = list and table.find(list, model)
	if list and at then
		table.remove(list, at)
	end
end

local function nearestModel(name: string, origin: Vector3): Model?
	local list = runtime.Index[name]
	if list == nil then
		return nil
	end
	local points: { Vector3 } = {}
	local models: { Model } = {}
	for _, model in list do
		if model:IsDescendantOf(workspace) then
			table.insert(points, model:GetPivot().Position)
			table.insert(models, model)
		end
	end
	local index = KitchenGuidance.NearestIndex(points, origin)
	return if index then models[index] else nil
end

local function clearVisuals()
	for _, highlight in runtime.Highlights do
		highlight.Adornee = nil
		highlight.Enabled = false
	end
	if runtime.Beam then
		runtime.Beam.Enabled = false
	end
end

local function getHighlight(slot: number): Highlight
	local existing = runtime.Highlights[slot]
	if existing and existing.Parent then
		return existing
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = HIGHLIGHT_NAME
	highlight.FillColor = Styles.GOLD
	highlight.OutlineColor = Styles.GOLD_DEEP
	highlight.FillTransparency = HIGHLIGHT_FILL_TRANSPARENCY
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = workspace
	runtime.Highlights[slot] = highlight
	return highlight
end

local function showBeam(rootPart: BasePart, target: BasePart)
	local beam = runtime.Beam
	if beam == nil or beam.Parent == nil then
		beam = Instance.new("Beam")
		beam.Name = BEAM_NAME
		beam.Color = ColorSequence.new(Styles.GOLD)
		beam.Width0 = BEAM_WIDTH
		beam.Width1 = BEAM_WIDTH
		beam.Transparency = NumberSequence.new(BEAM_TRANSPARENCY)
		beam.FaceCamera = true
		beam.LightEmission = 0.5
		beam.Segments = 20
		beam.Parent = workspace
		runtime.Beam = beam
	end
	local beamRef = beam :: Beam

	local from = rootPart:FindFirstChild(BEAM_ATTACHMENT_NAME)
	if from == nil then
		from = Instance.new("Attachment")
		from.Name = BEAM_ATTACHMENT_NAME
		from.Parent = rootPart
	end
	local to = target:FindFirstChild(BEAM_ATTACHMENT_NAME)
	if to == nil then
		to = Instance.new("Attachment")
		to.Name = BEAM_ATTACHMENT_NAME
		to.Parent = target
	end
	beamRef.Attachment0 = from :: Attachment
	beamRef.Attachment1 = to :: Attachment
	beamRef.Enabled = true
end

-- Tracks "customers seen" (distinct orders) and held-tool changes for the idle timer.
local function trackProgress(guidance: KitchenGuidance.Guidance?, order: any)
	if order ~= runtime.CurrentOrder then
		runtime.CurrentOrder = order
		if order ~= nil then
			runtime.CustomersSeen += 1
			runtime.LastChange = os.clock()
		end
	end
	local key = if guidance then `{guidance.Item}:{guidance.Current}` else nil
	if key ~= runtime.LastKey then
		runtime.LastKey = key
		runtime.LastChange = os.clock()
	end
end

local function guidanceStep(serveTarget: Model?)
	local player = Players.LocalPlayer
	local OrderController = Knit.GetController("OrderController")
	local order = OrderController.CurrentOrder
	local spec = KitchenGuidance.ResolveSpec(order, OrderSpec.FromOrderItem)
	local guidance = KitchenGuidance.Compute(spec, heldToolAttributes())
	runtime.Current = guidance
	trackProgress(guidance, order)

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not runtime.Enabled or guidance == nil or isClockedOut() or not rootPart or not rootPart:IsA("BasePart") then
		clearVisuals()
		return
	end

	local target: Model? = nil
	if guidance.IsServe then
		-- The assigned NPC. Which model that is comes from the M1.4f ticket (see evidence).
		target = serveTarget
	elseif guidance.Station then
		target = nearestModel(guidance.Station, rootPart.Position)
	end

	-- Never more than MAX_HIGHLIGHTS; today one hint target uses one slot.
	for slot = 1, KitchenGuidance.MAX_HIGHLIGHTS do
		local highlight = getHighlight(slot)
		if slot == 1 and target then
			highlight.Adornee = target
			highlight.Enabled = true
		else
			highlight.Adornee = nil
			highlight.Enabled = false
		end
	end

	local targetPart = target and anchorPart(target)
	local beamAllowed = KitchenGuidance.ShouldShowBeam({
		CustomersSeen = runtime.CustomersSeen,
		ItemSeenBefore = runtime.SeenItems[guidance.Item] == true,
		IdleSeconds = os.clock() - runtime.LastChange,
	})
	if targetPart and beamAllowed then
		showBeam(rootPart, targetPart)
	elseif runtime.Beam then
		runtime.Beam.Enabled = false
	end
	-- "First time each item appears": the item counts as seen once its first order is done
	-- (the held tool leaves the chain), so the beam stays for the whole first order.
	if guidance.IsServe then
		runtime.SeenItems[guidance.Item] = true
	end
end

local function resolveServeTarget(): Model?
	-- The NPC ticket carries the assigned NPC as NpcModel (M1.4e ticket table).
	local order = Knit.GetController("OrderController").CurrentOrder
	if typeof(order) == "table" then
		local value = (order :: any).NpcModel
		if typeof(value) == "Instance" and value:IsA("Model") then
			return value
		end
	end
	return nil
end

local impatientToasted: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local wasRescuable: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local lastRescueToastAt = -math.huge
local patienceCuesWarned = false

local function patienceFraction(model: Model): number
	local patienceEnd = model:GetAttribute("PatienceEnd")
	local total = model:GetAttribute("PatienceTotal")
	if typeof(patienceEnd) == "number" and typeof(total) == "number" and total > 0 then
		return (patienceEnd - workspace:GetServerTimeNow()) / total
	end
	return 1
end

-- C1 (own customer turns red) and C3 (nearby rescuable customer) toasts. Client-only.
local function runPatienceCues(model: Model, root: BasePart, fraction: number, clockedIn: boolean)
	local localPlayer = Players.LocalPlayer
	local assigned = model:GetAttribute("AssignedUserId")
	local atCounter = model:GetAttribute("State") == "AtCounter"

	-- C1
	if
		assigned == localPlayer.UserId
		and atCounter
		and fraction <= CustomerConfig.PATIENCE_RED_FRACTION
		and fraction > 0
		and not impatientToasted[model]
	then
		local scripted = false
		if resolveServeTarget() == model then
			local order = Knit.GetController("OrderController").CurrentOrder
			scripted = typeof(order) == "table" and (order :: any).Scripted == true
		end
		if not scripted then
			impatientToasted[model] = true
			toast(IMPATIENT_TEXT)
		end
	end

	-- C3
	local rescuable = false
	if
		clockedIn
		and atCounter
		and assigned ~= nil
		and assigned ~= localPlayer.UserId
		and fraction > 0
		and fraction < CustomerConfig.RESCUE_FRACTION
	then
		local character = localPlayer.Character
		local myRoot = character and character:FindFirstChild("HumanoidRootPart")
		if myRoot and myRoot:IsA("BasePart") then
			rescuable = (myRoot.Position - root.Position).Magnitude <= RESCUE_BROADCAST_STUDS
		end
	end
	if rescuable and not wasRescuable[model] then
		local now = os.clock()
		if now - lastRescueToastAt >= RESCUE_TOAST_COOLDOWN_SECONDS then
			lastRescueToastAt = now
			toast(`A customer needs help! Rescue for {CustomerConfig.RESCUE_MULT}x pay`)
		end
	end
	wasRescuable[model] = rescuable
end

-- Local view of each NPC ServePrompt (design 4.6): "Serve" for the assigned barista,
-- "Rescue" for a clocked-in barista once patience is below 30%, else hidden. The
-- server enforces every rule; this only decides what the player sees.
local function updateServePrompts()
	local customers = workspace:FindFirstChild("Customers")
	if customers == nil then
		return
	end
	local clockedIn = not isClockedOut()
	for _, model in customers:GetChildren() do
		local root = model:FindFirstChild("HumanoidRootPart")
		local prompt = root and root:FindFirstChild("ServePrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			local fraction = patienceFraction(model)
			if model:GetAttribute("AssignedUserId") == Players.LocalPlayer.UserId then
				prompt.Enabled = true
				prompt.ActionText = "Serve"
			elseif clockedIn and fraction < CustomerConfig.RESCUE_FRACTION then
				prompt.Enabled = true
				prompt.ActionText = "Rescue"
			else
				prompt.Enabled = false
			end
			local cuesOk, cuesErr = pcall(runPatienceCues, model, root :: BasePart, fraction, clockedIn)
			if not cuesOk and not patienceCuesWarned then
				patienceCuesWarned = true
				warn("[KitchenController] Patience cues failed: " .. tostring(cuesErr))
			end
		end
	end
end

local function onPromptHoldBegan(prompt: ProximityPrompt)
	local part = prompt.Parent
	local model = part and part.Parent
	if model == nil or not model:IsA("Model") then
		return
	end
	if isClockedOut() then
		return -- the server answers with InteractionFailed("ClockedOut")
	end
	local ok, err = pcall(function()
		local guidance = runtime.Current
		if not runtime.Enabled then
			return
		end
		local message = KitchenGuidance.WrongStationMessage(guidance, model.Name)
		local now = os.clock()
		if message and now - (runtime.LastToast[message] or -math.huge) >= TOAST_COOLDOWN_SECONDS then
			runtime.LastToast[message] = now
			toast(message)
		end
	end)
	if not ok then
		warn("[KitchenController] Wrong-station hint failed: " .. tostring(err))
	end
end

local function watchKitchen(kitchen: Instance)
	local connectedPrompts: { [Instance]: boolean } = {}
	local function onAdded(descendant: Instance)
		if descendant:IsA("Model") then
			indexModel(descendant)
		elseif descendant:IsA("ProximityPrompt") and not connectedPrompts[descendant] then
			connectedPrompts[descendant] = true
			descendant.PromptButtonHoldBegan:Connect(function()
				onPromptHoldBegan(descendant)
			end)
		end
	end
	for _, descendant in kitchen:GetDescendants() do
		onAdded(descendant)
	end
	kitchen.DescendantAdded:Connect(onAdded)
	kitchen.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("Model") then
			unindexModel(descendant)
		end
	end)
end

local function applySetting(value: any)
	runtime.Enabled = value ~= false -- defaults on
	if not runtime.Enabled then
		clearVisuals()
	end
end

-- Everything here degrades: a failure disables hints, never the kitchen.
local function startGuidance()
	local kitchen = WorldPath.waitFor(workspace, { "Assets", "Kitchen" }, KITCHEN_TIMEOUT_SECONDS)
	if not kitchen then
		warn("[KitchenController] workspace.Assets.Kitchen not found; station hints are disabled.")
		return
	end
	watchKitchen(kitchen)

	-- The setting (profile key SyrupHighlighting). Missing data leaves hints on.
	Knit.GetController("DataController"):GetDataAsync():andThen(function(data)
		local settings = data.Settings
		applySetting(if settings then settings[STATION_HINTS_SETTING] else nil)
		data:ListenToChange({ "Settings" }, function(newValue)
			applySetting(if newValue then newValue[STATION_HINTS_SETTING] else nil)
		end)
	end)

	local elapsed = 0
	local failures = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < GUIDANCE_INTERVAL_SECONDS or failures >= 5 then
			return
		end
		elapsed = 0
		local ok, err = pcall(function()
			guidanceStep(resolveServeTarget())
		end)
		if not ok then
			failures += 1
			warn("[KitchenController] Station hint update failed: " .. tostring(err))
			pcall(clearVisuals)
			if failures >= 5 then
				warn("[KitchenController] Station hints disabled after repeated errors.")
			end
		end
	end)

	Knit.GetService("KitchenService").InteractionFailed:Connect(function(reason: string)
		if reason == "ClockedOut" then
			toast("Clock In to use the kitchen. Tap the clock button.")
		end
	end)
end

---> Public

-- The dialog button the current step wants pressed ("Medium", "Latte", an item name), or
-- nil. AppDialogs pulses the button with this text.
function KitchenController:GetCurrentChoice(): string?
	if not runtime.Enabled or isClockedOut() then
		return nil
	end
	local guidance = runtime.Current
	return if guidance then guidance.Choice else nil
end

function KitchenController:KnitStart()
	local promptElapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		promptElapsed += dt
		if promptElapsed < 0.2 then
			return
		end
		promptElapsed = 0
		local ok, err = pcall(updateServePrompts)
		if not ok then
			warn("[KitchenController] Serve prompt update failed: " .. tostring(err))
		end
	end)

	task.spawn(function()
		local ok, err = pcall(startGuidance)
		if not ok then
			warn("[KitchenController] Station hints could not start: " .. tostring(err))
		end
	end)

	local player = Players.LocalPlayer

	local owns = GamepassUtil:PlayerOwnsPassAsync(player, INSTANT_BREW_PASS_NAME)
	if not owns then
		return
	end

	-- Bounded wait: a missing kitchen only disables the Instant Brew perk.
	local kitchen = WorldPath.waitFor(workspace, { "Assets", "Kitchen" }, KITCHEN_TIMEOUT_SECONDS)
	if not kitchen then
		warn("[KitchenController] workspace.Assets.Kitchen not found; Instant Brew hold times not applied.")
		return
	end
	applyInstantBrew(kitchen)
end

return KitchenController

---> Services

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local CustomerConfig = require(Shared.Configuration.CustomerConfig)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local WorldPath = require(Shared.Utility.WorldPath)
local OrderSpec = require(Shared.Ordering.OrderSpec)
local Styles = require(Shared.UI.Styles)
local KitchenConfig = require(Shared.Configuration.KitchenConfig)
local PourMeter = require(Shared.Kitchen.PourMeter)
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

local function allToolCandidates(): { { [string]: any } }
	local candidates: { { [string]: any } } = {}
	local player = Players.LocalPlayer
	if not player then
		return candidates
	end
	local character = player.Character
	local backpack = player:FindFirstChild("Backpack")
	local function addFrom(container: Instance?)
		if not container then
			return
		end
		for _, item in container:GetChildren() do
			if item:IsA("Tool") and item:GetAttribute("Served") ~= true then
				table.insert(candidates, item:GetAttributes())
			end
		end
	end
	addFrom(character)
	addFrom(backpack)
	return candidates
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

-- AUDIT-FIX D1.2: no ticket yet. Highlights the nearest customer waiting to order
-- (the welcome toast's "Follow the gold glow"); the beam follows the same first-
-- customers rule as the rest of guidance. True when it drew a hint.
local function takeOrderHint(rootPart: BasePart): boolean
	local folder = workspace:FindFirstChild("Customers")
	if folder == nil then
		return false
	end
	local views: { KitchenGuidance.CustomerView } = {}
	local models: { Model } = {}
	for _, model in folder:GetChildren() do
		if model:IsA("Model") then
			table.insert(views, {
				State = model:GetAttribute("State"),
				PromptAction = model:GetAttribute("PromptAction"),
				Position = model:GetPivot().Position,
			})
			table.insert(models, model)
		end
	end
	local index = KitchenGuidance.TakeOrderTarget(views, rootPart.Position)
	local target = if index then models[index] else nil
	if target == nil then
		return false
	end
	for slot = 1, KitchenGuidance.MAX_HIGHLIGHTS do
		local highlight = getHighlight(slot)
		highlight.Adornee = if slot == 1 then target else nil
		highlight.Enabled = slot == 1
	end
	local targetPart = anchorPart(target)
	local beamAllowed = KitchenGuidance.ShouldShowBeam({
		CustomersSeen = runtime.CustomersSeen,
		ItemSeenBefore = true,
		IdleSeconds = 0,
	})
	if targetPart and beamAllowed then
		showBeam(rootPart, targetPart)
	elseif runtime.Beam then
		runtime.Beam.Enabled = false
	end
	return true
end

local function guidanceStep(serveTarget: Model?)
	local player = Players.LocalPlayer
	local OrderController = Knit.GetController("OrderController")
	local order = OrderController.CurrentOrder
	local specs = KitchenGuidance.ResolveSpecs(order, OrderSpec.FromOrderItem)
	local candidates = allToolCandidates()
	local heldAttrs = heldToolAttributes()
	local activeSpec, allDone = KitchenGuidance.FindActiveSpec(specs, candidates, heldAttrs)

	local guidance: KitchenGuidance.Guidance? = nil
	if allDone then
		guidance = {
			Station = nil,
			Choice = nil,
			Label = "Serve your customer",
			IsServe = true,
			Current = 1,
			Total = 1,
			Item = if activeSpec then activeSpec.Item elseif specs[1] then specs[1].Item else "",
		}
	elseif activeSpec ~= nil then
		guidance = KitchenGuidance.Compute(activeSpec, heldAttrs)
		if guidance ~= nil and guidance.IsServe and not allDone then
			guidance.IsServe = false
		end
	end

	runtime.Current = guidance
	trackProgress(guidance, order)

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if
		order == nil
		and runtime.Enabled
		and player:GetAttribute(CLOCKED_IN_ATTRIBUTE) == true
		and rootPart
		and rootPart:IsA("BasePart")
		and takeOrderHint(rootPart)
	then
		return
	end
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
-- Patience runs at the register and at pickup, so both states count as waiting
-- (AUDIT-FIX D4.1).
local function runPatienceCues(model: Model, root: BasePart, fraction: number, clockedIn: boolean)
	local localPlayer = Players.LocalPlayer
	local assigned = model:GetAttribute("AssignedUserId")
	local state = model:GetAttribute("State")
	local atCounter = state == "AtCounter" or state == "AtPickup"

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

	-- T5: hide other baristas' bubbles unless rescuable; clocked-out sees all.
	local bubbleOk, bubbleErr = pcall(function()
		local hideBubble = clockedIn
			and assigned ~= nil
			and assigned ~= localPlayer.UserId
			and not (fraction < CustomerConfig.RESCUE_FRACTION)
		local bubble = model:FindFirstChild("OrderBubble")
		if bubble and bubble:IsA("BillboardGui") then
			local visible = not hideBubble
			if bubble.Enabled ~= visible then
				bubble.Enabled = visible
			end
		end
	end)
	if not bubbleOk and not patienceCuesWarned then
		patienceCuesWarned = true
		warn("[KitchenController] Patience cues failed: " .. tostring(bubbleErr))
	end
end

-- Local view of each NPC CustomerPrompt (design 4.6). The server names it
-- "CustomerPrompt" and mirrors its ActionText to the model's PromptAction attribute
-- (CustomerService:_ensureNpcPrompt). "Take Order" is left as the server set it.
-- "Serve" shows for the assigned barista only; another clocked-in barista sees
-- "Rescue" once patience is below RESCUE_FRACTION; anyone else sees nothing. The
-- server enforces every rule; this only decides what the player sees.
local function updateServePrompts()
	local customers = workspace:FindFirstChild("Customers")
	if customers == nil then
		return
	end
	local clockedIn = not isClockedOut()
	for _, model in customers:GetChildren() do
		local prompt = model:FindFirstChild("CustomerPrompt", true)
		local root = prompt and prompt.Parent
		if prompt and prompt:IsA("ProximityPrompt") and root and root:IsA("BasePart") then
			local fraction = patienceFraction(model)
			local action = model:GetAttribute("PromptAction")
			if action == "Serve" then
				if model:GetAttribute("AssignedUserId") == Players.LocalPlayer.UserId then
					prompt.Enabled = true
					prompt.ActionText = "Serve"
				elseif clockedIn and fraction < CustomerConfig.RESCUE_FRACTION then
					prompt.Enabled = true
					prompt.ActionText = "Rescue"
				else
					prompt.Enabled = false
				end
			end
			local cuesOk, cuesErr = pcall(runPatienceCues, model, root, fraction, clockedIn)
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

---> Pour meter (BIG-B7 skill moment)

-- Optional timing tap after pour stations. The server opens the window and
-- owns the clock; this only draws the meter from the server's view and
-- reports back how long the player watched it. Skipping it changes nothing.
-- UI-REVISION: a titled HUD card in OrderQueue's chrome (9-slice panel, GREEN_LIGHT
-- border, GREEN Banner), a GRAY pill track with the GREEN zone and GOLD sweet spot,
-- a GREEN_DEEP marker, a GREEN_LIGHT hint that names the player's input, and a
-- PromptButton-style "Pour" button. Pops in and out on a UIScale.

local POUR_GUI_NAME = "PourMeter"
local POUR_POSITION = UDim2.fromScale(0.5, 0.66)
local POUR_SIZE = UDim2.fromScale(0.265, 0.2)
local POUR_ASPECT = 1.85 -- taller than OrderQueue so the button is a real tap target
local POUR_MIN_SIZE = Vector2.new(280, 151)
local POUR_MAX_SIZE = Vector2.new(380, 205)
local POUR_BASE_IMAGE = "http://www.roblox.com/asset/?id=13473433246"
local POUR_BORDER_IMAGE = "http://www.roblox.com/asset/?id=13382163077"
local POUR_BANNER_BACK = "http://www.roblox.com/asset/?id=13369767169"
local POUR_BANNER_FRONT = "http://www.roblox.com/asset/?id=13369762471"
local POUR_OPEN_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POUR_CLOSE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local POUR_PRESS_TWEEN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type PourState = {
	Gui: ScreenGui?,
	Scale: UIScale?,
	Hint: TextLabel?,
	Track: Frame?,
	Zone: Frame?,
	PerfectZone: Frame?,
	Marker: Frame?,
	WindowId: number?,
	OpenedAt: number,
	Period: number,
	Duration: number,
	Heartbeat: RBXScriptConnection?,
}

local pour: PourState = {
	Gui = nil,
	Scale = nil,
	Hint = nil,
	Track = nil,
	Zone = nil,
	PerfectZone = nil,
	Marker = nil,
	WindowId = nil,
	OpenedAt = 0,
	Period = 1,
	Duration = 0,
	Heartbeat = nil,
}

-- TAKEOVER-REVIEW-FIX P2-2: keyboard and gamepad can tap the meter too. Bound only while a window is open, at a
-- priority above the default character controls, so Space/ButtonA don't jump and E doesn't hit a prompt mid-pour.
local POUR_TAP_ACTION = "PourMeterTap"
local POUR_TAP_INPUTS = { Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonR2 }
local POUR_TAP_PRIORITY = Enum.ContextActionPriority.High.Value + 50

local function unbindPourTap()
	ContextActionService:UnbindAction(POUR_TAP_ACTION)
end

local function hidePourMeter()
	unbindPourTap()
	if pour.Heartbeat then
		pour.Heartbeat:Disconnect()
		pour.Heartbeat = nil
	end
	pour.WindowId = nil
	local gui = pour.Gui
	if gui == nil or not gui.Enabled then
		return
	end
	local scale = pour.Scale
	if scale == nil then
		gui.Enabled = false
		return
	end
	local tween = TweenService:Create(scale, POUR_CLOSE_TWEEN, { Scale = 0 })
	tween.Completed:Connect(function(state)
		-- A window that opened again mid-close keeps the gui up.
		if state == Enum.PlaybackState.Completed and pour.WindowId == nil then
			gui.Enabled = false
		end
	end)
	tween:Play()
end

-- The hint names the input the player is using right now.
local function pourHintText(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "Tap Pour in the green!"
	elseif string.find(last.Name, "Gamepad") ~= nil then
		return "Press A in the green!"
	end
	return "Press E or Space in the green!"
end

local function addPourCorner(parent: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent
end

local function tapPourMeter()
	local id = pour.WindowId
	if id == nil then
		return
	end
	pour.WindowId = nil -- one tap per window
	local claimed = os.clock() - pour.OpenedAt
	hidePourMeter()
	task.spawn(function()
		pcall(function()
			Knit.GetService("KitchenService"):ReportPourTap(id, claimed)
		end)
	end)
end

local function buildPourMeter(): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = POUR_GUI_NAME
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	-- Outer frame: OrderQueue geometry (aspect, min/max pixel size, ZIndex 10).
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = POUR_POSITION
	panel.Size = POUR_SIZE
	panel.BackgroundTransparency = 1
	panel.ZIndex = 10
	panel.Parent = gui

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = POUR_ASPECT
	aspect.Parent = panel

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MinSize = POUR_MIN_SIZE
	sizeLimit.MaxSize = POUR_MAX_SIZE
	sizeLimit.Parent = panel

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = panel

	local base = Instance.new("ImageLabel")
	base.Name = "Base"
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	base.Position = UDim2.fromScale(0.5, 0.5)
	base.Size = UDim2.fromScale(1, 1)
	base.BackgroundTransparency = 1
	base.Image = POUR_BASE_IMAGE
	base.ScaleType = Enum.ScaleType.Slice
	base.SliceCenter = Rect.new(104, 96, 408, 416)
	base.Parent = panel

	local border = Instance.new("ImageLabel")
	border.Name = "Border"
	border.AnchorPoint = Vector2.new(0.5, 0.5)
	border.Position = UDim2.fromScale(0.5, 0.5)
	border.Size = UDim2.fromScale(0.970972, 0.938198)
	border.BackgroundTransparency = 1
	border.Image = POUR_BORDER_IMAGE
	border.ImageColor3 = Styles.GREEN_LIGHT
	border.Parent = base

	-- Banner (Components/Buttons/Banner) in GREEN, sized as OrderQueue's.
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.17)
	banner.Size = UDim2.fromScale(0.8, 0.3)
	banner.BackgroundTransparency = 1
	banner.ZIndex = 10
	banner.Parent = base

	local bannerBack = Instance.new("ImageLabel")
	bannerBack.AnchorPoint = Vector2.new(0.5, 0)
	bannerBack.Position = UDim2.fromScale(0.5, 0.1)
	bannerBack.Size = UDim2.fromScale(1, 0.875)
	bannerBack.BackgroundTransparency = 1
	bannerBack.Image = POUR_BANNER_BACK
	bannerBack.ImageColor3 = Styles.GREEN
	bannerBack.ZIndex = 8
	bannerBack.Parent = banner

	local bannerFront = Instance.new("ImageLabel")
	bannerFront.AnchorPoint = Vector2.new(0.5, 0)
	bannerFront.Position = UDim2.fromScale(0.5, 0)
	bannerFront.Size = UDim2.fromScale(0.845523, 0.758506)
	bannerFront.BackgroundTransparency = 1
	bannerFront.Image = POUR_BANNER_FRONT
	bannerFront.ImageColor3 = Styles.GREEN
	bannerFront.ZIndex = 11
	bannerFront.Parent = banner

	local bannerText = Instance.new("TextLabel")
	bannerText.AnchorPoint = Vector2.new(0, 0.5)
	bannerText.Position = UDim2.fromScale(0, 0.5)
	bannerText.Size = UDim2.fromScale(1, 0.8)
	bannerText.BackgroundTransparency = 1
	bannerText.FontFace = Styles.FONT_FREDOKA
	bannerText.Text = "Pour Timing"
	bannerText.TextColor3 = Color3.new(1, 1, 1)
	bannerText.TextScaled = true
	bannerText.ZIndex = 12
	bannerText.Parent = bannerFront

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.AnchorPoint = Vector2.new(0.5, 0)
	content.Position = UDim2.fromScale(0.5, 0.34)
	content.Size = UDim2.fromScale(0.84, 0.58)
	content.BackgroundTransparency = 1
	content.Parent = base

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.fromScale(0.5, 0.06)
	track.Size = UDim2.fromScale(1, 0.2)
	track.BackgroundColor3 = Styles.GRAY
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	addPourCorner(track, Styles.CORNER_BUTTON)
	track.Parent = content

	local config = KitchenConfig.POUR_METER

	local zone = Instance.new("Frame")
	zone.AnchorPoint = Vector2.new(0.5, 0.5)
	zone.Position = UDim2.fromScale(0.5, 0.5)
	zone.Size = UDim2.fromScale(config.ZONE_WIDTH, 1)
	zone.BackgroundColor3 = Styles.GREEN
	zone.BorderSizePixel = 0
	zone.Parent = track

	local perfectZone = Instance.new("Frame")
	perfectZone.AnchorPoint = Vector2.new(0.5, 0.5)
	perfectZone.Position = UDim2.fromScale(0.5, 0.5)
	perfectZone.Size = UDim2.fromScale(config.PERFECT_WIDTH / config.ZONE_WIDTH, 1)
	perfectZone.BackgroundColor3 = Styles.GOLD
	perfectZone.BorderSizePixel = 0
	perfectZone.Parent = zone

	-- The marker rides over the track (not inside it) so it can stand taller than it.
	local markerLane = Instance.new("Frame")
	markerLane.Name = "MarkerLane"
	markerLane.AnchorPoint = Vector2.new(0.5, 0.5)
	markerLane.Position = UDim2.fromScale(0.5, 0.06 + 0.1)
	markerLane.Size = UDim2.fromScale(1, 0.34)
	markerLane.BackgroundTransparency = 1
	markerLane.ZIndex = 3
	markerLane.Parent = content

	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.Position = UDim2.fromScale(0, 0.5)
	marker.Size = UDim2.fromScale(0.03, 1)
	marker.BackgroundColor3 = Styles.GREEN_DEEP
	marker.BorderSizePixel = 0
	marker.ZIndex = 3
	addPourCorner(marker, Styles.CORNER_FULL)
	local markerStroke = Instance.new("UIStroke")
	markerStroke.Color = Styles.OFFWHITE
	markerStroke.Thickness = 2
	markerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	markerStroke.Parent = marker
	marker.Parent = markerLane

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.fromScale(0.5, 0.36)
	hint.Size = UDim2.fromScale(1, 0.19)
	hint.BackgroundTransparency = 1
	hint.FontFace = Styles.FONT_FREDOKA
	hint.Text = pourHintText()
	hint.TextColor3 = Styles.GREEN_LIGHT
	hint.TextScaled = true
	hint.Parent = content
	local hintLimit = Instance.new("UITextSizeConstraint")
	hintLimit.MaxTextSize = 24
	hintLimit.Parent = hint

	-- PromptButton anatomy: radius 0.25, fill-lerp stroke 3, white label at max 24.
	local tapButton = Instance.new("TextButton")
	tapButton.Name = "PourButton"
	tapButton.AnchorPoint = Vector2.new(0.5, 1)
	tapButton.Position = UDim2.fromScale(0.5, 1)
	tapButton.Size = UDim2.fromScale(0.56, 0.38)
	tapButton.AutoButtonColor = false
	tapButton.BackgroundColor3 = Styles.GREEN
	tapButton.BorderSizePixel = 0
	tapButton.Text = ""
	addPourCorner(tapButton, UDim.new(0.25, 0))
	local tapStroke = Instance.new("UIStroke")
	tapStroke.Color = Styles.GREEN:Lerp(Color3.new(0, 0, 0), 0.15)
	tapStroke.Thickness = 3
	tapStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tapStroke.Parent = tapButton
	local tapScale = Instance.new("UIScale")
	tapScale.Parent = tapButton
	local tapLabel = Instance.new("TextLabel")
	tapLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	tapLabel.Position = UDim2.fromScale(0.5, 0.5)
	tapLabel.Size = UDim2.fromScale(0.85, 0.6)
	tapLabel.BackgroundTransparency = 1
	tapLabel.FontFace = Styles.FONT_FREDOKA
	tapLabel.Text = "Pour"
	tapLabel.TextColor3 = Color3.new(1, 1, 1)
	tapLabel.TextScaled = true
	tapLabel.Parent = tapButton
	local tapLimit = Instance.new("UITextSizeConstraint")
	tapLimit.MaxTextSize = 24
	tapLimit.Parent = tapLabel
	tapButton.Parent = content
	tapButton.MouseEnter:Connect(function()
		TweenService:Create(tapScale, POUR_PRESS_TWEEN, { Scale = 1.07 }):Play()
	end)
	tapButton.MouseLeave:Connect(function()
		TweenService:Create(tapScale, POUR_PRESS_TWEEN, { Scale = 1 }):Play()
	end)
	tapButton.MouseButton1Down:Connect(function()
		TweenService:Create(tapScale, POUR_PRESS_TWEEN, { Scale = 0.93 }):Play()
	end)
	tapButton.Activated:Connect(tapPourMeter)

	pour.Scale = scale
	pour.Hint = hint
	pour.Track = track
	pour.Zone = zone
	pour.PerfectZone = perfectZone
	pour.Marker = marker
	pour.Gui = gui
	gui.Parent = playerGui
	return gui
end

local function showPourMeter(view: any)
	if typeof(view) ~= "table" or typeof(view.Id) ~= "number" then
		return
	end
	local config = KitchenConfig.POUR_METER
	local gui = pour.Gui
	if gui == nil then
		local ok, built = pcall(buildPourMeter)
		if not ok or built == nil then
			warn("[KitchenController] Pour meter build failed: " .. tostring(built))
			return
		end
		gui = built
	end
	local zoneWidth = view.ZoneWidth or config.ZONE_WIDTH
	local perfectWidth = view.PerfectWidth or config.PERFECT_WIDTH
	if pour.Zone then
		pour.Zone.Size = UDim2.fromScale(zoneWidth, 1)
		pour.Zone.Position = UDim2.fromScale(view.ZoneCenter or 0.5, 0.5)
	end
	if pour.PerfectZone then
		local ratio = if zoneWidth > 0 then math.clamp(perfectWidth / zoneWidth, 0, 1) else 0.5
		pour.PerfectZone.Size = UDim2.fromScale(ratio, 1)
		pour.PerfectZone.Position = UDim2.fromScale(0.5, 0.5)
	end
	pour.WindowId = view.Id
	pour.OpenedAt = os.clock()
	pour.Period = view.Period or config.PERIOD_SECONDS
	pour.Duration = view.Duration or config.DURATION_SECONDS
	if pour.Hint then
		pour.Hint.Text = pourHintText()
	end
	if pour.Scale then
		local wasOpen = gui.Enabled
		if not wasOpen then
			pour.Scale.Scale = 0.6
		end
		TweenService:Create(pour.Scale, POUR_OPEN_TWEEN, { Scale = 1 }):Play()
	end
	gui.Enabled = true
	unbindPourTap()
	ContextActionService:BindActionAtPriority(POUR_TAP_ACTION, function(_actionName, inputState)
		if inputState ~= Enum.UserInputState.Begin or pour.WindowId == nil then
			return Enum.ContextActionResult.Pass
		end
		tapPourMeter()
		return Enum.ContextActionResult.Sink
	end, false, POUR_TAP_PRIORITY, table.unpack(POUR_TAP_INPUTS))
	if pour.Heartbeat then
		pour.Heartbeat:Disconnect()
	end
	pour.Heartbeat = RunService.Heartbeat:Connect(function()
		if pour.Marker and pour.WindowId == view.Id then
			pour.Marker.Position = UDim2.fromScale(PourMeter.Position(os.clock() - pour.OpenedAt, pour.Period), 0.5)
		end
	end)
	local id = view.Id
	task.delay(pour.Duration + config.LATENCY_ALLOWANCE_SECONDS + 0.5, function()
		if pour.WindowId == id then
			hidePourMeter()
		end
	end)
end

-- A miss or a skipped meter is still a Good drink (AUDIT-FIX D2.1); "Messy" only
-- tells the player the tip was lost.
local function showPourFeedback(tier: string, reason: any)
	if tier == "Good" and typeof(reason) == "string" and reason ~= "Ok" then
		tier = "Messy"
	end
	local text: string
	local textColor: Color3
	local strokeColor: Color3

	if tier == "Perfect" then
		text = "Perfect pour!"
		textColor = Styles.GOLD
		strokeColor = Styles.GOLD_DEEP
	elseif tier == "Good" then
		text = "Good pour"
		textColor = Styles.GREEN
		strokeColor = Styles.GREEN_DEEP
	elseif tier == "Messy" then
		text = "Messy pour, no tip"
		textColor = Styles.CORAL
		strokeColor = Styles.CORAL:Lerp(Color3.new(0, 0, 0), 0.3)
	else
		return
	end

	local player = Players.LocalPlayer
	local character = if player then player.Character else nil
	local targetPart = if character then (character:FindFirstChild("Head") or character.PrimaryPart) else nil
	if not (targetPart and targetPart:IsA("BasePart")) then
		toast(text)
		return
	end

	local playerGui = if player
		then (player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 2))
		else nil
	local parentTarget = playerGui or character
	if parentTarget == nil then
		toast(text)
		return
	end

	local initialOffset = Vector3.new(0, 3.5, 0)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PourFeedback"
	gui.Adornee = targetPart
	gui.Size = UDim2.fromOffset(140, 40)
	gui.StudsOffset = initialOffset
	gui.AlwaysOnTop = true
	gui.MaxDistance = 60
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Styles.FONT_FREDOKA
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = textColor

	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label

	label.Parent = gui
	gui.Parent = parentTarget

	local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, tweenInfo, { StudsOffset = initialOffset + Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(label, tweenInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, tweenInfo, { Transparency = 1 }):Play()

	task.delay(1.2, function()
		pcall(function()
			gui:Destroy()
		end)
	end)
end

local function startPourMeter()
	local ok, kitchenService = pcall(Knit.GetService, "KitchenService")
	if not ok or kitchenService == nil then
		warn("[KitchenController] KitchenService not found; pour meter is disabled.")
		return
	end
	kitchenService.PourWindowOpened:Connect(showPourMeter)
	kitchenService.PourResolved:Connect(function(_id: number, tier: any, reason: any)
		if typeof(tier) == "string" then
			showPourFeedback(tier, reason)
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
		local okPour, errPour = pcall(startPourMeter)
		if not okPour then
			warn("[KitchenController] Pour meter could not start: " .. tostring(errPour))
		end
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

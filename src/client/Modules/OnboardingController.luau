--[[
    Module: OnboardingController
    Description: Drives the worker onboarding on the client — the objective state the HUD
                 card renders, and the world beacon pointing at the current target.

    The onboarding teaches by doing: there is no "Next" button anywhere in it. This
    controller only ever *observes* the player reaching a place; every step that matters is
    confirmed by the server, which owns progression.

    React components subscribe to ObjectiveChanged rather than talking to the service.
--]]

---> Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SharedStorage = ReplicatedStorage:WaitForChild("SharedStorage")

---> Dependencies

local Knit = require(Packages.Knit)
local GoodSignal = require(Packages.GoodSignal)
local OnboardingConfig = require(Shared.Configuration.OnboardingConfig)

---> Controller

local OnboardingController = Knit.CreateController({
	Name = "OnboardingController",
})

local LocalPlayer = Players.LocalPlayer

---> Constants

--- How close the player must get for a "go to X" step to count as done.
local ARRIVAL_DISTANCE = 14

--- Seconds between proximity checks. The step is a walk across a room, so polling four
--- times a second is far more than enough and costs nothing.
local PROXIMITY_INTERVAL = 0.25

---> State

-- nil = no objective. Set to the current WORKER_STEPS entry while onboarding runs.
OnboardingController.Objective = nil :: any
OnboardingController.State = nil :: any
-- Live instance the beacon is pointing at, when the server named one (the customer to
-- serve). nil means the step's configured world anchor is in use.
OnboardingController.ObjectiveTarget = nil :: Instance?
-- Server-supplied objective line, naming the specific customer and what they asked for.
-- nil means the step's static text from OnboardingConfig applies.
OnboardingController.ObjectiveText = nil :: string?

OnboardingController.ObjectiveChanged = GoodSignal.new() -- fires(step: table?)
OnboardingController.StateChanged = GoodSignal.new() -- fires(state: table)

local beacon: Beam? = nil
local beaconAttachments: { Attachment } = {}

---> Private

--- Resolves a step's Target path under workspace, then picks a part to point at. Returns
--- nil rather than erroring when the world does not have the anchor: the onboarding must
--- degrade to "objective text with no beacon", never to a broken client.
local function resolveTarget(path: { string }): BasePart?
	local node: Instance = workspace

	for _, name in path do
		local child = node:FindFirstChild(name)
		if not child then
			return nil
		end
		node = child
	end

	if node:IsA("BasePart") then
		return node
	end

	-- Folder or model: aim at whichever part is closest, so a bank of staff screens
	-- points at the one the player should actually walk to.
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

	local closest: BasePart? = nil
	local closestDistance = math.huge

	for _, descendant in node:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end

		if not root then
			return descendant
		end

		local distance = (descendant.Position - root.Position).Magnitude
		if distance < closestDistance then
			closest = descendant
			closestDistance = distance
		end
	end

	return closest
end

local function clearBeacon()
	if beacon then
		beacon:Destroy()
		beacon = nil
	end

	for _, attachment in beaconAttachments do
		attachment:Destroy()
	end
	beaconAttachments = {}
end

--- Draws the beam from the player to the target. Reuses the same PickupBeam the order
--- pick-up flow uses, so the "follow this" language is consistent across the game.
local function drawBeacon(target: BasePart)
	clearBeacon()

	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local template = SharedStorage.Effects:FindFirstChild("PickupBeam")
	if not template then
		return
	end

	local newBeacon = template:Clone()

	local a0 = Instance.new("Attachment")
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Parent = target

	newBeacon.Attachment0 = a0
	newBeacon.Attachment1 = a1
	newBeacon.Parent = root

	beacon = newBeacon
	beaconAttachments = { a0, a1 }
end

--- Picks a part to aim at from a model or folder handed over by the server.
local function partOf(instance: Instance?): BasePart?
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChild("HumanoidRootPart") :: BasePart?
	end

	return nil
end

--- Publishes the current step to the HUD and repoints the beacon.
--- `override` is a live instance from the server (the customer to serve); when present it
--- wins over the step's configured anchor, because a spawned NPC cannot be named in config.
function OnboardingController:_setObjective(step: any, override: Instance?)
	local changed = self.Objective ~= step

	self.Objective = step
	self.ObjectiveTarget = override

	if changed then
		self.ObjectiveChanged:Fire(step)
	end

	if not step then
		clearBeacon()
		return
	end

	local target = partOf(override) or resolveTarget(step.Target)
	if target then
		drawBeacon(target)
	else
		clearBeacon()
		warn(`[OnboardingController] No world anchor for step '{step.Id}'.`)
	end
end

--- Watches for the player reaching a "go there" step's target. This is the only step the
--- client can complete on its own; the server still decides whether the report counts.
function OnboardingController:_watchProximity()
	local accumulated = 0

	RunService.Heartbeat:Connect(function(deltaTime)
		accumulated += deltaTime
		if accumulated < PROXIMITY_INTERVAL then
			return
		end
		accumulated = 0

		local step = self.Objective
		if not step or step.Tracker ~= "ApproachedRegister" then
			return
		end

		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end

		local target = resolveTarget(step.Target)
		if not target then
			return
		end

		if (target.Position - root.Position).Magnitude <= ARRIVAL_DISTANCE then
			Knit.GetService("OnboardingService"):ReportProximity()
		end
	end)
end

---> Public

--- Whether the local player is currently working through the onboarding.
function OnboardingController:IsOnboarding(): boolean
	return self.Objective ~= nil
end

---> Lifecycle

function OnboardingController:KnitStart()
	local OnboardingService = Knit.GetService("OnboardingService")

	local function apply(state)
		if not state then
			return
		end

		self.State = state
		self.StateChanged:Fire(state)

		if not state.OnboardingRunning then
			self:_setObjective(nil)
			return
		end

		self.ObjectiveText = state.ObjectiveText
		self:_setObjective(OnboardingConfig.WORKER_STEPS[state.StepIndex + 1], state.ObjectiveTarget)
	end

	OnboardingService.StateChanged:Connect(apply)

	-- Snapshot on start, in case the server published before this connected.
	OnboardingService:GetState():andThen(apply):catch(function(err)
		warn(`[OnboardingController] Could not read onboarding state: {err}`)
	end)

	-- The beam anchors to the character, so it has to be redrawn after a respawn.
	LocalPlayer.CharacterAdded:Connect(function()
		local step = self.Objective
		if not step then
			return
		end

		task.wait(0.5)
		local target = partOf(self.ObjectiveTarget) or resolveTarget(step.Target)
		if target then
			drawBeacon(target)
		end
	end)

	self:_watchProximity()
end

return OnboardingController

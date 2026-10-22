--!strict
--[[
	EventFxController
	World-side "pop" for Rush Hour and Boba Party (EVENT-FX). Client only, nothing authored
	in the place:
	- A ColorCorrectionEffect of its own in Lighting (the authored one is left alone) warms
	  and saturates the cafe; during a party its tint drifts through pastel party colours.
	- Confetti falls around the local character: a burst on start, then a steady drizzle
	  (heavier during a party, plus gold sparkles).
	- A quick camera FOV punch when an event starts or a party is extended.
	The HUD intro (Hud/EventIntro) and MusicController's fanfare play alongside.
]]

---> Services

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local CafeEvent = require(Shared.Utility.CafeEvent)
local Styles = require(Shared.UI.Styles)

---> Constants

local CONFETTI_TEXTURE = "rbxasset://textures/particles/SquareParticle.png"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local CONFETTI_COLORS = { Styles.GOLD, Styles.ROSE, Styles.GREEN_LIGHT, Styles.CORAL, Styles.CREAM }
local CONFETTI_HEIGHT = 14 -- studs above the character
local CONFETTI_AREA = Vector3.new(44, 1, 44)
local BURST_PER_COLOR = 24

type Look = {
	Rate: number, -- confetti per second, per colour
	Sparkles: number, -- sparkles per second
	Saturation: number,
	Contrast: number,
	Brightness: number,
	Tint: { Color3 }, -- cycled; one entry = steady
}

local LOOKS: { [CafeEvent.Mode]: Look } = {
	Rush = {
		Rate = 2,
		Sparkles = 0,
		Saturation = 0.22,
		Contrast = 0.06,
		Brightness = 0.02,
		Tint = { Color3.fromRGB(255, 242, 220) },
	},
	Party = {
		Rate = 5,
		Sparkles = 6,
		Saturation = 0.32,
		Contrast = 0.08,
		Brightness = 0.03,
		Tint = {
			Color3.fromRGB(255, 226, 236),
			Color3.fromRGB(255, 242, 214),
			Color3.fromRGB(228, 255, 236),
			Color3.fromRGB(232, 232, 255),
		},
	},
}

local GRADE_TWEEN = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TINT_CYCLE_SECONDS = 2.5
local FOV_PUNCH = 8
local FOV_OUT = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FOV_BACK = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

---> Controller

local EventFxController = Knit.CreateController({
	Name = "EventFxController",
})

local grade: ColorCorrectionEffect? = nil
local rig: Part? = nil
local confetti: { ParticleEmitter } = {}
local sparkles: ParticleEmitter? = nil
local followConn: RBXScriptConnection? = nil
local tintThread: thread? = nil
local tintTween: Tween? = nil
local fovBusy = false

-- Paper flutter: squash swings between flat and stretched over the particle's life.
local function flutter(): NumberSequence
	local points = {}
	local steps = 12
	for i = 0, steps do
		local value = if i % 2 == 0 then 1.2 else -1.2
		table.insert(points, NumberSequenceKeypoint.new(i / steps, value))
	end
	return NumberSequence.new(points)
end

local function makeConfetti(color: Color3, parent: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Confetti"
	emitter.Texture = CONFETTI_TEXTURE
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.15
	emitter.LightInfluence = 0.6
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.32, 0.08),
		NumberSequenceKeypoint.new(1, 0.32, 0.08),
	})
	emitter.Squash = flutter()
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.85, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(4, 6)
	emitter.Speed = NumberRange.new(2, 6)
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Acceleration = Vector3.new(0, -5, 0)
	emitter.Drag = 1.2
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-320, 320)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
end

local function makeSparkles(parent: Instance): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sparkles"
	emitter.Texture = SPARKLE_TEXTURE
	emitter.Color = ColorSequence.new(Styles.GOLD)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(2, 3)
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Acceleration = Vector3.new(0, -2, 0)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Rate = 0
	emitter.Parent = parent
	return emitter
end

local function ensureRig(): Part
	if rig and rig.Parent then
		return rig
	end
	local part = Instance.new("Part")
	part.Name = "CafeEventConfetti"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = CONFETTI_AREA
	confetti = {}
	for _, color in CONFETTI_COLORS do
		table.insert(confetti, makeConfetti(color, part))
	end
	sparkles = makeSparkles(part)
	part.Parent = Workspace.CurrentCamera or Workspace
	rig = part
	return part
end

local function ensureGrade(): ColorCorrectionEffect
	if grade and grade.Parent then
		return grade
	end
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "CafeEventGrade"
	effect.Parent = Lighting
	grade = effect
	return effect
end

local function startFollow()
	if followConn then
		return
	end
	followConn = RunService.Heartbeat:Connect(function()
		local part = rig
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if part and root then
			part.CFrame = CFrame.new(root.Position + Vector3.new(0, CONFETTI_HEIGHT, 0))
		end
	end)
end

local function stopFollow()
	if followConn then
		followConn:Disconnect()
		followConn = nil
	end
end

local function stopTintCycle()
	if tintThread then
		task.cancel(tintThread)
		tintThread = nil
	end
	-- The cycle's in-flight tween outlives the thread: it finishes after the
	-- end-of-event neutral tween and repaints the grade with a party tint that
	-- then sticks (and poisons the next event), so cancel it too.
	if tintTween then
		tintTween:Cancel()
		tintTween = nil
	end
end

local function startTintCycle(effect: ColorCorrectionEffect, tints: { Color3 })
	stopTintCycle()
	if #tints < 2 then
		return
	end
	local info = TweenInfo.new(TINT_CYCLE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	tintThread = task.spawn(function()
		local index = 1
		while true do
			index = index % #tints + 1
			tintTween = TweenService:Create(effect, info, { TintColor = tints[index] })
			tintTween:Play()
			task.wait(TINT_CYCLE_SECONDS)
		end
	end)
end

local function punchFov()
	local camera = Workspace.CurrentCamera
	if not camera or fovBusy then
		return
	end
	fovBusy = true
	local base = camera.FieldOfView
	local out = TweenService:Create(camera, FOV_OUT, { FieldOfView = base + FOV_PUNCH })
	out:Play()
	out.Completed:Wait()
	local back = TweenService:Create(camera, FOV_BACK, { FieldOfView = base })
	back:Play()
	back.Completed:Wait()
	fovBusy = false
end

local function burst()
	for _, emitter in confetti do
		emitter:Emit(BURST_PER_COLOR)
	end
end

local function apply(state: CafeEvent.State, intro: CafeEvent.Intro?)
	local mode = state.Mode
	local effect = ensureGrade()

	if mode == nil then
		stopTintCycle()
		TweenService:Create(effect, GRADE_TWEEN, {
			Saturation = 0,
			Contrast = 0,
			Brightness = 0,
			TintColor = Color3.new(1, 1, 1),
		}):Play()
		for _, emitter in confetti do
			emitter.Rate = 0
		end
		if sparkles then
			sparkles.Rate = 0
		end
		-- Let the last confetti land before the rig stops following.
		task.delay(6, function()
			if CafeEvent.read().Mode == nil then
				stopFollow()
			end
		end)
		return
	end

	local look = LOOKS[mode]
	ensureRig()
	startFollow()
	for _, emitter in confetti do
		emitter.Rate = look.Rate
	end
	if sparkles then
		sparkles.Rate = look.Sparkles
	end
	TweenService:Create(effect, GRADE_TWEEN, {
		Saturation = look.Saturation,
		Contrast = look.Contrast,
		Brightness = look.Brightness,
		TintColor = look.Tint[1],
	}):Play()
	startTintCycle(effect, look.Tint)

	if intro ~= nil then
		-- The rig moves onto the character next Heartbeat; burst after it gets there.
		-- Guarded: an event that ends (or is superseded) within that window must not
		-- fire confetti after teardown.
		task.delay(0.05, function()
			if CafeEvent.read().Mode ~= nil then
				burst()
			end
		end)
		task.spawn(punchFov)
	end
end

function EventFxController:KnitStart()
	local last = CafeEvent.read()
	-- Joining mid-event: settle into the look, no burst or punch.
	if last.Mode ~= nil then
		apply(last, nil)
	end
	CafeEvent.observe(function(state)
		local intro = CafeEvent.introFor(last, state)
		local changed = state.Mode ~= last.Mode
		last = state
		if changed or intro ~= nil then
			apply(state, intro)
		end
	end)
end

return EventFxController

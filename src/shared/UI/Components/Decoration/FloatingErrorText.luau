--!nonstrict

-- Render this inside a BillboardGui whose Adornee is your interaction point.
-- The component randomizes drift, wobble, and fade each time it mounts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local Pane = require(UI.Components.Pane)

---> hooks
local useClock = require(UI.Hooks.useClock)

---> utilities
local joinDicts = require(UI.Utility.joinDicts)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local DEFAULT_MESSAGES = {
	"ERROR!",
	"INVALID!",
	"DENIED!",
	"NOPE!",
	"TRY AGAIN!",
}

local function clamp01(value)
	return math.clamp(value, 0, 1)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function smoothstep(t)
	t = clamp01(t)
	return t * t * (3 - 2 * t)
end

local function easeOutCubic(t)
	t = clamp01(t)
	local inv = 1 - t
	return 1 - (inv * inv * inv)
end

local function selectMessage(rng, text)
	if text and text ~= "" then
		return text
	end

	return DEFAULT_MESSAGES[rng:NextInteger(1, #DEFAULT_MESSAGES)]
end

local function buildConfig(props)
	local seed = props.Seed or Random.new():NextInteger(1, 1_000_000_000)
	local rng = Random.new(seed)

	return {
		Message = selectMessage(rng, props.Text),
		StartDelay = math.max(0, props.StartDelay or rng:NextNumber(0, 0.09)),
		Lifetime = math.max(0.25, props.Lifetime or rng:NextNumber(0.85, 1.45)),
		StartY = props.StartY or 0.66,
		RiseAmount = props.RiseAmount or rng:NextNumber(0.28, 0.44),
		DriftX = props.DriftX or rng:NextNumber(-0.11, 0.11),
		WobbleAmp = rng:NextNumber(0.008, 0.025),
		WobbleFreq = rng:NextNumber(12, 20),
		JitterFreq = rng:NextNumber(18, 30),
		FlickerFreq = rng:NextNumber(35, 50),
		Phase = rng:NextNumber(0, math.pi * 2),
		PopScale = rng:NextNumber(1.12, 1.3),
		EndScale = rng:NextNumber(0.8, 0.92),
	}
end

local function sample(config, clock)
	local elapsed = math.max(0, clock - config.StartDelay)
	local progress = clamp01(elapsed / config.Lifetime)
	local eased = easeOutCubic(progress)
	local fade = smoothstep(progress)
	local alive = 1 - fade

	local sway = math.sin(elapsed * config.WobbleFreq + config.Phase) * config.WobbleAmp * alive
	local lift = math.cos(elapsed * (config.WobbleFreq * 0.72) + config.Phase) * config.WobbleAmp * 0.65 * alive

	local x = 0.5 + (config.DriftX * eased) + sway
	local y = config.StartY - (config.RiseAmount * eased) + lift

	local popIn = smoothstep(clamp01(progress / 0.22))
	local settleOut = smoothstep(clamp01((progress - 0.22) / 0.78))
	local scale = lerp(config.PopScale, 1, popIn)
	scale = lerp(scale, config.EndScale, settleOut)

	local flicker = (0.5 + 0.5 * math.sin(elapsed * config.FlickerFreq + config.Phase * 1.7)) * 0.2 * alive
	local textTransparency = clamp01(0.02 + fade + flicker)
	local shadowTransparency = clamp01(0.24 + fade + (flicker * 0.5))
	local strokeTransparency = clamp01(0.08 + fade)
	local accentTransparency = clamp01(0.12 + fade + (flicker * 0.6))

	local rotation = math.sin(elapsed * config.JitterFreq + config.Phase) * 7 * alive

	return {
		X = x,
		Y = y,
		Scale = scale,
		Rotation = rotation,
		TextTransparency = textTransparency,
		ShadowTransparency = shadowTransparency,
		StrokeTransparency = strokeTransparency,
		AccentTransparency = accentTransparency,
	}
end

export type Props = {
	Text: string?,
	Seed: number?,
	Lifetime: number?,
	StartDelay: number?,
	StartY: number?,
	RiseAmount: number?,
	DriftX: number?,
	Native: { [string]: any }?,
	OnFinished: (() -> ())?,
}

return function(props: Props)
	local configRef = React.useRef(nil)
	if not configRef.current then
		configRef.current = buildConfig(props)
	end

	local config = configRef.current
	local clock = useClock()

	React.useEffect(function()
		if not props.OnFinished then
			return
		end

		local cancelled = false
		local thread = task.delay(config.StartDelay + config.Lifetime, function()
			if cancelled then
				return
			end
			props.OnFinished()
		end)

		return function()
			cancelled = true
			task.cancel(thread)
		end
	end, { props.OnFinished })

	local textPositionBinding = clock:map(function(t)
		local state = sample(config, t)
		return UDim2.fromScale(state.X, state.Y)
	end)

	local shadowPositionBinding = clock:map(function(t)
		local state = sample(config, t)
		return UDim2.fromScale(state.X + 0.02, state.Y + 0.02)
	end)

	local leftAccentPositionBinding = clock:map(function(t)
		local state = sample(config, t)
		return UDim2.fromScale(state.X - 0.34, state.Y - 0.01)
	end)

	local rightAccentPositionBinding = clock:map(function(t)
		local state = sample(config, t)
		return UDim2.fromScale(state.X + 0.34, state.Y - 0.01)
	end)

	local scaleBinding = clock:map(function(t)
		local state = sample(config, t)
		return state.Scale
	end)

	local rotationBinding = clock:map(function(t)
		local state = sample(config, t)
		return state.Rotation
	end)

	local textTransparencyBinding = clock:map(function(t)
		local state = sample(config, t)
		return state.TextTransparency
	end)

	local shadowTransparencyBinding = clock:map(function(t)
		local state = sample(config, t)
		return state.ShadowTransparency
	end)

	local strokeTransparencyBinding = clock:map(function(t)
		local state = sample(config, t)
		return state.StrokeTransparency
	end)

	local accentTransparencyBinding = clock:map(function(t)
		local state = sample(config, t)
		return state.AccentTransparency
	end)

	return c(Pane, {
		ClassName = "Frame",
		Native = joinDicts({
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ClipsDescendants = false,
		}, props.Native),
	}, {
		Shadow = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_DENKONE,
				Position = shadowPositionBinding,
				Rotation = rotationBinding,
				Size = UDim2.fromScale(0.9, 0.7),
				Text = config.Message,
				TextColor3 = Color3.fromRGB(76, 0, 0),
				TextScaled = true,
				TextTransparency = shadowTransparencyBinding,
			},
		}),

		Main = c(Pane, {
			ClassName = "TextLabel",
			Scale = scaleBinding,
			Gradient = {
				Rotation = 90,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 102, 102)),
					ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 39, 63)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 0, 22)),
				}),
			},
			Stroke = {
				Color = Color3.fromRGB(40, 0, 0),
				Thickness = 2.5,
				Transparency = strokeTransparencyBinding,
			},
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_DENKONE,
				Position = textPositionBinding,
				Rotation = rotationBinding,
				Size = UDim2.fromScale(0.9, 0.7),
				Text = config.Message,
				TextColor3 = Styles.RED,
				TextScaled = true,
				TextTransparency = textTransparencyBinding,
			},
		}),

		LeftAccent = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = leftAccentPositionBinding,
				Rotation = rotationBinding,
				Size = UDim2.fromScale(0.2, 0.35),
				Text = "!!",
				TextColor3 = Color3.fromRGB(255, 145, 145),
				TextScaled = true,
				TextTransparency = accentTransparencyBinding,
			},
		}),

		RightAccent = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = rightAccentPositionBinding,
				Rotation = rotationBinding,
				Size = UDim2.fromScale(0.2, 0.35),
				Text = "!!",
				TextColor3 = Color3.fromRGB(255, 145, 145),
				TextScaled = true,
				TextTransparency = accentTransparencyBinding,
			},
		}),
	})
end
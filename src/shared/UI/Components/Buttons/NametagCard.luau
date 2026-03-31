local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)

---> components
local Pane = require(UI.Components.Pane)

---> utilities
local useClock = require(UI.Utility.useClock)

---> constants
local IS_MOBILE = game:GetService("UserInputService").TouchEnabled

local HOVER_SPRING = {
	mass = 1,
	tension = 10000,
	friction = 200,
}

---> private
local c = React.createElement

--- Lerp a number
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

--- Lerp a Color3
local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

--- Smoothstep easing — eases in AND out, making color transitions feel fluid
local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

--- Given elapsed time and the animation frame list, return the current
--- interpolated {Color, Transparency} for rendering.
local function evalAnimation(frames: { any }, elapsed: number): (Color3, number)
	-- compute total cycle duration
	local totalDuration = 0
	for _, f in ipairs(frames) do
		totalDuration += (f.Transition or 0.5) + f.Hold
	end

	-- wrap elapsed into one cycle
	local t = elapsed % totalDuration

	-- walk through frames to find which segment we're in
	for i, frame in ipairs(frames) do
		local transition = frame.Transition or 0.5
		local segDuration = transition + frame.Hold

		if t <= segDuration then
			-- during transition phase?
			if t <= transition then
				local alpha = smoothstep(transition > 0 and (t / transition) or 1)
				local prevFrame = frames[((i - 2) % #frames) + 1]
				local fromColor = prevFrame.Color
				local fromTransp = prevFrame.Transparency or 0
				return lerpColor(fromColor, frame.Color, alpha),
					lerp(fromTransp, frame.Transparency or 0, alpha)
			else
				-- holding at this frame's color
				return frame.Color, frame.Transparency or 0
			end
		end

		t -= segDuration
	end

	-- fallback
	local last = frames[#frames]
	return last.Color, last.Transparency or 0
end

---> public

export type AnimFrame = {
	Color: Color3,
	Transparency: number?,
	Hold: number,
	Transition: number?,
}

export type ColorAnimation = {
	Frames: { AnimFrame },
}

export type Props = {
	Name: string,
	Price: string,
	Tier: string,
	TierColor: Color3,
	Color: Color3,
	Animation: ColorAnimation?,
	OffSale: boolean?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
}

return function(props: Props)
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)

	local active = not props.OffSale
	local priceVisible = active and (IS_MOBILE or isHovering)

	local hoverStyles = ReactSpring.useSpring({
		scale        = active and (isPressing and 0.95 or (isHovering and 1.12 or 1)) or 1,
		priceOpacity = priceVisible and 0 or 1,
		config = HOVER_SPRING,
	})

	local strokeStyles = ReactSpring.useSpring({
		priceStrokeOpacity = priceVisible and 0 or 1,
		config = { mass = 0.5, tension = 15000, friction = 150 },
	})

	local startTime = React.useRef(os.clock())
	local clock = if props.Animation then useClock() else 0

	local displayColor: Color3
	local displayTransparency: number
	if props.Animation and #props.Animation.Frames > 0 then
		local elapsed = clock - startTime.current
		displayColor, displayTransparency = evalAnimation(props.Animation.Frames, elapsed)
	else
		displayColor = props.Color
		displayTransparency = 0
	end

	return c(Pane, {
		ClassName = "ImageButton",
		Scale = hoverStyles.scale,
		AspectRatio = 1,
		CornerRadius = UDim.new(1, 0),
		Stroke = active and { Color = props.TierColor, Thickness = 3 } or nil,
		OnClick = active and props.OnClick or nil,
		OnPress = active and function()
			setIsPressing(true)
		end or nil,
		OnRelease = active and function()
			setIsPressing(false)
		end or nil,
		OnHover = active and function()
			setIsHovering(true)
		end or nil,
		OnLeave = active and function()
			setIsHovering(false)
			setIsPressing(false)
		end or nil,
		Native = {
			AutoButtonColor = false,
			BackgroundColor3 = displayColor,
			BackgroundTransparency = displayTransparency,
			LayoutOrder = props.LayoutOrder,
		},
	}, {
		ProductName = not props.OffSale and c(Pane, {
			ClassName = "TextLabel",
			Stroke = { Thickness = 1.5 },
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, 0.48),
				Size = UDim2.fromScale(0.8, 0.22),
				Text = props.Name,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}) or nil,

		TierLabel = not props.OffSale and c(Pane, {
			ClassName = "TextLabel",
			Stroke = {
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = 1.5,
			},
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, 0.66),
				Size = UDim2.fromScale(0.7, 0.16),
				Text = props.Tier,
				TextColor3 = props.TierColor,
				TextScaled = true,
			},
		}) or nil,

		ProductPrice = c(Pane, {
			ClassName = "TextLabel",
			Stroke = { Thickness = 1.5, Transparency = strokeStyles.priceStrokeOpacity },
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, 0.15),
				Size = UDim2.fromScale(0.75, 0.16),
				Text = props.Price,
				TextColor3 = Color3.new(1, 1, 1),
				TextTransparency = hoverStyles.priceOpacity,
				TextScaled = true,
			},
		}),

		OffSaleOverlay = props.OffSale and c(Pane, {
			ClassName = "Frame",
			CornerRadius = UDim.new(1, 0),
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.4,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			},
		}, {
			Label = c(Pane, {
				ClassName = "TextLabel",
				Stroke = { Thickness = 1.5 },
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.75, 0.22),
					Text = "Off Sale",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				},
			}),
		}) or nil,
	})
end

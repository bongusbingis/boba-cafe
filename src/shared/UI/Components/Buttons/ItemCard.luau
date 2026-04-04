local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)

---> components
local Banner = require(UI.Components.Buttons.Banner)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local Pane = require(UI.Components.Pane)
local ViewportModel = require(UI.Components.ViewportModel)

---> utilities
local useClock = require(UI.Utility.useClock)

---> styles
local Styles = require(UI.Styles)

---> constants
local IS_MOBILE = game:GetService("UserInputService").TouchEnabled
local TIER_COLORS = InventoryItemDefinitions.Tiers

---> private
local c = React.createElement

--- Lerp a number
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function evalAnimation(frames: { any }, elapsed: number): (Color3, number)
	local totalDuration = 0
	for _, f in ipairs(frames) do
		totalDuration += (f.Transition or 0.5) + f.Hold
	end

	local t = elapsed % totalDuration

	for i, frame in ipairs(frames) do
		local transition = frame.Transition or 0.5
		local segDuration = transition + frame.Hold

		if t <= segDuration then
			if t <= transition then
				local alpha = smoothstep(transition > 0 and (t / transition) or 1)
				local prevFrame = frames[((i - 2) % #frames) + 1]
				local fromColor = prevFrame.Color
				local fromTransp = prevFrame.Transparency or 0
				return fromColor:Lerp(frame.Color, alpha),
					lerp(fromTransp, frame.Transparency or 0, alpha)
			else
				return frame.Color, frame.Transparency or 0
			end
		end

		t -= segDuration
	end

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

--[[
	Unified item card. The visual variant is determined by which props are provided:

	  Color / Animation  →  nametag style: animated circular color swatch with Name + Tier labels
	  Model              →  pet style: 3D viewport with Name at the bottom
	  Image              →  shop style: image-based circular card with Name + Price

	All variants support: Equipped banner, OffSale overlay, Price label, hover/press spring.
]]
export type Props = {
	-- identity
	Name: string,
	Tier: string,

	-- variant selectors (provide exactly one group)
	Color: Color3?,           -- nametag: background color
	Animation: ColorAnimation?, -- nametag: animated color cycle (overrides Color)
	Model: Instance?,          -- pet: 3D model rendered in a viewport
	Image: string?,            -- shop: asset id used as background image

	-- optional
	Price: string?,
	TopBanner: Banner.Props?,
	Equipped: boolean?,
	OffSale: boolean?,

	-- layout
	LayoutOrder: number?,
	Size: UDim2?,
	OnClick: (() -> ())?,
}

return function(props: Props)
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)

	local active = not props.OffSale
	local priceVisible = active and (IS_MOBILE or isHovering)

	local isPet = props.Model ~= nil
	local isShop = not isPet and props.Image ~= nil
	-- else: nametag variant

	local tierColor = props.Tier and TIER_COLORS[props.Tier].Color or TIER_COLORS.Common.Color
	local springConfig = isPet and Styles.SPRING_CARD or Styles.SPRING_STANDARD

	local hoverStyles = ReactSpring.useSpring({
		scale           = active and (isPressing and 0.95 or (isHovering and (isPet and 1.1 or 1.08) or 1)) or 1,
		priceOpacity    = props.Price and (priceVisible and 0 or 1) or nil,
		imageTransparency = isShop and (active and ((not IS_MOBILE and isHovering) and 0.2 or 0) or 0) or nil,
		config = springConfig,
	})

	local strokeStyles = ReactSpring.useSpring({
		priceStrokeOpacity = props.Price and (priceVisible and 0 or 1) or nil,
		config = { mass = 0.5, tension = 15000, friction = 150 },
	})

	local startTime = React.useRef(os.clock())
	local clock = if props.Animation then useClock() else 0
	local displayColor: Color3 = props.Color or Color3.new(1, 1, 1)
	local displayTransparency: number = 0
	if props.Animation and #props.Animation.Frames > 0 then
		local elapsed = clock - startTime.current
		displayColor, displayTransparency = evalAnimation(props.Animation.Frames, elapsed)
	end

	local offSaleOverlay = props.OffSale and c(Pane, {
		ClassName = "Frame",
		CornerRadius = 1,
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
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.75, 0.22),
				Text = "Off Sale",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}),
	}) or nil

	local banner = props.TopBanner and c(Banner, {
		Size = UDim2.fromScale(1.05, 0.225),
		Text = props.TopBanner.Text,
		Color = props.TopBanner.Color,
	}) or nil

	local priceLabel = props.Price and c(Pane, {
		ClassName = "TextLabel",
		Stroke = { Thickness = 1.5, Transparency = strokeStyles.priceStrokeOpacity },
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = isShop and (props.TopBanner and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0.5, 0.15))
				or UDim2.fromScale(0.5, 0.15),
			Size = UDim2.fromScale(0.8, 0.213),
			Text = props.Price,
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = hoverStyles.priceOpacity,
			TextScaled = true,
		},
	}) or nil

	-- Container props differ by variant
	local nativeProps
	local stroke = (not isShop) and (active and { Color = tierColor, Thickness = 3 } or nil) or nil
	local cornerRadius = Styles.CORNER_FULL

	if isShop then
		nativeProps = {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Image = props.Image,
			ImageTransparency = hoverStyles.imageTransparency,
			LayoutOrder = props.LayoutOrder,
			Size = props.Size or UDim2.fromScale(1, 1),
		}
	elseif isPet then
		nativeProps = {
			AutoButtonColor = false,
			BackgroundColor3 = tierColor:Lerp(Color3.new(0, 0, 0), 0.2),
			BackgroundTransparency = 0,
			LayoutOrder = props.LayoutOrder,
			Size = props.Size or UDim2.fromScale(1, 1),
		}
	else
		-- nametag
		nativeProps = {
			AutoButtonColor = false,
			BackgroundColor3 = displayColor,
			BackgroundTransparency = displayTransparency,
			LayoutOrder = props.LayoutOrder,
			Size = props.Size or UDim2.fromScale(1, 1),
		}
	end

	local children

	if isPet then
		local petName = props.Name:gsub("Pet", "")
		children = {
			Viewport = c(ViewportModel, {
				Model = props.Model,
				Size = UDim2.fromScale(1, 0.78),
				ModelRotation = 15,
				ElevationAngle = 15,
				FieldOfView = 30,
			}),
			NameLabel = c(Pane, {
				ClassName = "TextLabel",
				Stroke = { Thickness = 1 },
				Native = {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.99),
					Size = UDim2.fromScale(0.9, 0.2),
					Text = petName,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				},
			}),
			Banner = banner,
			ProductPrice = priceLabel,
			OffSaleOverlay = offSaleOverlay,
		}
	elseif isShop then
		children = {
			ProductName = not props.OffSale and c(Pane, {
				ClassName = "TextLabel",
				Stroke = { Thickness = 1.5 },
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.825908),
					Size = UDim2.fromScale(0.8, 0.3554),
					Text = props.Name,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				},
			}) or nil,
			ProductPrice = priceLabel,
			Banner = banner,
			OffSaleOverlay = offSaleOverlay,
		}
	else
		-- nametag
		children = {
			ProductName = not props.OffSale and c(Pane, {
				ClassName = "TextLabel",
				Stroke = { Thickness = 1.5 },
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.48),
					Size = props.Tier and UDim2.fromScale(0.8, 0.22) or UDim2.fromScale(0.8, 0.4),
					Text = props.Name,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				},
			}) or nil,
			TierLabel = not props.OffSale and props.Tier and c(Pane, {
				ClassName = "TextLabel",
				Stroke = { Color = Color3.new(0, 0, 0), Thickness = 1.5 },
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.66),
					Size = UDim2.fromScale(0.7, 0.16),
					Text = props.Tier,
					TextColor3 = tierColor,
					TextScaled = true,
				},
			}) or nil,
			Banner = banner,
			ProductPrice = priceLabel,
			OffSaleOverlay = offSaleOverlay,
		}
	end

	return c(Pane, {
		ClassName = "ImageButton",
		Scale = hoverStyles.scale,
		AspectRatio = 1,
		CornerRadius = cornerRadius,
		Stroke = stroke,
		OnClick = active and props.OnClick or nil,
		OnPress = active and props.OnClick and function()
			setIsPressing(true)
		end or nil,
		OnRelease = active and props.OnClick and function()
			setIsPressing(false)
		end or nil,
		OnHover = active and props.OnClick and function()
			setIsHovering(true)
		end or nil,
		OnLeave = active and props.OnClick and function()
			setIsHovering(false)
			setIsPressing(false)
		end or nil,
		Native = nativeProps,
	}, children)
end

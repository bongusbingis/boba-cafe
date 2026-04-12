local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)

local Banner = require(UI.Components.Buttons.Banner)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local Pane = require(UI.Components.Pane)
local ViewportModel = require(UI.Components.ViewportModel)
local useClock = require(UI.Utility.useClock)
local Styles = require(UI.Styles)

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local IS_MOBILE = UserInputService.TouchEnabled
local TIER_COLORS = InventoryItemDefinitions.Tiers
local c = React.createElement

--------------------------------------------------------------------------------
-- Animation helpers
--------------------------------------------------------------------------------

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

--- Evaluates an animation keyframe sequence at a given elapsed time.
--- Returns the interpolated Color3 and transparency for that moment.
local function evalAnimation(frames: { any }, elapsed: number): (Color3, number)
	local totalDuration = 0
	for _, frame in ipairs(frames) do
		totalDuration += (frame.Transition or 0.5) + frame.Hold
	end

	local t = elapsed % totalDuration

	for i, frame in ipairs(frames) do
		local transition = frame.Transition or 0.5
		local segDuration = transition + frame.Hold

		if t <= segDuration then
			if t <= transition then
				local alpha = smoothstep(transition > 0 and (t / transition) or 1)
				local prevFrame = frames[((i - 2) % #frames) + 1]
				return prevFrame.Color:Lerp(frame.Color, alpha),
					lerp(prevFrame.Transparency or 0, frame.Transparency or 0, alpha)
			else
				return frame.Color, frame.Transparency or 0
			end
		end

		t -= segDuration
	end

	local last = frames[#frames]
	return last.Color, last.Transparency or 0
end

--------------------------------------------------------------------------------
-- Types
--------------------------------------------------------------------------------

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

	  Color / Animation  →  nametag: animated color swatch with Name + Tier labels
	  Model              →  pet: 3D viewport with Name at the bottom
	  Image              →  shop: image-based card with Name + optional Price

	All variants support: TopBanner, OffSale overlay, Price label, hover/press spring.
]]
export type Props = {
	-- identity
	Name: string,
	Tier: string,

	-- variant (provide exactly one group)
	Color: Color3?, -- nametag: static background color
	Animation: ColorAnimation?, -- nametag: animated color cycle (overrides Color)
	Model: Instance?, -- pet: 3D model rendered in a viewport
	Image: string?, -- shop: asset ID used as background image
	ImageSize: UDim2?, -- shop: optional image size override

	-- optional
	Price: string?,
	TopBanner: Banner.Props?,
	StackCount: number?, -- shows a ×N badge in the top-right corner when > 1
	Equipped: boolean?,
	OffSale: boolean?,

	-- layout
	ZIndex: number?,
	LayoutOrder: number?,
	Size: UDim2?,
	OnClick: (() -> ())?,
}

--------------------------------------------------------------------------------
-- Component helpers
--------------------------------------------------------------------------------

--- Resolves which layout variant is active based on props.
local function resolveVariant(props: Props): (boolean, boolean)
	local isPet = props.Model ~= nil
	local isShop = not isPet and props.Image ~= nil
	return isPet, isShop
end

--- Builds the name label's position and size based on the active variant.
local function resolveNameLayout(isPet: boolean, isShop: boolean, hasTier: boolean): (UDim2, UDim2)
	if isPet then
		-- Same text layout as nametags; viewport is sized to stay above.
		return UDim2.fromScale(0.5, 0.48), UDim2.fromScale(0.8, 0.22)
	elseif isShop and not hasTier then
		return UDim2.fromScale(0.5, 0.825908), UDim2.fromScale(0.8, 0.3554)
	elseif hasTier then
		return UDim2.fromScale(0.5, 0.48), UDim2.fromScale(0.8, 0.22)
	else
		return UDim2.fromScale(0.5, 0.48), UDim2.fromScale(0.8, 0.4)
	end
end

--- Resolves the price label position based on variant and banner presence.
local function resolvePricePosition(isShop: boolean, hasBanner: boolean): UDim2
	if isShop and hasBanner then
		return UDim2.fromScale(0.5, 0.5)
	end
	return UDim2.fromScale(0.5, 0.15)
end

--------------------------------------------------------------------------------
-- Child builders
--------------------------------------------------------------------------------

local function buildOffSaleOverlay()
	return c(Pane, {
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
	})
end

local function buildBanner(bannerProps: Banner.Props)
	return c(Banner, {
		Size = UDim2.fromScale(1.05, 0.225),
		Text = bannerProps.Text,
		Color = bannerProps.Color,
	})
end

local function buildPriceLabel(price: string, position: UDim2, springs: any, strokes: any)
	return c(Pane, {
		ClassName = "TextLabel",
		Stroke = { Thickness = 1.5, Transparency = strokes.priceStrokeOpacity },
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = position,
			Size = UDim2.fromScale(0.8, 0.213),
			Text = price,
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = springs.priceOpacity,
			TextScaled = true,
		},
	})
end

local function buildShopImage(image: string?, imageSize: UDim2?, tierColor: Color3?, imageTransparency: any)
	return c(Pane, {
		ClassName = "ImageLabel",
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = image,
			BackgroundColor3 = tierColor,
			ImageTransparency = imageTransparency,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = imageSize or UDim2.fromScale(0.675, 0.675),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 0,
		},
	})
end

local function buildViewport(model: Instance?)
	return c(ViewportModel, {
		Model = model,
		Size = UDim2.fromScale(1, 0.55),
		ModelRotation = 15,
		ElevationAngle = 15,
		FieldOfView = 30,
	})
end

local function buildNameLabel(text: string, _, size: UDim2, strokeThickness: number)
	return c(Pane, {
		ClassName = "TextLabel",
		Stroke = { Thickness = strokeThickness },
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.65),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.5, 0.625),
			Size = size,
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
		},
	})
end

local function buildCountBadge(count: number)
	return c("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BackgroundTransparency = 0.25,
		Position = UDim2.fromScale(1.0, 0.02),
		Size = UDim2.fromScale(0.38, 0.22),
		ZIndex = 10,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Label = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.85, 0.75),
			Text = "×" .. count,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 11,
		}),
	})
end

local function buildTierLabel(tier: string, tierColor: Color3?)
	return c(Pane, {
		ClassName = "TextLabel",
		Stroke = { Color = Color3.new(0, 0, 0), Thickness = 1.5 },
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.5, 0.75),
			Size = UDim2.fromScale(0.7, 0.16),
			Text = tier,
			TextColor3 = tierColor or Styles.OFFWHITE,
			TextScaled = true,
		},
	})
end

--------------------------------------------------------------------------------
-- Component
--------------------------------------------------------------------------------

return function(props: Props)
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)

	local isPet, isShop = resolveVariant(props)
	local isActive = not props.OffSale
	local isInteractive = isActive and props.OnClick ~= nil
	local priceVisible = isActive and (IS_MOBILE or isHovering)

	local tierColor = props.Tier and TIER_COLORS[props.Tier].Color or nil

	-- Springs
	local hoverScale = isActive and (isPressing and 0.95 or (isHovering and (isPet and 1.1 or 1.08) or 1)) or 1

	local springs = ReactSpring.useSpring({
		scale = hoverScale,
		priceOpacity = props.Price and (priceVisible and 0 or 1) or nil,
		imageTransparency = isShop and (isActive and ((not IS_MOBILE and isHovering) and 0.2 or 0) or 0) or nil,
		config = isPet and Styles.SPRING_CARD or Styles.SPRING_STANDARD,
	})

	local strokes = ReactSpring.useSpring({
		priceStrokeOpacity = props.Price and (priceVisible and 0 or 1) or nil,
		config = { mass = 0.5, tension = 15000, friction = 150 },
	})

	-- Animated background color (nametag variant)
	local startTime = React.useRef(os.clock())
	local clock = if props.Animation then useClock() else 0
	local displayColor: Color3 = props.Color or Color3.new(1, 1, 1)
	local displayTransparency: number = 0
	if props.Animation and #props.Animation.Frames > 0 then
		displayColor, displayTransparency = evalAnimation(props.Animation.Frames, clock - startTime.current)
	end

	-- Layout
	local namePosition, nameSize = resolveNameLayout(isPet, isShop, props.Tier ~= nil)
	local nameText = isPet and props.Name:gsub("Pet", "") or props.Name
	local nameVisible = isPet or not props.OffSale

	-- Children
	local children = {
		ShopImage = isShop and buildShopImage(props.Image, props.ImageSize, tierColor, springs.imageTransparency)
			or nil,
		Viewport = isPet and buildViewport(props.Model) or nil,

		ProductName = nameVisible and buildNameLabel(nameText, namePosition, nameSize, isPet and 1 or 1.5) or nil,

		TierLabel = (not props.OffSale and props.Tier) and buildTierLabel(props.Tier, tierColor) or nil,

		Banner = props.TopBanner and buildBanner(props.TopBanner) or nil,
		CountBadge = (props.StackCount and props.StackCount > 1) and buildCountBadge(props.StackCount) or nil,
		ProductPrice = props.Price
				and buildPriceLabel(props.Price, resolvePricePosition(isShop, props.TopBanner ~= nil), springs, strokes)
			or nil,
		OffSaleOverlay = props.OffSale and buildOffSaleOverlay() or nil,
	}

	-- Background color: pet/shop use tier tint; nametag uses animated color
	local backgroundColor = (isPet or isShop)
			and (tierColor and tierColor:Lerp(Color3.new(1, 1, 1), 0.2) or Color3.new(1, 1, 1))
		or displayColor

	local backgroundTransparency = isPet and 0 or isShop and 0 or displayTransparency

	return c(Pane, {
		ClassName = "ImageButton",
		Scale = springs.scale,
		AspectRatio = 1,
		CornerRadius = Styles.CORNER_FULL,
		Stroke = (isActive and props.Tier) and { Color = tierColor, Thickness = 3 } or nil,

		OnClick = isInteractive and props.OnClick or nil,
		OnPress = isInteractive and function()
			setIsPressing(true)
		end or nil,
		OnRelease = isInteractive and function()
			setIsPressing(false)
		end or nil,
		OnHover = isInteractive and function()
			setIsHovering(true)
		end or nil,
		OnLeave = isInteractive and function()
			setIsHovering(false)
			setIsPressing(false)
		end or nil,

		Native = {
			AutoButtonColor = false,
			BackgroundColor3 = backgroundColor,
			BackgroundTransparency = backgroundTransparency,
			LayoutOrder = props.LayoutOrder,
			Size = props.Size or UDim2.fromScale(1, 1),
			ZIndex = props.ZIndex,
		},
	}, children)
end

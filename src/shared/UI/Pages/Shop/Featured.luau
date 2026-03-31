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

---> private
local c = React.createElement

---> theme
local ROSE = Color3.fromRGB(255, 182, 193)
local ROSE_MID = Color3.fromRGB(230, 145, 165)
local ROSE_DEEP = Color3.fromRGB(180, 80, 100)
local BADGE_GREEN = Color3.fromRGB(72, 199, 116)

local CARD_SPRING = { mass = 1, tension = 10000, friction = 200 }

---> animation helpers (mirrors NametagCard)
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

---> types
export type AnimFrame = {
	Color: Color3,
	Transparency: number?,
	Hold: number,
	Transition: number?,
}

export type TrendingItem = {
	Name: string,
	Price: string,
	-- "pass" or "pet" → image circle; "cosmetic" → colored circle
	Type: "pass" | "pet" | "cosmetic",
	-- pass / pet
	Image: string?,
	-- cosmetic
	Color: Color3?,
	TierColor: Color3?,
	Tier: string?,
	Animation: { Frames: { AnimFrame } }?,
}

---> mock data (swap with server data later)
local HERO_ITEM = {
	Name = "VIP Pass",
	Price = " 299",
	Image = "rbxassetid://5893760810",
	Description = "Exclusive perks, custom chat tag, and priority seating at the café.",
}

local TRENDING_ITEMS: { TrendingItem } = {
	{
		Name = "Shift Lead",
		Price = " 499",
		Type = "pass",
		Image = "rbxassetid://5893760810",
	},
	{
		Name = "Aurora",
		Price = " 500",
		Type = "cosmetic",
		Color = Color3.fromRGB(80, 200, 255),
		TierColor = Color3.fromRGB(80, 150, 255),
		Tier = "Rare",
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(80, 200, 255), Hold = 0, Transition = 1.2 },
				{ Color = Color3.fromRGB(140, 100, 255), Hold = 0, Transition = 1.2 },
				{ Color = Color3.fromRGB(50, 220, 180), Hold = 0, Transition = 1.2 },
			},
		},
	},
	{
		Name = "Epic Capsule",
		Price = " 149",
		Type = "pet",
		Image = "rbxassetid://5893760810",
	},
	{
		Name = "Gold Tag",
		Price = " 350",
		Type = "cosmetic",
		Color = Color3.fromRGB(255, 215, 37),
		TierColor = Color3.fromRGB(255, 185, 30),
		Tier = "Uncommon",
	},
	{
		Name = "2x Boba Bucks",
		Price = " 399",
		Type = "pass",
		Image = "rbxassetid://5893760810",
	},
}

---> Hero card — large spotlight for the #1 trending item
local function HeroCard(props)
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)

	local styles = ReactSpring.useSpring({
		strokeThickness = isPressing and 2.5 or (isHovering and 6.5 or 4),
		config = CARD_SPRING,
	})

	return c(Pane, {
		ClassName = "ImageButton",
		CornerRadius = UDim.new(0.06, 0),
		Stroke = { Color = ROSE_MID, Thickness = styles.strokeThickness },
		OnPress = function()
			setIsPressing(true)
		end,
		OnRelease = function()
			setIsPressing(false)
		end,
		OnHover = function()
			setIsHovering(true)
		end,
		OnLeave = function()
			setIsHovering(false)
			setIsPressing(false)
		end,
		Native = {
			AutoButtonColor = false,
			BackgroundColor3 = ROSE,
			Size = UDim2.fromScale(1, 1),
		},
	}, {
		-- Product image, left half
		Image = c("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = props.Item.Image,
			Position = UDim2.fromScale(-0.05, 0.5),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.43, 0.82),
		}),

		-- Info panel, right half
		Info = c("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.975, 0.5),
			Size = UDim2.fromScale(0.65, 0.88),
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0.06, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			Badge = c(Pane, {
				ClassName = "TextLabel",
				CornerRadius = UDim.new(1, 0),
				Stroke = {
					Color = ROSE_MID,
					Thickness = 2.5,
				},
				Native = {
					BackgroundTransparency = 0.5,
					BackgroundColor3 = BADGE_GREEN,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					LayoutOrder = 0,
					Size = UDim2.fromScale(0.92, 0.18),
					Text = "🔥  #1 Trending",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					Position = UDim2.fromScale(-0.05, -0.02),
				},
			}),

			Name = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0.22),
				Text = props.Item.Name,
				TextColor3 = ROSE_DEEP,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Desc = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0.29),
				Text = props.Item.Description,
				TextColor3 = Color3.fromRGB(110, 50, 65),
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			PriceRow = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				Size = UDim2.fromScale(1, 0.18),
			}, {
				Pill = c(Pane, {
					ClassName = "TextLabel",
					CornerRadius = UDim.new(0.4, 0),
					Native = {
						BackgroundColor3 = ROSE_DEEP,
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Size = UDim2.fromScale(0.78, 1),
						Text = props.Item.Price,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
					},
				}),
			}),
		}),
	})
end

---> Small card for the "Hot Right Now" row — handles passes, pets, and cosmetics
local function TrendingCard(props: TrendingItem)
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)

	local styles = ReactSpring.useSpring({
		scale = isPressing and 0.92 or (isHovering and 1.1 or 1),
		config = CARD_SPRING,
	})

	-- Animated color for cosmetics (only ticks when animation is present)
	local startTime = React.useRef(os.clock())
	local clock = if props.Animation then useClock() else 0

	local displayColor: Color3 = props.Color or Color3.new(1, 1, 1)
	local displayTransparency: number = 0
	if props.Animation and #props.Animation.Frames > 0 then
		local elapsed = clock - startTime.current
		displayColor, displayTransparency = evalAnimation(props.Animation.Frames, elapsed)
	end

	local isCosmetic = props.Type == "cosmetic"

	return c(Pane, {
		ClassName = "ImageButton",
		CornerRadius = UDim.new(1, 0),
		Scale = styles.scale,
		-- Tier-colored stroke on cosmetics
		Stroke = isCosmetic and props.TierColor and { Color = props.TierColor, Thickness = 3 } or nil,
		OnPress = function()
			setIsPressing(true)
		end,
		OnRelease = function()
			setIsPressing(false)
		end,
		OnHover = function()
			setIsHovering(true)
		end,
		OnLeave = function()
			setIsHovering(false)
			setIsPressing(false)
		end,
		Native = {
			AutoButtonColor = false,
			-- Cosmetics fill with color; passes/pets use the image
			BackgroundColor3 = isCosmetic and displayColor or Color3.new(1, 1, 1),
			BackgroundTransparency = isCosmetic and displayTransparency or 1,
			Image = (not isCosmetic) and (props.Image or "") or nil,
			-- AnchorPoint + Position centered so UIScale scales from the middle
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
		},
	}, {
		-- Price always visible at top on the Featured page (browsing context)
		Price = c(Pane, {
			ClassName = "TextLabel",
			Stroke = { Thickness = 1.5 },
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, 0.175),
				Size = UDim2.fromScale(0.8, 0.22),
				Text = props.Price,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}),

		-- Name label (higher for cosmetics to leave room for tier)
		Name = c(Pane, {
			ClassName = "TextLabel",
			Stroke = { Thickness = 1.5 },
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, isCosmetic and 0.52 or 0.825),
				Size = UDim2.fromScale(0.8, 0.22),
				Text = props.Name,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}),

		-- Tier label — cosmetics only
		Tier = isCosmetic and props.Tier and c(Pane, {
			ClassName = "TextLabel",
			Stroke = { Color = Color3.new(0, 0, 0), Thickness = 1.5 },
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, 0.70),
				Size = UDim2.fromScale(0.7, 0.18),
				Text = props.Tier,
				TextColor3 = props.TierColor or Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}) or nil,
	})
end

---> public
return function()
	local trendingChildren = {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.03, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = c("UIPadding", {
			PaddingLeft = UDim.new(0.025, 0),
			PaddingRight = UDim.new(0.025, 0),
		}),
	}

	for i, item in ipairs(TRENDING_ITEMS) do
		trendingChildren["slot_" .. i] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = i,
			Size = UDim2.fromScale(0.88, 0.88),
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
		}, {
			Card = c(TrendingCard, item),
		})
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Title = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.03, 0),
			Size = UDim2.fromScale(0.94, 0.09),
			Text = "Featured",
			TextColor3 = ROSE_MID,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextScaled = true,
		}),

		HeroContainer = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.1),
			Size = UDim2.fromScale(0.94, 0.35),
		}, {
			Card = c(HeroCard, { Item = HERO_ITEM }),
		}),

		TrendingLabel = c("TextLabel", {
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.03, 0.478),
			Size = UDim2.fromScale(0.55, 0.065),
			Text = "Hot Right Now",
			TextColor3 = ROSE_DEEP,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		TrendingRow = c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.555),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarImageTransparency = 1,
			ScrollBarThickness = 4,
			ScrollingDirection = Enum.ScrollingDirection.X,
			Size = UDim2.fromScale(1, 0.41),
		}, trendingChildren),
	})
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
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
local GREEN_DEEP = Color3.fromRGB(99, 129, 91)
local GREEN = Color3.fromRGB(138, 173, 125)

local CARD_SPRING = { mass = 1, tension = 10000, friction = 200 }
local INTERACTION_VERB = UserInputService.TouchEnabled and "Tap" or "Click"

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

local RANKS = {
	{
		Name = "Barista",
		Price = "299",
		Image = "rbxassetid://5893760810",
		Description = "Serve up delicious drinks and earn exclusive rewards as a Barista!",
	},
	{
		Name = "Kitchen Leader",
		Price = "299",
		Image = "rbxassetid://5893760810",
		Description = "Serve up delicious drinks and earn exclusive rewards as a Kitchen Leader!",
	},
}

---> Hero card — large spotlight for the #1 trending item
local function HeroCard(props)
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)

	local styles = ReactSpring.useSpring({
		strokeThickness = isPressing and 2.5 or (isHovering and 5 or 3),
		config = CARD_SPRING,
	})

	return c(Pane, {
		ClassName = "ImageButton",
		CornerRadius = UDim.new(0.06, 0),
		Stroke = { Color = GREEN, Thickness = styles.strokeThickness },
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

			Name = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0.22),
				Text = props.Item.Name,
				TextColor3 = GREEN,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Desc = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0.29),
				Text = props.Item.Description,
				TextColor3 = GREEN_DEEP,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			PriceRow = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				Size = UDim2.fromScale(0.3, 0.2),
			}, {
				Pill = c(Pane, {
					ClassName = "TextLabel",
					CornerRadius = UDim.new(1, 0),
					Native = {
						FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
						Size = UDim2.fromScale(0.78, 1),
						Text = props.Item.Price,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Center,
						BackgroundTransparency = 0,
						BackgroundColor3 = GREEN,
					},
				}),
			}),
		}),
	})
end

local function heroContainer(props)
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.1),
		Size = UDim2.fromScale(0.94, 0.35),
	}, c(HeroCard, { Item = props.Rank }))
end

---> public
return function()
	local heroCardsToRender = {}
	for _, rank in RANKS do
		table.insert(heroCardsToRender, c(heroContainer, {Rank = rank}))
	end

	table.insert(heroCardsToRender, c("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0.05, 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}))

	table.insert(heroCardsToRender, c("UIPadding", {
		PaddingTop = UDim.new(0.075, 0),
	}))

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, heroCardsToRender)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local NametagCard = require(UI.Components.Buttons.NametagCard)

---> private
local c = React.createElement

---> tier colors
local TIER_COLORS = {
	Basic     = Color3.fromRGB(190, 190, 190),
	Uncommon  = Color3.fromRGB(80,  200, 120),
	Rare      = Color3.fromRGB(80,  150, 255),
	Epic      = Color3.fromRGB(180, 80,  255),
	Legendary = Color3.fromRGB(255, 185, 30),
	Special   = Color3.fromRGB(255, 150, 40),
}

---> mock data (replace with server-provided data)
export type NametagColor = {
	Name: string,
	Tier: string,
	Color: Color3,
	Price: string,
	Animation: NametagCard.ColorAnimation?,
	OffSale: boolean?,
}

local NAMETAG_COLORS: { NametagColor } = {
	---> static
	{
		Name  = "Crimson",
		Tier  = "Basic",
		Color = Color3.fromRGB(220, 50, 50),
		Price = " 150",
	},
	{
		Name  = "Ocean",
		Tier  = "Basic",
		Color = Color3.fromRGB(50, 150, 220),
		Price = " 150",
	},
	{
		Name  = "Emerald",
		Tier  = "Basic",
		Color = Color3.fromRGB(50, 180, 90),
		Price = " 150",
	},
	{
		Name  = "Gold",
		Tier  = "Uncommon",
		Color = Color3.fromRGB(255, 200, 50),
		Price = " 200",
	},

	---> animated
	{
		Name  = "Bubblegum",
		Tier  = "Uncommon",
		Color = Color3.fromRGB(255, 100, 180),
		Price = " 350",
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(255, 100, 180), Transparency = 0,   Hold = 0, Transition = 0.8 },
				{ Color = Color3.fromRGB(255, 100, 180), Transparency = 0.5, Hold = 0, Transition = 0.8 },
			},
		},
	},
	{
		Name  = "Sunset",
		Tier  = "Rare",
		Color = Color3.fromRGB(255, 100, 50),
		Price = " 400",
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(255, 80,  50),  Hold = 0, Transition = 1.2 },
				{ Color = Color3.fromRGB(255, 190, 50),  Hold = 0, Transition = 1.2 },
				{ Color = Color3.fromRGB(255, 50,  100), Hold = 0, Transition = 1.2 },
			},
		},
	},
	{
		Name  = "Aurora",
		Tier  = "Rare",
		Color = Color3.fromRGB(100, 255, 200),
		Price = " 500",
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(100, 255, 200), Hold = 0, Transition = 1.0 },
				{ Color = Color3.fromRGB(100, 200, 255), Hold = 0, Transition = 1.0 },
				{ Color = Color3.fromRGB(160, 100, 255), Hold = 0, Transition = 1.0 },
				{ Color = Color3.fromRGB(255, 100, 200), Hold = 0, Transition = 1.0 },
			},
		},
	},
	{
		Name  = "Void",
		Tier  = "Epic",
		Color = Color3.fromRGB(80, 50, 150),
		Price = " 600",
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(80,  50,  150), Transparency = 0,    Hold = 0, Transition = 2.0 },
				{ Color = Color3.fromRGB(30,  20,  80),  Transparency = 0.35, Hold = 0, Transition = 2.0 },
			},
		},
	},
	{
		Name  = "Prism",
		Tier  = "Legendary",
		Color = Color3.fromRGB(255, 50, 50),
		Price = " 800",
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(255, 50,  50),  Hold = 0, Transition = 0.45 },
				{ Color = Color3.fromRGB(255, 165, 50),  Hold = 0, Transition = 0.45 },
				{ Color = Color3.fromRGB(255, 255, 50),  Hold = 0, Transition = 0.45 },
				{ Color = Color3.fromRGB(50,  220, 80),  Hold = 0, Transition = 0.45 },
				{ Color = Color3.fromRGB(50,  150, 255), Hold = 0, Transition = 0.45 },
				{ Color = Color3.fromRGB(180, 50,  255), Hold = 0, Transition = 0.45 },
			},
		},
	},
	{
		Name    = "Valentine",
		Tier    = "Special",
		Color   = Color3.fromRGB(255, 120, 150),
		Price   = " 300",
		OffSale = true,
		Animation = {
			Frames = {
				{ Color = Color3.fromRGB(255, 120, 150), Hold = 1.0, Transition = 0.8 },
				{ Color = Color3.fromRGB(255, 50,  100), Hold = 1.0, Transition = 0.8 },
			},
		},
	},
}

---> public
return function()
	local onSaleCount = 0
	for _, entry in ipairs(NAMETAG_COLORS) do
		if not entry.OffSale then
			onSaleCount += 1
		end
	end

	local onSaleIndex, offSaleIndex = 0, onSaleCount
	local gridChildren = {
		UIGridLayout = c("UIGridLayout", {
			CellPadding = UDim2.fromScale(0.043, 0.03),
			CellSize = UDim2.fromScale(0.212, 0.288),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = c("UIPadding", {
			PaddingTop    = UDim.new(0.02, 0),
			PaddingBottom = UDim.new(0.02, 0),
			PaddingLeft   = UDim.new(0.02, 0),
			PaddingRight  = UDim.new(0.02, 0),
		}),
	}

	for _, entry in ipairs(NAMETAG_COLORS) do
		local layoutOrder
		if entry.OffSale then
			offSaleIndex += 1
			layoutOrder = offSaleIndex
		else
			onSaleIndex += 1
			layoutOrder = onSaleIndex
		end

		gridChildren[entry.Name] = c(NametagCard, {
			Name        = entry.Name,
			Price       = entry.Price,
			Tier        = entry.Tier,
			TierColor   = TIER_COLORS[entry.Tier] or TIER_COLORS.Basic,
			Color       = entry.Color,
			Animation   = entry.Animation,
			OffSale     = entry.OffSale,
			LayoutOrder = layoutOrder,
		})
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Title = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
			Position = UDim2.fromScale(0.470149, 0),
			Size = UDim2.fromScale(0.94, 0.09),
			Text = "Nametag Colors",
			TextColor3 = Color3.fromRGB(143, 169, 127),
			TextScaled = true,
		}),

		Grid = c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.112),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarImageTransparency = 1,
			ScrollBarThickness = 5,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1.02, 0.888),
		}, gridChildren),
	})
end

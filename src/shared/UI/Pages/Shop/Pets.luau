local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> components
local ShopCard = require(UI.Components.Buttons.ShopCard)

---> private
local c = React.createElement

---> mock data (replace with server-provided data)
export type Egg = {
	Name: string,
	Icon: string,
	Price: string,
	OffSale: boolean?,
}

local EGGS: { Egg } = {
	{
		Name  = "Regular Pet Capsule",
		Icon  = "rbxassetid://6073658218",
		Price = " 75",
	},
	{
		Name  = "Rare Pet Capsule",
		Icon  = "rbxassetid://7621095542",
		Price = " 250",
	},
	{
		Name  = "Epic Pet Capsule",
		Icon  = "rbxassetid://9369156094",
		Price = " 800",
	},
	{
		Name    = "Halloween Capsule",
		Icon    = "rbxassetid://7621096000",
		Price   = " 500",
		OffSale = true,
	},
	{
		Name    = "Christmas Capsule",
		Icon    = "rbxassetid://8097926532",
		Price   = " 500",
		OffSale = true,
	},
	{
		Name    = "Fall Capsule",
		Icon    = "rbxassetid://11007702975",
		Price   = " 500",
		OffSale = true,
	},
}

---> public
return function()
	local onSaleCount = 0
	for _, egg in ipairs(EGGS) do
		if not egg.OffSale then
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
			PaddingTop = UDim.new(0.02, 0),
			PaddingBottom = UDim.new(0.02, 0),
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
		}),
	}

	for _, egg in ipairs(EGGS) do
		local layoutOrder
		if egg.OffSale then
			offSaleIndex += 1
			layoutOrder = offSaleIndex
		else
			onSaleIndex += 1
			layoutOrder = onSaleIndex
		end

		gridChildren[egg.Name] = c(ShopCard, {
			Name = egg.Name,
			Price = egg.Price,
			Image = egg.Icon,
			OffSale = egg.OffSale,
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
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.470149, 0),
			Size = UDim2.fromScale(0.94, 0.09),
			Text = "Pets",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		Hint = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.5, 0.095),
			Size = UDim2.fromScale(0.94, 0.055),
			Text = "Purchase capsules to hatch your own pets!",
			TextColor3 = Styles.GRAY,
			TextScaled = true,
		}),

		Grid = c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.175),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarImageTransparency = 1,
			ScrollBarThickness = 5,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1.02, 0.825),
		}, gridChildren),
	})
end

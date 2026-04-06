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
export type Pass = {
	Name: string,
	Price: string,
	Image: string,
	OffSale: boolean?,
}

local PASSES: { Pass } = {
	{ Name = "Barista",       Price = " 199", Image = "rbxassetid://5893760810" },
	{ Name = "Shift Lead",    Price = " 499", Image = "rbxassetid://5893760810" },
	{ Name = "Manager",       Price = " 999", Image = "rbxassetid://5893760810" },
	{ Name = "VIP",           Price = " 299", Image = "rbxassetid://5893760810" },
	{ Name = "2x Boba Bucks", Price = " 399", Image = "rbxassetid://5893760810" },
	{ Name = "Premium",       Price = " 799", Image = "rbxassetid://5893760810", OffSale = true },
}

---> public
return function()
	local onSaleCount = 0
	for _, pass in ipairs(PASSES) do
		if not pass.OffSale then
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

	for _, pass in ipairs(PASSES) do
		local layoutOrder
		if pass.OffSale then
			offSaleIndex += 1
			layoutOrder = offSaleIndex
		else
			onSaleIndex += 1
			layoutOrder = onSaleIndex
		end

		gridChildren[pass.Name] = c(ShopCard, {
			Name = pass.Name,
			Price = pass.Price,
			Image = pass.Image,
			ImageSize = UDim2.fromScale(1, 1),
			OffSale = pass.OffSale,
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
			Text = "Game Passes",
			TextColor3 = Styles.GREEN,
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

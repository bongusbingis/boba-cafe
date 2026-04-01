local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> components
local ShopCategory = require(script.Parent.ShopCategory)

---> private
local c = React.createElement

---> mock data (replace with server-provided data)
local SHOP_DATA: { BobaBucks: { ShopCategory.Item }, Points: { ShopCategory.Item } } = {
	BobaBucks = {
		{ Label = "50 Boba Bucks",     Price = " 500" },
		{ Label = "150 Boba Bucks",    Price = " 1,300" },
		{ Label = "500 Boba Bucks",    Price = " 3,500" },
		{ Label = "1,000 Boba Bucks",  Price = " 6,000" },
		{ Label = "5,000 Boba Bucks",  Price = " 20,000" },
	},
	Points = {
		{ Label = "100 Points",    Price = " 500" },
		{ Label = "500 Points",    Price = " 2,000" },
		{ Label = "1,500 Points",  Price = " 5,000" },
		{ Label = "5,000 Points",  Price = " 15,000" },
		{ Label = "15,000 Points", Price = " 40,000" },
	},
}

---> public
return function()
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
			Text = "Currency",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		Categories = c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.112),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarThickness = 5,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1, 0.888),
		}, {
			UIListLayout = c("UIListLayout", {
				Padding = UDim.new(0.02, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			BobaBucks = c(ShopCategory, {
				Title = "Boba Bucks",
				Items = SHOP_DATA.BobaBucks,
				LayoutOrder = 0,
			}),

			Points = c(ShopCategory, {
				Title = "Points",
				Items = SHOP_DATA.Points,
				LayoutOrder = 1,
			}),

			Spacer = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = math.huge,
				Size = UDim2.fromScale(1, 0.05),
			}),
		}),
	})
end

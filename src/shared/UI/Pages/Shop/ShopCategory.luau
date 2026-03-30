local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local Pane = require(UI.Components.Pane)
local ShopItem = require(UI.Components.Buttons.ShopItem)

---> private
local c = React.createElement

---> public
export type Item = {
	Label: string,
	Price: string,
}

export type Props = {
	Title: string,
	Items: { Item },
	LayoutOrder: number?,
	OnPurchase: ((item: Item) -> ())?,
}

return function(props: Props)
	local children = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0.0055, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		Header = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				BackgroundTransparency = 1,
				Image = "http://www.roblox.com/asset/?id=13465572823",
				ImageColor3 = Color3.fromRGB(136, 170, 122),
				Size = UDim2.fromScale(0.981, 0.065),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
				SliceCenter = Rect.new(0, 0, 1019, 40),
			},
		}, {
			Title = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.5, 0.132084),
					Size = UDim2.fromScale(0.94, 0.7),
					Text = props.Title,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			}),
		}),

		Footer = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				BackgroundTransparency = 1,
				Image = "http://www.roblox.com/asset/?id=13465749908",
				ImageColor3 = Color3.fromRGB(151, 190, 135),
				LayoutOrder = 999999999,
				Size = UDim2.fromScale(0.981, 0.02),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
			},
		}),
	}

	for i, item in ipairs(props.Items) do
		children[item.Label] = c(ShopItem, {
			Label = item.Label,
			Price = item.Price,
			LayoutOrder = i,
			OnClick = if props.OnPurchase then function()
				props.OnPurchase(item)
			end else nil,
		})
	end

	return c("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0),
	}, children)
end

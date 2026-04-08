local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local SelectionCard = require(UI.Components.Buttons.SelectionCard)

local c = React.createElement

return function(props)
	local children = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Wraps = true,
			Padding = UDim.new(0.05, 0),
		}),
	}

	for categoryKey, data in props.FoodTable do
		children[categoryKey] = c(SelectionCard, {
			Text = categoryKey,
			Color = data.Color,
			Icon = data.Icon,
			Size = UDim2.fromOffset(props.CardSize, props.CardSize),
			LayoutOrder = data.LayoutOrder or 0,
			OnClick = function()
				props.OnCategorySelected(categoryKey)
			end,
		})
	end

	return c("ScrollingFrame", {
		Active = true,
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		Position = UDim2.fromScale(0.518627, 0.5),
		ScrollBarImageColor3 = Color3.new(),
		ScrollBarThickness = 5,
		Size = UDim2.fromScale(0.964196, 0.9),
	}, children)
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local SelectionCard = require(UI.Components.Buttons.SelectionCard)

local c = React.createElement

return function(props)
	if not props.SelectedCategory then
		return nil
	end

	local catData = props.FoodTable[props.SelectedCategory]
	if not catData then
		return nil
	end

	local children = {
		UIGridLayout = c("UIGridLayout", {
			CellPadding = UDim2.fromScale(0.039, 0.065),
			CellSize = UDim2.fromScale(0.199, 0.35),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for itemKey, itemData in catData.Items do
		children[itemKey] = c(SelectionCard, {
			Text = itemData.ItemName or itemKey,
			Color = itemData.Color or catData.Color,
			LayoutOrder = itemData.LayoutOrder or 0,
			OnClick = function()
				props.OnItemSelected(itemKey)
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
		Size = UDim2.fromScale(0.965, 0.9),
	}, children)
end

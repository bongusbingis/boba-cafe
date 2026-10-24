local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local SelectionCard = require(UI.Components.Buttons.SelectionCard)

local c = React.createElement

return function(props)
	local step = props.Step
	if not step then
		return nil
	end

	local children = {
		UIGridLayout = c("UIGridLayout", {
			CellPadding = UDim2.fromScale(0.039, 0.065),
			CellSize = UDim2.fromScale(0.199, 0.35),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local sortedKeys = {}
	for optionKey in step.options do
		table.insert(sortedKeys, optionKey)
	end
	table.sort(sortedKeys, function(a, b)
		if a == b then
			return false
		end
		if a == "Normal" then
			return true
		elseif b == "Normal" then
			return false
		end
		return a < b
	end)

	for order, optionKey in ipairs(sortedKeys) do
		local optionData = step.options[optionKey]
		local isSelected = props.CustomInfo[step.name] == optionKey
		children[optionKey] = c(SelectionCard, {
			Text = optionKey,
			Color = optionData.Color,
			LayoutOrder = order,
			Highlighted = isSelected,
			OnClick = function()
				props.OnOptionPicked(optionKey)
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

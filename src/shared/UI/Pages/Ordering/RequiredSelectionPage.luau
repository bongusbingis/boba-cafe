local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local Pane = require(UI.Components.Pane)
local SelectionCard = require(UI.Components.Buttons.SelectionCard)
local Styles = require(UI.Styles)

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

	local order = 0
	for optionKey, optionData in step.options do
		order += 1
		local isSelected = props.CustomInfo[step.name] == optionKey
		children[optionKey] = c(SelectionCard, {
			Text = optionKey,
			Color = optionData.Color,
			LayoutOrder = order,
			OnClick = function()
				props.OnOptionPicked(optionKey)
			end,
		})

		if isSelected then
			children[optionKey] = c(Pane, {
				ClassName = "Frame",
				Stroke = {
					Color = Styles.GOLD_BADGE,
					Thickness = 3,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				},
				Native = {
					BackgroundTransparency = 1,
					LayoutOrder = order,
				},
			}, {
				Card = c(SelectionCard, {
					Text = optionKey,
					Color = optionData.Color,
					OnClick = function()
						props.OnOptionPicked(optionKey)
					end,
				}),
			})
		end
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

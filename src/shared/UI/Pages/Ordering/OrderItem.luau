--[[
	OrderItem
	A single item row in the order summary list.
	Displays the item name, a description of selected options, a remove button,
	and a separator line.

	Props:
	- Name: Item display name (e.g. "Custom Boba").
	- Description: Rich-text description of options (e.g. "Tapioca: Tutti Frutti<br />Syrup: Blueberry").
	- LayoutOrder: Layout ordering.
	- OnRemove: Callback fired when the remove button is pressed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local Pane = require(UI.Components.Pane)

---> styles
local Styles = require(UI.Styles)

---> constants
local REMOVE_ICON = "http://www.roblox.com/asset/?id=13934199293"
local DESC_FONT = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)

---> private
local c = React.createElement
local usePx = require(UI.Hooks.usePx)

---> public
return function(props: {
	Name: string,
	Description: string,
	LayoutOrder: number?,
	OnRemove: (() -> ())?,
})
	local px = usePx()

	return c(Pane, {
		ClassName = "Frame",
		ListLayout = {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		Native = {
			AnchorPoint = Vector2.new(0, 0.5),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromScale(1, 0),
		},
	}, {
		NameRow = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = 1,
				Position = UDim2.fromScale(0.40495, 0),
				Size = UDim2.new(0.809899, 0, 0, px(30)),
				Text = props.Name,
				TextColor3 = Color3.new(),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}, {
			Remove = props.OnRemove and c(Pane, {
				ClassName = "ImageButton",
				OnClick = props.OnRemove,
				AspectRatio = 1,
				Native = {
					AnchorPoint = Vector2.new(0, 0),
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					Image = REMOVE_ICON,
					ImageColor3 = Styles.GRAY,
					Position = UDim2.fromScale(0.95, 0.18),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.45, 0.45),
				},
			}) or nil,
		}),

		Description = props.Description ~= "" and c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = DESC_FONT,
				LayoutOrder = 2,
				RichText = true,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Text = props.Description,
				TextColor3 = Color3.new(),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			},
		}, {
			UITextSizeConstraint = c("UITextSizeConstraint", {
				MaxTextSize = 25,
			}),
		}),

		Separator = c(Pane, {
			ClassName = "Frame",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.fromRGB(202, 202, 202),
				BackgroundTransparency = 0,
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 1),
			},
		}),
	})
end

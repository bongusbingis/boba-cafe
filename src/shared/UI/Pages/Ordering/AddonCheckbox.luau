--[[
	AddonCheckbox
	A checkbox row for toggling an optional drink add-on (e.g. Iced, Sugar).
	Renders a checkbox image with a fill overlay that appears when checked,
	alongside a text label.

	Props:
	- Label: Display text for the add-on name.
	- Color: Accent color for the checked fill and label. Defaults to ORANGE.
	- Checked: Whether the checkbox is currently checked.
	- LayoutOrder: Layout ordering.
	- OnToggle: Callback fired when the checkbox is pressed.
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
local ORANGE = Color3.fromRGB(237, 114, 47)
local CHECKBOX_IMAGE = "http://www.roblox.com/asset/?id=13752189617"
local CHECKBOX_FILL_IMAGE = "http://www.roblox.com/asset/?id=13752240807"

---> private
local c = React.createElement

---> public
return function(props: {
	Label: string,
	Color: Color3?,
	Checked: boolean?,
	LayoutOrder: number?,
	OnToggle: (() -> ())?,
})
	local color = props.Color or ORANGE

	return c(Pane, {
		ClassName = "Frame",
		Native = {
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromScale(1, 0.2625),
		},
	}, {
		Checkbox = c(Pane, {
			ClassName = "ImageButton",
			OnClick = props.OnToggle,
			Native = {
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Image = CHECKBOX_IMAGE,
				ImageColor3 = Styles.GRAY,
				LayoutOrder = 1,
				ResampleMode = Enum.ResamplerMode.Pixelated,
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.0458515, 1),
				ZIndex = 2,
			},
		}, {
			Fill = c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					BackgroundTransparency = 1,
					Image = CHECKBOX_FILL_IMAGE,
					ImageColor3 = color,
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(1, 1),
					Visible = props.Checked == true,
				},
			}),
		}),

		Label = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.06, 0.5),
				Size = UDim2.fromScale(0.937, 0.82),
				Text = props.Label,
				TextColor3 = color,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}),
	})
end

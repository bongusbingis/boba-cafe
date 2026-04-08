--[[
	TopBar
	A colored header bar displayed at the top of ordering sub-pages.
	Shows a centered title and an optional back button on the left.

	Props:
	- Title: Text displayed in the center of the bar.
	- Color: Background color. Defaults to a muted red.
	- ShowBack: Whether to show the back chevron button. Defaults to true.
	- OnBack: Callback fired when the back button is pressed.
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
local DEFAULT_COLOR = Color3.fromRGB(224, 94, 88)

---> private
local c = React.createElement

---> public
return function(props: {
	Title: string,
	Color: Color3?,
	ShowBack: boolean?,
	OnBack: (() -> ())?,
})
	local color = props.Color or DEFAULT_COLOR
	local showBack = props.ShowBack ~= false

	return c(Pane, {
		ClassName = "Frame",
		Native = {
			BackgroundColor3 = color,
			BackgroundTransparency = 0,
			Size = UDim2.fromScale(1, 0.112254),
		},
	}, {
		Title = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.7, 0.75),
				Text = props.Title,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}),

		Back = showBack and c(Pane, {
			ClassName = "TextButton",
			OnClick = props.OnBack,
			Native = {
				AnchorPoint = Vector2.new(0, 0.5),
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.025, 0.5),
				Size = UDim2.fromScale(0.0702987, 0.831217),
				Text = "<",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}) or nil,
	})
end

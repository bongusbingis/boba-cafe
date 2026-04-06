local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)
local Styles = require(UI.Styles)
local Pane = require(UI.Components.Pane)

local c = React.createElement

return function(props: {
	Text: string,
	PlaceholderText: string?,
	Color: Color3?,
	Size: UDim2?,
	LayoutOrder: number?,
	OnTextChange: (string) -> (),
	OnClick: (() -> ())?,
})
	local color = props.Color or Styles.GREEN_DIM
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)


	return c(Pane, {
		ClassName = "ImageButton",
		CornerRadius = 0.25, 
		Stroke = props.Color and {
			Color = props.Color:Lerp(Color3.new(0, 0, 0), 0.15),
			Thickness = 3,
		} or nil,
		OnClick = props.OnClick,
		OnPress = function()
			setIsPressing(true)
		end,
		OnRelease = function()
			setIsPressing(false)
		end,
		OnHover = function()
			setIsHovering(true)
		end,
		OnLeave = function()
			setIsHovering(false)
			setIsPressing(false)
		end,
		Native = {
			AutoButtonColor = false,
			BackgroundColor3 = color,
			BackgroundTransparency = 0,
			ImageTransparency = 1,
			LayoutOrder = props.LayoutOrder,
			Size = props.Size or UDim2.fromScale(0.47, 0.77),
		},
	}, {
		Label = c(Pane, {
			ClassName = "TextBox",
			MaxTextSize = 24,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				PlaceholderText = props.PlaceholderText,
				PlaceholderColor3 = Color3.new(0.847059, 0.847059, 0.847059),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.85, 0.6),
				Text = "",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextWrapped = true,
			},
			OnChange = props.OnTextChange and {"Text", function(box: TextBox)
				props.OnTextChange(box.Text)
			end} or nil,
		}),
	})
end

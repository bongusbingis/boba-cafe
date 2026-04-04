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
	Color: Color3?,
	Size: UDim2?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
})
	local color = props.Color or Styles.GREEN_DIM
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)

	local springs = ReactSpring.useSpring({
		scale = isPressing and 0.93 or (isHovering and 1.07 or 1.0),
		config = Styles.SPRING_STANDARD,
	})

	return c(Pane, {
		ClassName = "ImageButton",
		CornerRadius = 0.25,
		Stroke = props.Color and {
			Color = props.Color:Lerp(Color3.new(0, 0, 0), 0.15),
			Thickness = 3,
		} or nil,
		Scale = springs.scale,
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
			ClassName = "TextLabel",
			MaxTextSize = 24,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.85, 0.6),
				Text = props.Text,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextWrapped = true,
			},
		}),
	})
end

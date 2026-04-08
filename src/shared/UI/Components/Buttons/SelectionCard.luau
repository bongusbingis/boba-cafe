--[[
	SelectionCard
	A solid-colored selectable card used for categories, menu items, and flavor/option swatches.
	Displays a colored background, an optional icon image in the upper portion,
	and a label pinned to the bottom.

	Props:
	- Text: Display label.
	- Color: Card background color.
	- Icon: Optional asset URL displayed above the label.
	- MaxTextSize: Max text size. Defaults to 18.
	- LayoutOrder: Layout ordering.
	- OnClick: Selection callback.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)

---> components
local Pane = require(UI.Components.Pane)

---> styles
local Styles = require(UI.Styles)

---> constants
local SPRING_CONFIG = Styles.SPRING_STANDARD

---> private
local c = React.createElement

---> public
return function(props: {
	Text: string,
	Color: Color3,
	Icon: string?,
	Size: UDim2?,
	MaxTextSize: number?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
})
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)
	local styles = ReactSpring.useSpring({
		scale = isPressing and 0.93 or (isHovering and 1.07 or 1),
		config = SPRING_CONFIG,
	})

	return c(Pane, {
		ClassName = "TextButton",
		OnClick = props.OnClick,
		OnPress = props.OnClick and function()
			setIsPressing(true)
		end or nil,
		OnRelease = props.OnClick and function()
			setIsPressing(false)
		end or nil,
		OnHover = props.OnClick and function()
			setIsHovering(true)
		end or nil,
		OnLeave = props.OnClick and function()
			setIsHovering(false)
			setIsPressing(false)
		end or nil,
		Native = {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			LayoutOrder = props.LayoutOrder,
			Selectable = false,
			Size = props.Size or nil,
			Text = "",
		},
	}, {
		Background = c(Pane, {
			ClassName = "Frame",
			Scale = styles.scale,
			CornerRadius = Styles.CORNER_CARD,
			Native = {
				BackgroundColor3 = props.Color,
				BackgroundTransparency = 0,
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5)
			},
		}, {
			Icon = props.Icon and c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = props.Icon,
					Position = UDim2.fromScale(0.5, 0.38),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.62, 0.52),
				},
			}) or nil,

			Label = c(Pane, {
				ClassName = "TextLabel",
				MaxTextSize = props.MaxTextSize or 18,
				Native = {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = props.Icon and UDim2.fromScale(0.5, 0.97) or UDim2.fromScale(0.5, 0.75),
					Size = UDim2.fromScale(0.9, if props.Icon then 0.28 else 0.52),
					Text = props.Text,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeTransparency = 0.55,
					TextWrapped = true,
				},
			}),
		}),
	})
end

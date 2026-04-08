--[[
	FlavorCard
	A selectable grid card for displaying flavor or category items.

	Props:
	- Text: Display label text.
	- Image: Optional inner image shown inside the card background.
	- LabelBelow: If true, text label renders below the background (category style);
	              otherwise it renders centered inside (flavor style). Defaults to false.
	- MaxTextSize: Max text size constraint. Defaults to 20.
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
local CARD_IMAGE = "http://www.roblox.com/asset/?id=13866611257"
local CARD_TINT = Color3.fromRGB(217, 217, 217)

---> private
local c = React.createElement

---> public
return function(props: {
	Text: string,
	Image: string?,
	LabelBelow: boolean?,
	MaxTextSize: number?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
})
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)
	local styles = ReactSpring.useSpring({
		scale = isPressing and 0.94 or (isHovering and 1.06 or 1),
		config = SPRING_CONFIG,
	})

	local backgroundHeight = if props.LabelBelow then 0.815 else 1.0

	local nameLabel = c(Pane, {
		ClassName = "TextLabel",
		MaxTextSize = props.MaxTextSize or 20,
		Native = if props.LabelBelow
			then {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 1.03),
				Size = UDim2.fromScale(1, 0.169),
				Text = props.Text,
				TextColor3 = Color3.new(),
				TextScaled = true,
			}
			else {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				RichText = true,
				Size = UDim2.fromScale(0.8, 0.74),
				Text = props.Text,
				TextColor3 = Color3.new(),
				TextScaled = true,
			},
	})

	return c(Pane, {
		ClassName = "TextButton",
		Scale = styles.scale,
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
			Text = "",
		},
	}, {
		Background = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0,
				Image = CARD_IMAGE,
				ImageColor3 = CARD_TINT,
				Size = UDim2.fromScale(1, backgroundHeight),
			},
		}, {
			InnerImage = props.Image and c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = props.Image,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.9, 0.9),
				},
			}) or nil,
			InlineLabel = (not props.LabelBelow) and nameLabel or nil,
		}),
		BelowLabel = props.LabelBelow and nameLabel or nil,
	})
end

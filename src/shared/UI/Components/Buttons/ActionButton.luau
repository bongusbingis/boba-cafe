--[[
	ActionButton
	A colored slice-image action button used for confirmations and order actions.
	Renders a tinted sliced background image with a Fredoka text label.

	Props:
	- Text: Button label.
	- Color: Tint color applied to both the background image and the text stroke.
	- Size: Button size. Defaults to UDim2.fromScale(0.167673, 1).
	- Position: Button position.
	- AnchorPoint: Anchor point. Defaults to Vector2.new(0, 0.5).
	- LayoutOrder: Layout ordering.
	- ZIndex: Render order. Defaults to 2.
	- OnClick: Click callback.
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
local BUTTON_IMAGE = "http://www.roblox.com/asset/?id=13752189617"

---> private
local c = React.createElement

---> public
return function(props: {
	Text: string,
	Color: Color3,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
	OnClick: (() -> ())?,
})
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)
	local styles = ReactSpring.useSpring({
		scale = isPressing and 0.95 or (isHovering and 1.05 or 1),
		config = SPRING_CONFIG,
	})

	local zIndex = props.ZIndex or 2

	return c(Pane, {
		ClassName = "TextButton",
		CornerRadius = 0.1,
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
			AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			BackgroundTransparency = 0,
			Text = "",
			BackgroundColor3 = props.Color,
			LayoutOrder = props.LayoutOrder,
			Position = props.Position,
			Size = props.Size or UDim2.fromScale(0.167673, 1),
			ZIndex = zIndex,
		},
	}, {
		Label = c(Pane, {
			ClassName = "TextLabel",
			Stroke = {
				Color = props.Color:Lerp(Color3.new(0, 0, 0), 0.3),
				Thickness = 1,
			},
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.85, 0.47),
				Text = props.Text,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = zIndex,
			},
		}),
	})
end

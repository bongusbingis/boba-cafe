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
local NORMAL_COLOR = Styles.GREEN_LIGHT
local HOVER_COLOR  = NORMAL_COLOR:Lerp(Color3.new(0, 0, 0), 0.12)
local PRESS_COLOR  = NORMAL_COLOR:Lerp(Color3.new(0, 0, 0), 0.22)

local SPRING_CONFIG = Styles.SPRING_STANDARD

---> private
local c = React.createElement

---> public
export type Props = {
	Label: string,
	Price: string,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
}

return function(props: Props)
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)
	local styles = ReactSpring.useSpring({
		backgroundColor = isPressing and PRESS_COLOR or (isHovering and HOVER_COLOR or NORMAL_COLOR),
		config = SPRING_CONFIG,
	})

	return c(Pane, {
		ClassName = "TextButton",
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
		ListLayout = {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0.05, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
		Padding = {
			PaddingLeft = UDim.new(0.03, 0),
		},
		Native = {
			AutoButtonColor = false,
			BackgroundColor3 = styles.backgroundColor,
			BackgroundTransparency = 0,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromScale(0.981, 0.065),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			Text = "",
			TextSize = 14,
		},
	}, {
		Label = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Size = UDim2.fromScale(0.685698, 0.57),
				Text = props.Label,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}),

		Price = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.234582, 0.57),
				Text = props.Price,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
			},
		}),
	})
end

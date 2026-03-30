local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)

---> components
local Pane = require(UI.Components.Pane)

---> constants
local SPRING_CONFIG = {
	mass = 1,
	tension = 10000,
	friction = 150,
}

---> private
local c = React.createElement

---> public
export type Props = {
	Title: string,
	Price: string,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
}

return function(props: Props)
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)
	local styles = ReactSpring.useSpring({
		scale = isPressing and 1 or (isHovering and 1.05 or 1),
		config = SPRING_CONFIG,
	})

	return c(Pane, {
		ClassName = "TextButton",
		CornerRadius = UDim.new(0.2, 0),
		Scale = styles.scale,
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
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(143, 169, 127),
			BackgroundTransparency = 0,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.fromScale(0.235229, 1),
			Text = "",
			TextSize = 14,
		},
	}, {
		Title = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, 0.2),
				Size = UDim2.fromScale(1, 0.250944),
				Text = props.Title,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}),

		Price = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, 0.6),
				Size = UDim2.fromScale(1, 0.32),
				Text = props.Price,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}),
	})
end

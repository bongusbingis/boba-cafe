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
	OnClick: (() -> ())?,
}

return function(props: Props)
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)
	local styles = ReactSpring.useSpring({
		scale = isPressing and 0.9 or (isHovering and 1.15 or 1),
		config = SPRING_CONFIG,
	})

	return c(Pane, {
		ClassName = "ImageButton",
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
			BackgroundTransparency = 1,
			Image = "http://www.roblox.com/asset/?id=13438417284",
			Position = UDim2.fromScale(0.980770, 0.147523),
			Size = UDim2.fromScale(0.0919732, 0.123874),
			ZIndex = 5,
		},
	}, {
		Inner = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "http://www.roblox.com/asset/?id=13438418840",
				ImageColor3 = Color3.fromRGB(255, 87, 90),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.835405, 0.835405),
			},
		}),

		Label = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.744808, 0.744808),
				Text = "X",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}),
	})
end

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
local IS_MOBILE = game:GetService("UserInputService").TouchEnabled
local c = React.createElement

---> public
export type Props = {
	Name: string,
	Price: string,
	Image: string,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
}

return function(props: Props)
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)
	local priceVisible = IS_MOBILE or isHovering

	local styles = ReactSpring.useSpring({
		scale             = isPressing and 0.95 or (isHovering and 1.08 or 1),
		imageTransparency = (not IS_MOBILE and isHovering) and 0.2 or 0,
		priceOpacity      = priceVisible and 0 or 1,
		config = SPRING_CONFIG,
	})

	-- Faster spring so the stroke always leads the text on fade-out,
	-- preventing a visible outline with no content behind it.
	local strokeStyles = ReactSpring.useSpring({
		priceStrokeOpacity = priceVisible and 0 or 1,
		config = { mass = 0.5, tension = 15000, friction = 150 },
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
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Image = props.Image,
			ImageTransparency = styles.imageTransparency,
			LayoutOrder = props.LayoutOrder,
		},
	}, {
		ProductName = c(Pane, {
			ClassName = "TextLabel",
			Stroke = { Thickness = 1.5 },
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, 0.825908),
				Size = UDim2.fromScale(0.8, 0.3554),
				Text = props.Name,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}),

		ProductPrice = c(Pane, {
			ClassName = "TextLabel",
			Stroke = { Thickness = 1.5, Transparency = strokeStyles.priceStrokeOpacity },
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, 0.15),
				Size = UDim2.fromScale(0.8, 0.213069),
				Text = props.Price,
				TextColor3 = Color3.new(1, 1, 1),
				TextTransparency = styles.priceOpacity,
				TextScaled = true,
			},
		}),
	})
end

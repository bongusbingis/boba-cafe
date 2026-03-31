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
local IS_MOBILE = game:GetService("UserInputService").TouchEnabled

local SPRING_CONFIG = {
	mass = 1,
	tension = 10000,
	friction = 150,
}

---> private
local c = React.createElement

---> public
export type Props = {
	Name: string,
	Price: string,
	Image: string,
	OffSale: boolean?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
}

return function(props: Props)
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)

	local active = not props.OffSale
	local priceVisible = active and (IS_MOBILE or isHovering)

	local styles = ReactSpring.useSpring({
		scale             = active and (isPressing and 0.95 or (isHovering and 1.08 or 1)) or 1,
		imageTransparency = active and ((not IS_MOBILE and isHovering) and 0.2 or 0) or 0,
		priceOpacity      = priceVisible and 0 or 1,
		config = SPRING_CONFIG,
	})

	local strokeStyles = ReactSpring.useSpring({
		priceStrokeOpacity = priceVisible and 0 or 1,
		config = { mass = 0.5, tension = 15000, friction = 150 },
	})

	return c(Pane, {
		ClassName = "ImageButton",
		Scale = styles.scale,
		CornerRadius = UDim.new(1, 0),
		OnClick = active and props.OnClick or nil,
		OnPress = active and function()
			setIsPressing(true)
		end or nil,
		OnRelease = active and function()
			setIsPressing(false)
		end or nil,
		OnHover = active and function()
			setIsHovering(true)
		end or nil,
		OnLeave = active and function()
			setIsHovering(false)
			setIsPressing(false)
		end or nil,
		Native = {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Image = props.Image,
			ImageTransparency = styles.imageTransparency,
			LayoutOrder = props.LayoutOrder,
		},
	}, {
		ProductName = not props.OffSale and c(Pane, {
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

		OffSaleOverlay = props.OffSale and c(Pane, {
			ClassName = "Frame",
			CornerRadius = UDim.new(1, 0),
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.4,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			},
		}, {
			Label = c(Pane, {
				ClassName = "TextLabel",
				Stroke = { Thickness = 1.5 },
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.75, 0.22),
					Text = "Off Sale",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				},
			}),
		}) or nil,
	})
end

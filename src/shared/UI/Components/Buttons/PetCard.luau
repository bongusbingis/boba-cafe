local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)

---> components
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local Pane = require(UI.Components.Pane)
local ViewportModel = require(UI.Components.ViewportModel)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement
local TIER_COLORS = InventoryItemDefinitions.Tiers

---> public
export type Props = {
	Name: string,
	Tier: string,
	Model: Instance,
	BackgroundColor: Color3?,
	OffSale: boolean?,
	LayoutOrder: number?,
	Size: UDim2?,
	OnClick: (() -> ())?,
}

return function(props: Props)
	local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)

	local active = not props.OffSale
	local tierColor = TIER_COLORS[props.Tier].Color

	local styles = ReactSpring.useSpring({
		scale = active and (isPressing and 0.95 or (isHovering and 1.1 or 1)) or 1,
		config = Styles.SPRING_CARD,
	})

	local name = props.Name:gsub("Pet", "")


	return c(Pane, {
		ClassName = "ImageButton",
		Scale = styles.scale,
		AspectRatio = 1,
		CornerRadius = 1,
		Stroke = active and { Color = tierColor, Thickness = 3 } or nil,
		OnClick = active and props.OnClick or nil,
		OnPress = active and props.OnClick and function()
			setIsPressing(true)
		end or nil,
		OnRelease = active and props.OnClick and function()
			setIsPressing(false)
		end or nil,
		OnHover = active and props.OnClick and function()
			setIsHovering(true)
		end or nil,
		OnLeave = active and props.OnClick and function()
			setIsHovering(false)
			setIsPressing(false)
		end or nil,
		Native = {
			AutoButtonColor = false,
			BackgroundColor3 = tierColor:Lerp(Color3.new(0, 0, 0), 0.2),
			BackgroundTransparency = 0,
			LayoutOrder = props.LayoutOrder,
			Size = props.Size or UDim2.fromScale(1, 1),
		},
	}, {
		Viewport = c(ViewportModel, {
			Model = props.Model,
			Size = UDim2.fromScale(1, 0.78),
			ModelRotation = 15,
			ElevationAngle = 15,
			FieldOfView = 30,
		}),

		NameLabel = c(Pane, {
			ClassName = "TextLabel",
			Stroke = { Thickness = 1 },
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.99),
				Size = UDim2.fromScale(0.9, 0.2),
				Text = name,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}),

		OffSaleOverlay = props.OffSale and c(Pane, {
			ClassName = "Frame",
			CornerRadius = Styles.CORNER_CARD,
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
					FontFace = Styles.FONT_FREDOKA,
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

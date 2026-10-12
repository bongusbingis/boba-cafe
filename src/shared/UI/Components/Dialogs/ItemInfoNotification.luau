--[[
    Dialog: ItemInfoNotification
    Description: Detail card for a single inventory item — name, tier, image and
    description, with an optional action button.

    V3 stored this content in nested StringValues under each UI label; it is passed as
    props here.

    Props: Name, Tier?, Image?, Description?, ActionText?, OnResolution
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> config
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)

---> hooks
local usePx = require(UI.Hooks.usePx)

---> private
local c = React.createElement

--- Tier colours are defined once in the item definitions; reuse them rather than
--- duplicating a palette here.
local function getTierColor(tier: string?): Color3
	local definition = tier and InventoryItemDefinitions.Tiers[tier]
	return (definition and definition.Color) or Styles.GRAY
end

---> public
return function(props: {
	Name: string,
	Tier: string?,
	Image: string?,
	Description: string?,
	ActionText: string?,
	OnResolution: (string) -> (),
})
	local px = usePx()
	local tierColor = getTierColor(props.Tier)

	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 1.15,
		CornerRadius = Styles.CORNER_CARD,
		Stroke = { Color = tierColor, Thickness = 4 },
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Styles.GREEN_MID,
			BackgroundTransparency = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.26, 0.42),
		},
	}, {
		Close = c(Pane, {
			ClassName = "TextButton",
			CornerRadius = Styles.CORNER_FULL,
			OnClick = function()
				props.OnResolution("Close")
			end,
			Native = {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Styles.RED,
				BackgroundTransparency = 0,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.96, 0.03),
				Size = UDim2.fromScale(0.11, 0.09),
				Text = "X",
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
			},
		}),

		Preview = c(Pane, {
			ClassName = "ImageLabel",
			CornerRadius = Styles.CORNER_CARD,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Styles.GREEN_DEEP,
				BackgroundTransparency = 0.4,
				Image = props.Image or "",
				Position = UDim2.fromScale(0.5, 0.05),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.5, 0.34),
			},
		}),

		Name = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.05, 0.42),
				Size = UDim2.fromScale(0.9, 0.1),
				Text = props.Name,
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
			},
		}),

		Tier = if props.Tier
			then c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.05, 0.52),
					Size = UDim2.fromScale(0.9, 0.07),
					Text = props.Tier,
					TextColor3 = tierColor,
					TextScaled = true,
				},
			})
			else nil,

		Description = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.08, 0.62),
				RichText = true,
				Size = UDim2.fromScale(0.84, 0.2),
				Text = props.Description or "",
				TextColor3 = Styles.CREAM,
				TextSize = px(24),
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
			},
		}),

		Action = if props.ActionText
			then c(Pane, {
				ClassName = "TextButton",
				CornerRadius = Styles.CORNER_PILL,
				OnClick = function()
					props.OnResolution(props.ActionText)
				end,
				Native = {
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundColor3 = Styles.GREEN_BADGE,
					BackgroundTransparency = 0,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.95),
					Size = UDim2.fromScale(0.6, 0.11),
					Text = props.ActionText,
					TextColor3 = Styles.OFFWHITE,
					TextScaled = true,
				},
			})
			else nil,
	})
end

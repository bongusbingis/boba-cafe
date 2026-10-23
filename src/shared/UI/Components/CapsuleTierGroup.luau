local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local Pane = require(UI.Components.Pane)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement
local TIER_COLORS = InventoryItemDefinitions.Tiers

local BORDER_PADDING = UDim.new(0.05, 0)

---> public
export type Props = {
	Tier: string,
	LayoutOrder: number,
	Items: { [any]: any },
}

return function(props: Props)
	local tier = TIER_COLORS[props.Tier]

	local weightText
	if tier.Weight > 0 then
		weightText = `{props.Tier}  •  {math.floor(tier.Weight * 100)}% DROP CHANCE`
	else
		weightText = `{props.Tier}  •  EVENT ONLY`
	end

	return c(Pane, {
		ClassName = "Frame",
		Native = {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = props.LayoutOrder,
		},
		ListLayout = {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 8),
		},
		Padding = {
			PaddingLeft = BORDER_PADDING,
			PaddingRight = BORDER_PADDING,
		},
	}, {
		Badge = c(Pane, {
			ClassName = "Frame",
			CornerRadius = 1,
			Padding = {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 14),
				PaddingRight = UDim.new(0, 14),
			},
			Native = {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = tier.Color,
				BackgroundTransparency = 0,
				LayoutOrder = 1,
			},
		}, {
			Label = c("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Text = weightText,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 15,
			}, {
				UIStroke = c("UIStroke", {
					Color = tier.Color:Lerp(Color3.new(0, 0, 0), 0.4),
					Thickness = 1.5,
				}),
			}),
		}),

		Inner = c(Pane, {
			ClassName = "Frame",
			CornerRadius = Styles.CORNER_CARD,
			Stroke = { Color = tier.Color, Thickness = 2 },
			ListLayout = {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 10),
				Wraps = true,
				HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly,
			},
			Padding = {
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 12),
			},
			Native = {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Styles.OFFWHITE,
				BackgroundTransparency = 0,
				Size = UDim2.fromScale(1, 0),
				LayoutOrder = 2,
			},
		}, props.Items),
	})
end

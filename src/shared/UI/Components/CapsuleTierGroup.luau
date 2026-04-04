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
	Items: { [ any ]: any },
}

return function(props: Props)
	local tier = TIER_COLORS[props.Tier]

	local weightText
	if tier.Weight > 0 then
		weightText = " " .. props.Tier .. "  —  " .. math.floor(tier.Weight * 100) .. "%"
	else
		weightText = " " .. props.Tier .. "  —  Event Only"
	end

	table.insert(props.Items, c("Frame", {
		Size = UDim2.fromScale(1, 0.175),
		BackgroundTransparency = 1,
		LayoutOrder = math.huge
	}))

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
			Padding = UDim.new(0.0375, 0),
		},
		Padding = {
			PaddingLeft = BORDER_PADDING,
			PaddingRight = BORDER_PADDING,
		},
	}, {
		Label = c("TextLabel", {
			AnchorPoint = Vector2.new(0, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(0.9, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = weightText,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = false,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
		}, {
			UIStroke = c("UIStroke", {
				Color = tier.Color:Lerp(Color3.new(0, 0, 0), 0.5),
				Thickness = 2,
			}),
		}),

		Inner = c(Pane, {
			ClassName = "ImageButton",
			CornerRadius = UDim.new(0.06, 0),
			Stroke = { Color = tier.Color, Thickness = 3 },
			ListLayout = {
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0.05, 0),
				Wraps = true,
				HorizontalFlex = Enum.UIFlexAlignment.SpaceEvenly,
			},
			Padding = {
				PaddingLeft = UDim.new(0.0275, 0),
				PaddingTop = UDim.new(0.125, 0),
				PaddingBottom = UDim.new(0.05, 0),
			},
			Native = {
				AutoButtonColor = false,
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.fromScale(0.95, 0.5),
				Position = UDim2.fromScale(0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0),
				LayoutOrder = 2,
			},
		}, props.Items),
	})
end

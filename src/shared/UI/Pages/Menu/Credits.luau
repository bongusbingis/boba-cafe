local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> data
local Credits = require(Shared.Configuration.Credits)

---> private
local c = React.createElement
local nextOrderFunctionFactory = require(UI.Utility.nextOrderFunctionFactory)

local function label(props: {
	Text: string,
	YScale: number,
	Position: UDim2?,
	Font: Font?,
})
	return c("TextLabel", {
		Text = props.Text,
		BackgroundTransparency = 1,
		TextColor3 = Styles.GREEN,
		TextScaled = true,
		FontFace = props.Font or Styles.FONT_DENKONE,
		TextXAlignment = Enum.TextXAlignment.Left,

		Position = props.Position,
		Size = UDim2.fromScale(1, props.YScale),
	})
end

export type Props = {
	HideTitle: boolean?,
	Position: UDim2?,
	Size: UDim2?,
	Visible: boolean?,
}

return function(props: Props?)
	local hideTitle = props and props.HideTitle or false
	local nextOrder = nextOrderFunctionFactory()
	local children: { [any]: any } = {
		Layout = c("UIListLayout", {
			Padding = UDim.new(0.02, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = c("UIPadding", {
			PaddingLeft = UDim.new(0.03, 0),
			PaddingRight = UDim.new(0.03, 0),
			PaddingTop = UDim.new(0.02, 0),
		}),
	}

	if not hideTitle then
		table.insert(
			children,
			c(label, {
				Text = "Credits",
				YScale = 0.1,
				Font = Styles.FONT_FREDOKA,
			})
		)
	end

	for _, credit in ipairs(Credits) do
		table.insert(
			children,
			c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, if hideTitle then 0.2 else 0.15),
				LayoutOrder = nextOrder(),
			}, {
				Title = c(label, {
					Text = credit.Title,
					YScale = 0.35,
				}),
				Text = c(label, {
					Text = credit.Text,
					YScale = 0.65,
					Position = UDim2.fromScale(0, 0.3),
				}),
			})
		)
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Position = props and props.Position or UDim2.new(),
		Size = props and props.Size or UDim2.fromScale(1, 1),
		Visible = if props and props.Visible ~= nil then props.Visible else true,
	}, children)
end

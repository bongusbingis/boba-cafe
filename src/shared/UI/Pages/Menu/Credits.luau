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
		FontFace = props.Font or Font.new("rbxasset://fonts/families/DenkOne.json"),
		TextXAlignment = Enum.TextXAlignment.Left,

        Position = props.Position,
		Size = UDim2.fromScale(1, props.YScale),
	})
end

return function(props)
	local nextOrder = nextOrderFunctionFactory()
	local children = {
		c("UIListLayout", {
			Padding = UDim.new(0.015, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		c(label, {
			Text = "Credits",
			YScale = 0.1,
			Font = Font.new("rbxasset://fonts/families/FredokaOne.json"),
		}),
	}

	for _, credit in ipairs(Credits) do
		table.insert(
			children,
			c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0.15),
				LayoutOrder = nextOrder(),
			}, {
				c(label, {
					Text = credit.Title,
					YScale = 0.35,
				}),
                c(label, {
                    Text = credit.Text,
                    YScale = 0.65,
                    Position = UDim2.fromScale(0, 0.3),
                }),
			})
		)
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, children)
end

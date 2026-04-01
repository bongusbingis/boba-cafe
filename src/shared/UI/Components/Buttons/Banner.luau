local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

---> dependencies
local React = require(Packages.React)

---> private
local c = React.createElement

---> public
export type Props = {
	Color: Color3,
	Text: string,
	Size: UDim2,
}

return function(props: Props)
	return c("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.21),
		Size = props.Size,
	}, {
		Back = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = "http://www.roblox.com/asset/?id=13369767169",
			ImageColor3 = props.Color,
			Position = UDim2.fromScale(0.5, 0.1),
			Size = UDim2.fromScale(1, 0.875),
			ZIndex = -1,
		}),

		Front = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Image = "http://www.roblox.com/asset/?id=13369762471",
			ImageColor3 = props.Color,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromScale(0.845523, 0.758506),
		}, {
			TextLabel = c("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0, 0.45),
				Size = UDim2.fromScale(1, 0.9),
				Text = props.Text,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			}),
		}),
	})
end

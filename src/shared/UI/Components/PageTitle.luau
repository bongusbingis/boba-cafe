local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> private
local joinDicts = require(UI.Utility.joinDicts)
local c = React.createElement

---> public
return function(props: {
	Text: string,
	Color: Color3,
})
	return c("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.0384615, 0),
		Size = UDim2.fromScale(0.436455, 0.189189),
	}, {
		Back = c("ImageLabel", {
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Image = "http://www.roblox.com/asset/?id=13438330502",
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromScale(0.283525, 0.821429),
		}, {
			Inner = c("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "http://www.roblox.com/asset/?id=13438349330",
				ImageColor3 = props.Color:Lerp(Color3.new(0, 0, 0), 0.15),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.839169, 0.822496),
			}),
		}),

		Front = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = "http://www.roblox.com/asset/?id=13438222034",
			Size = UDim2.fromScale(0.885057, 0.821429),
			ZIndex = 2,
		}, {
			Inner = c("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "http://www.roblox.com/asset/?id=13438230247",
				ImageColor3 = props.Color,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.946321, 0.822496),
			}),

			TextLabel = c("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, 0.436),
				Size = UDim2.fromScale(0.85, 0.591),
				Text = props.Text,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			}),
		}),
	})
end

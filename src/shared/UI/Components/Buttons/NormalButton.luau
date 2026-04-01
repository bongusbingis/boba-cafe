local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local Pane = require(UI.Components.Pane)

---> styles
local Styles = require(UI.Styles)

local c = React.createElement

return function(props: {
    Text: string,
    Color: Color3,
    Icon: string?,
    PlusButton: boolean?,

    Size: UDim2?,
    Position: UDim2?,
	OnClick: (() -> ())?,
})
	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 5.04762,
		Native = {
			Name = "ButtonWrapper",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = props.Position or UDim2.fromScale(0.0244846, 0.46814),
			Size = props.Size or UDim2.fromScale(0.921739, 0.0546164),
		},
	}, {
		UISizeConstraint = c("UISizeConstraint", {
			MaxSize = Vector2.new(240, math.huge),
			MinSize = Vector2.new(140, math.huge),
		}),

		Base = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				BackgroundTransparency = 1,
				Image = "http://www.roblox.com/asset/?id=13382242889",
				Size = UDim2.fromScale(1, 1),
			},
			OnClick = (not props.PlusButton) and props.OnClick or nil,
		}, {
			Border = c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "http://www.roblox.com/asset/?id=13382243228",
					ImageColor3 = props.Color or Styles.CORAL,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.97, 0.85),
				},
			}),

			Container = c(Pane, {
				ClassName = "Frame",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.92, 0.616),
				},
			}, {
				Amount = c(Pane, {
					ClassName = "TextLabel",
					MaxTextSize = 30,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.65, 0.9),
						Text = props.Text,
						TextColor3 = props.Color or Styles.CORAL,
						TextScaled = true,
					},
				}),

				Icon = props.Icon and c(Pane, {
					ClassName = "ImageLabel",
					Native = {
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						Image = props.Icon or "rbxassetid://13391365805",
						Position = UDim2.fromScale(0.0713614, 0.483614),
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromScale(0.127882, 0.945269),
					},
				}),

				Plus = props.PlusButton and c(Pane, {
					ClassName = "ImageButton",
					OnClick = props.OnClick,
					Native = {
						AnchorPoint = Vector2.new(1, 0.5),
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						Image = "http://www.roblox.com/asset/?id=13382300733",
						ImageColor3 = props.Color or Styles.CORAL,
						Position = UDim2.fromScale(0.94603, 0.5),
						Size = UDim2.fromScale(0.0820308, 0.60635),
					},
				}),
			}),
		}),
	})
end
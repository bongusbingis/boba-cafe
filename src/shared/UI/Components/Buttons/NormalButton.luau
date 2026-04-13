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
	LayoutOrder: number?,

	OnClick: (() -> ())?,
	OnPlusButtonClick: (() -> ())?,
})
	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 7,
		Native = {
			Name = "ButtonWrapper",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = props.Position or UDim2.fromScale(0.0244846, 0.46814),
			Size = props.Size or UDim2.fromScale(0.921739, 0.0546164),
			LayoutOrder = props.LayoutOrder,
		},
	}, {
		Base = c(Pane, {
			ClassName = "ImageButton",
			CornerRadius = UDim.new(1, 0),
			Stroke = {
				Color = Styles.OFFWHITE,
				Thickness = 2,
			},
			Native = {
				BackgroundTransparency = 0,
				BackgroundColor3 = props.Color,
				Size = UDim2.fromScale(1, 1),
			},
			OnClick = props.OnClick,
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
					--MaxTextSize = 40,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						FontFace = Styles.FONT_FREDOKA,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.65, 1.15),
						Text = props.Text,
						TextColor3 = Styles.OFFWHITE,
						TextScaled = true,
						ZIndex = 5,
					},
				}),

				Icon = props.Icon and c(Pane, {
					ClassName = "ImageLabel",
					AspectRatio = 1,
					Native = {
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						Image = props.Icon or "rbxassetid://13391365805",
						Position = UDim2.fromScale(0.02, 0.5),
						Size = UDim2.fromScale(1.35, 1.35),
					},
				}),

				Plus = props.PlusButton and c(Pane, {
					ClassName = "ImageButton",
					OnClick = props.OnClick,
					AspectRatio = 1,
					Native = {
						AnchorPoint = Vector2.new(1, 0.5),
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						Image = "http://www.roblox.com/asset/?id=13382300733",
						ImageColor3 = Styles.OFFWHITE,
						Position = UDim2.fromScale(0.95, 0.5),
						Size = UDim2.fromScale(0.75, 0.75),
					},
				}),
			}),
		}),
	})
end
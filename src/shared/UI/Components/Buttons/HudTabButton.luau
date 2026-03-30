local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(ReplicatedStorage.Packages.ReactSpring)

---> components
local Pane = require(UI.Components.Pane)

---> constants
local SPRING_CONFIG = {
	mass = 1,
	tension = 10000,
	friction = 150,
}


---> private
local c = React.createElement

return function(props: {
	Text: string,
    TextColor3: Color3?,
    Size: UDim2?,

    BackgroundColor: Color3?,
	LayoutOrder: number?,
	OnClick: (() -> ())?,
})
    local isHovering, setIsHovering = React.useState(false)
	local isPressing, setIsPressing = React.useState(false)
	local styles = ReactSpring.useSpring({
        scale = isPressing and 1 or (isHovering and 1.1 or 1),
		config = SPRING_CONFIG,
	})

	return c(Pane, {
		Scale = props.BackgroundColor and styles.scale or nil,
		ClassName = "TextButton",
		OnClick = props.OnClick,
        OnPress = props.OnClick and function()
			setIsPressing(true)
		end,
		OnRelease = props.OnClick and function()
			setIsPressing(false)
		end,
		OnHover = props.OnClick and function()
			setIsHovering(true)
		end,
		OnLeave = props.OnClick and function()
			setIsHovering(false)
			setIsPressing(false)
		end,
		Native = {
			AutoButtonColor = false,
			FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
			LayoutOrder = props.LayoutOrder,
			Size = props.Size or UDim2.fromScale(0.334, 1),
			Text = "",
			TextSize = 14,
            BackgroundColor3 = props.BackgroundColor or Color3.fromRGB(250, 250, 250),
            BackgroundTransparency = props.BackgroundColor and 0 or 1,
		},
        CornerRadius = 0.5,
	}, {
		TextLabel = c(Pane, {
			ClassName = "TextLabel",
            Scale = not props.BackgroundColor and styles.scale or nil,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 0.58),
				Text = props.Text,
				TextColor3 = props.TextColor3 or Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}),
	})
end
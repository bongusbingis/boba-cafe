local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(ReplicatedStorage.Packages.ReactSpring)

---> components
local Pane = require(UI.Components.Pane)

---> styles
local Styles = require(UI.Styles)

---> constants
local SPRING_CONFIG = Styles.SPRING_STANDARD


---> private
local c = React.createElement

return function(props: {
	Text: string,
    TextColor3: Color3?,
    Size: UDim2?,

    BackgroundColor: Color3?,
	LayoutOrder: number?,
	Selected: boolean?,
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
            BackgroundColor3 = props.BackgroundColor or Styles.OFFWHITE,
            BackgroundTransparency = props.BackgroundColor and 0 or 1,
		},
        CornerRadius = 0.5,
	}, {
		UIStroke = props.Selected and c("UIStroke", {
			Thickness = 3,
			Color = Styles.GREEN_DEEP,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		TextLabel = c(Pane, {
			ClassName = "TextLabel",
            Scale = not props.BackgroundColor and styles.scale or nil,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 0.58),
				Text = props.Text,
				TextColor3 = props.TextColor3 or Color3.new(1, 1, 1),
				TextScaled = true,
			},
		}),
	})
end
--[[
    Dialog: Notification
    Description: A centred announcement with a single dismiss button.

    V3's "Announcement" prompt. Distinct from SmallNotification, which is a passive
    toast — this one blocks until acknowledged, so it resolves through the dialog queue
    like the other prompts.

    Props: Title, Text, Color?, ButtonText?, OnResolution
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)

---> hooks
local usePx = require(UI.Hooks.usePx)

---> private
local c = React.createElement

---> public
return function(props: {
	Title: string,
	Text: string,
	Color: Color3?,
	ButtonText: string?,
	OnResolution: (string) -> (),
})
	local px = usePx()
	local accent = props.Color or Styles.GREEN

	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 2.23008,
		CornerRadius = Styles.CORNER_CARD,
		Stroke = { Color = Styles.OFFWHITE, Thickness = 3.5 },
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Styles.GREEN_MID,
			BackgroundTransparency = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.32, 0.28),
		},
	}, {
		---> coloured header strip
		Header = c(Pane, {
			ClassName = "Frame",
			CornerRadius = Styles.CORNER_CARD,
			Native = {
				BackgroundColor3 = accent,
				BackgroundTransparency = 0,
				Size = UDim2.fromScale(1, 0.24),
			},
		}, {
			Title = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.05, 0.15),
					Size = UDim2.fromScale(0.9, 0.7),
					Text = props.Title,
					TextColor3 = Styles.OFFWHITE,
					TextScaled = true,
				},
			}),
		}),

		Body = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.07, 0.3),
				RichText = true,
				Size = UDim2.fromScale(0.86, 0.4),
				Text = props.Text,
				TextColor3 = Styles.OFFWHITE,
				TextSize = px(28),
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
			},
		}),

		Dismiss = c(Pane, {
			ClassName = "TextButton",
			CornerRadius = Styles.CORNER_PILL,
			OnClick = function()
				props.OnResolution("Close")
			end,
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = accent,
				BackgroundTransparency = 0,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.93),
				Size = UDim2.fromScale(0.45, 0.18),
				Text = props.ButtonText or "Okay",
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
			},
		}),
	})
end

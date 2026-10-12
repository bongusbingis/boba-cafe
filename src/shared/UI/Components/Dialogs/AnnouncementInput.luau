--[[
    Dialog: AnnouncementInput
    Description: Staff-facing composer for a server-wide announcement.

    Resolves with the typed message, or nil when cancelled. The server is responsible
    for re-checking rank and filtering the text before broadcasting — this is only the
    input surface.

    Props: Title?, PlaceholderText?, MaxLength?, OnResolution
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

---> private
local c = React.createElement

local DEFAULT_MAX_LENGTH = 200

---> public
return function(props: {
	Title: string?,
	PlaceholderText: string?,
	MaxLength: number?,
	OnResolution: (string?) -> (),
})
	local text, setText = React.useState("")
	local maxLength = props.MaxLength or DEFAULT_MAX_LENGTH

	local remaining = maxLength - #text
	local canSend = #text:gsub("%s", "") > 0

	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 1.6,
		CornerRadius = Styles.CORNER_CARD,
		Stroke = { Color = Styles.OFFWHITE, Thickness = 3.5 },
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Styles.GREEN_MID,
			BackgroundTransparency = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.3, 0.32),
		},
	}, {
		Title = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.05, 0.05),
				Size = UDim2.fromScale(0.9, 0.13),
				Text = props.Title or "Announcement",
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
			},
		}),

		Input = c(Pane, {
			ClassName = "TextBox",
			CornerRadius = Styles.CORNER_CARD,
			Native = {
				BackgroundColor3 = Styles.GREEN_DEEP,
				BackgroundTransparency = 0.2,
				ClearTextOnFocus = false,
				FontFace = Styles.FONT_FREDOKA,
				MultiLine = true,
				PlaceholderText = props.PlaceholderText or "Type your announcement...",
				Position = UDim2.fromScale(0.05, 0.22),
				Size = UDim2.fromScale(0.9, 0.42),
				Text = text,
				TextColor3 = Styles.OFFWHITE,
				TextSize = 22,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				[React.Change.Text] = function(rbx)
					-- Clamp in the change handler; MaxLength would let the extra
					-- characters render for a frame before snapping back.
					if #rbx.Text > maxLength then
						rbx.Text = string.sub(rbx.Text, 1, maxLength)
					end
					setText(rbx.Text)
				end,
			},
		}),

		Counter = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.05, 0.65),
				Size = UDim2.fromScale(0.9, 0.07),
				Text = `{remaining} characters left`,
				TextColor3 = if remaining < 20 then Styles.RED else Styles.CREAM,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
			},
		}),

		Send = c(Pane, {
			ClassName = "TextButton",
			CornerRadius = Styles.CORNER_PILL,
			OnClick = function()
				if canSend then
					props.OnResolution(text)
				end
			end,
			Native = {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = if canSend then Styles.GREEN_BADGE else Styles.GRAY,
				BackgroundTransparency = 0,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.05, 0.95),
				Size = UDim2.fromScale(0.44, 0.16),
				Text = "Send",
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
			},
		}),

		Cancel = c(Pane, {
			ClassName = "TextButton",
			CornerRadius = Styles.CORNER_PILL,
			OnClick = function()
				props.OnResolution(nil)
			end,
			Native = {
				AnchorPoint = Vector2.new(1, 1),
				BackgroundColor3 = Styles.RED,
				BackgroundTransparency = 0,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.95, 0.95),
				Size = UDim2.fromScale(0.44, 0.16),
				Text = "Cancel",
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
			},
		}),
	})
end

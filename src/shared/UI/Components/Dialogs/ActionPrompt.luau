--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local Styles = require(UI.Styles)
local usePx = require(UI.Hooks.usePx)

local Banner = require(UI.Components.Buttons.Banner)
local Page = require(UI.Components.Core.Page)
local Pane = require(UI.Components.Pane)
local PromptButton = require(UI.Components.Buttons.PromptButton)

local c = React.createElement

local BUTTON_HEIGHT = 50

type ButtonDef = {
	Text: string,
	Color: Color3?,
	Disabled: boolean?,
}

--[[
	ActionPrompt
	A taller dialog variant for inventory/action flows. Action buttons are stacked
	vertically in the middle of the dialog; an optional close button is pinned to
	the bottom. Button height adjusts automatically based on count.

	Props:
	- Title: Banner label at the top.
	- Text: Body description (supports RichText).
	- Buttons: Vertical stack of action buttons.
	- CloseText: Optional dismiss button pinned to the bottom (rendered in CORAL).
	- OnResolution: Called with the text of whichever button was pressed.
]]
return function(props: {
	Title: string,
	Text: string,
	Buttons: { ButtonDef },
	OffsetX: number?,
	CloseText: string?,
	OnResolution: (string) -> (),
	Native: { [string]: any }?,
})
	local px = usePx()
	local closeFnRef = React.useRef(nil)

	local function resolve(text: string)
		if closeFnRef.current then
			closeFnRef.current()
		end
		props.OnResolution(text)
	end

	local buttonElements = {}
	for i, buttonDef in ipairs(props.Buttons) do
		table.insert(buttonElements, c(PromptButton, {
			Text = buttonDef.Text,
			Color = buttonDef.Color or Styles.GREEN_DIM,
			Disabled = buttonDef.Disabled,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, px(BUTTON_HEIGHT)),
			OnClick = function()
				if buttonDef.Disabled then
					return
				end
				resolve(buttonDef.Text)
			end,
		}))
	end

	table.insert(buttonElements, c(PromptButton, {
		Text = props.CloseText or "Close",
		Color = Styles.CORAL,
		LayoutOrder = math.huge,
		Size = UDim2.new(1, 0, 0, px(BUTTON_HEIGHT)),
		OnClick = function()
			resolve(props.CloseText or "Close")
		end,
	}))

	table.insert(buttonElements, c("Frame", {
		LayoutOrder = math.huge,
		Size = UDim2.new(1, 0, 0, px(5)),
		BackgroundTransparency = 1,
	}))

	local yOffset = #buttonElements / 2 * (BUTTON_HEIGHT + 8) + 20

	local promptElement = c(Pane, {
		ClassName = "Frame",
		AspectRatio = 0.937,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5 + (props.OffsetX or 0), 0.5 - yOffset / 1000),
			Size = UDim2.fromScale(0.65, 0.65),
		},
	}, {
		UISizeConstraint = c("UISizeConstraint", {
			MaxSize = Vector2.new(380, math.huge),
			MinSize = Vector2.new(200, 180),
		}),

		Title = c(Banner, {
			Text = props.Title or "Notification",
			Color = Styles.GREEN,
			Position = UDim2.fromScale(0.5, 0.2),
			Size = UDim2.fromScale(1.21645, 0.15),
		}),

		Base = c(Pane, {
			ClassName = "Frame",
			CornerRadius = 0.05,
			Stroke = {
				Color = Styles.GREEN_DIM,
				Thickness = 5,
			},
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 0,
				BackgroundColor3 = Styles.OFFWHITE,
				Position = UDim2.fromScale(0.5, 0.1),
				Size = UDim2.fromScale(1, 0.5),
				AutomaticSize = Enum.AutomaticSize.Y,
			},
		}, {
			Container = c(Pane, {
				ClassName = "Frame",
				ListLayout = {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					Padding = UDim.new(0.1, 0),
				},
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.3),
					Size = UDim2.fromScale(0.88, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
				},
			}, {
				Description = c(Pane, {
					ClassName = "TextLabel",
					MaxTextSize = 28,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Position = UDim2.fromScale(0.5, 0),
						Size = UDim2.fromScale(0.95, 0),
						Text = props.Text,
						TextColor3 = Styles.GREEN_LIGHT,
						TextYAlignment = Enum.TextYAlignment.Top,
						TextScaled = true,
						RichText = true,
						AutomaticSize = Enum.AutomaticSize.Y,
					},
				}),

				ActionButtons = props.Buttons and c(Pane, {
					ClassName = "Frame",
					ListLayout = {
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Top,
						--VerticalFlex = Enum.UIFlexAlignment.SpaceEvenly,
						Padding = UDim.new(0.2, 0),
					},
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.46),
						Size = UDim2.fromScale(0.9, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
					},
				}, buttonElements) or nil,
			}),
		}),
	})

	return c(Page, {
		IsVisible = true,
		PageContent = promptElement,
		OnClosing = function(callback)
			closeFnRef.current = callback
		end,
	})
end

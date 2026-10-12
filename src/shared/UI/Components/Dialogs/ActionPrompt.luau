--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
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
		SoundService.SFX.UI.Pop2:Play()
		props.OnResolution(text)
	end

	SoundService.SFX.UI.Pop1:Play()

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

	-- No fixed AspectRatio: the prompt has to grow and shrink with the number of action
	-- buttons, and a fixed ratio forced a tall box with dead space under short content.
	-- Height comes from the children instead; only the width is driven by the viewport.
	local promptElement = c(Pane, {
		ClassName = "Frame",
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5 + (props.OffsetX or 0), 0.5),
			Size = UDim2.fromScale(0.28, 0),
		},
	}, {
		-- Scaled bounds: raw pixel min/max made the prompt tiny on large displays and
		-- oversized on small ones.
		UISizeConstraint = c("UISizeConstraint", {
			MaxSize = Vector2.new(px(400), math.huge),
			MinSize = Vector2.new(px(230), 0),
		}),

		-- Fixed banner height: a 0.15 scale of a now auto-sized parent resolved against a
		-- height that depends on this element, which is circular.
		Title = c(Banner, {
			Text = props.Title or "Notification",
			Color = Styles.GREEN,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(1.21645, 0, 0, px(46)),
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
				Position = UDim2.fromOffset(0, 0),
				-- Zero base height: AutomaticSize supplies it. A 0.5 scale added half
				-- the parent's height on top of the content, which was the dead space.
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			},
		}, {
			-- Clears the banner, which overhangs the top of the base.
			UIPadding = c("UIPadding", {
				PaddingBottom = UDim.new(0, px(12)),
				PaddingTop = UDim.new(0, px(34)),
			}),

			Container = c(Pane, {
				ClassName = "Frame",
				ListLayout = {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					-- Fixed gap, not 10% of the container: a scale padding grew with the
					-- box and opened a large hole between the first and second buttons.
					Padding = UDim.new(0, px(8)),
				},
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0),
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
						-- Fixed gap. This was 20% of the stack's own height, so every
						-- extra button widened the gaps as well — the large hole between
						-- the first and second buttons.
						Padding = UDim.new(0, px(10)),
					},
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						-- Position is managed by the parent's list layout.
						Position = UDim2.fromScale(0.5, 0),
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

--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local Styles = require(UI.Styles)

local Banner = require(UI.Components.Buttons.Banner)
local Page = require(UI.Components.Core.Page)
local Pane = require(UI.Components.Pane)
local PromptButton = require(UI.Components.Buttons.PromptButton)

local c = React.createElement

type ButtonDef = {
	Text: string,
	Color: Color3?,
}

return function(props: {
	Title: string,
	Text: string,
	Buttons: { ButtonDef },
	OnResolution: (string) -> (),
	Native: { [string]: any }?,
})
	local closeFnRef = React.useRef(nil)

	local buttonElements = {}
	for i, buttonDef in ipairs(props.Buttons) do
		buttonElements["Button_" .. i] = c(PromptButton, {
			Text = buttonDef.Text,
			Color = buttonDef.Color,
			LayoutOrder = i,
			OnClick = function()
				if closeFnRef.current then
					closeFnRef.current()
				end
				props.OnResolution(buttonDef.Text)
			end,
		})
	end

	local promptElement = c(Pane, {
		ClassName = "Frame",
		AspectRatio = 2.23008,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.4),
		},
	}, {
		UISizeConstraint = c("UISizeConstraint", {
			MaxSize = Vector2.new(440, math.huge),
			MinSize = Vector2.new(200, 122),
		}),

		Base = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = "http://www.roblox.com/asset/?id=13473433246",
				Position = UDim2.fromScale(0.5, 0.5),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromScale(1, 1),
				SliceCenter = Rect.new(104, 96, 408, 416),
			},
		}, {
			Container = c(Pane, {
				ClassName = "Frame",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Position = UDim2.fromScale(0.5, 0.315665),
					Size = UDim2.fromScale(0.94214, 0.616115),
				},
			}, {
				Description = c(Pane, {
					ClassName = "TextLabel",
					MaxTextSize = 30,
					Native = {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Position = UDim2.fromScale(0.499, 0.055),
						Size = UDim2.fromScale(0.95, 0.393437),
						Text = props.Text,
						TextColor3 = Styles.GREEN_LIGHT,
						TextScaled = true,
						RichText = true,
					},
				}),

				Buttons = c(Pane, {
					ClassName = "Frame",
					ListLayout = {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0.05, 0),
						VerticalAlignment = Enum.VerticalAlignment.Center,
						HorizontalFlex = Enum.UIFlexAlignment.Fill,
					},
					Native = {
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						Position = UDim2.fromScale(0.5, 0.925),
						Size = UDim2.fromScale(0.9, 0.4),
					},
				}, buttonElements),
			}),

			Border = c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "http://www.roblox.com/asset/?id=13382163077",
					ImageColor3 = Styles.GREEN_LIGHT,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.970972, 0.938198),
				},
			}),

			Title = c(Banner, {
				Text = props.Title or "Notification",
				Color = Styles.GREEN,
				Size = UDim2.fromScale(1.21645, 0.371931),
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

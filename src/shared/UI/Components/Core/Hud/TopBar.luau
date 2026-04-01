--[[
	Hud
	Renders groups of Hud buttons used for opening/closing page components.
	Props:
	- CurrentPage: ModuleScript currently selected.
	- SetCurrentPage: Callback to update the selected page (ModuleScript or nil).
]]

--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> components
local Pages = UI.Pages
local Pane = require(UI.Components.Pane)
local HudTabButton = require(UI.Components.Buttons.HudTabButton)

---> private
local c = React.createElement

return function(props: {
    CurrentPage: ModuleScript,
	SetCurrentPage: (pageComponent: ModuleScript | nil, ...any) -> (),
})
    local function setPage(page: ModuleScript)
        return function ()
            props.SetCurrentPage(page)
        end
    end

	return c(Pane, {
		Native = {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, -0.001),
			Size = UDim2.fromScale(0.377911, 0.106612),
		},
		AspectRatio = 6.5443,
	}, {
		Time = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				Image = "http://www.roblox.com/asset/?id=13407992271",
				ImageColor3 = Styles.CREAM,
				Position = UDim2.fromScale(0.5, 0.327),
				Size = UDim2.fromScale(0.263667, 0.633103),
			},
		}, {
			Border = c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Image = "http://www.roblox.com/asset/?id=13408001982",
					ImageColor3 = Styles.GREEN_LIGHT,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, 5, 1, 5),
				},
			}),

			TextLabel = c(Pane, {
				ClassName = "TextLabel",
				Stroke = {
					Color = Styles.GREEN_TEXT,
					Thickness = 2,
				},
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.66),
					Size = UDim2.fromScale(1, 0.364498),
					Text = "12:34 PM",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				},
			}),
		}),

		Base = c(Pane, {
			ClassName = "ImageLabel",
			AspectRatio = 11.5077,
			Native = {
				AnchorPoint = Vector2.new(0.5, 0),
				Image = "http://www.roblox.com/asset/?id=13407950658",
				Position = UDim2.fromScale(0.5, 0),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.982294, 0.558621),
			},
		}, {
			Border = c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Image = "http://www.roblox.com/asset/?id=13407901910",
					ImageColor3 = Styles.GREEN_LIGHT,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1.00668, 1.07692),
				},
			}),

			Buttons = c(Pane, {
				Native = {
					Size = UDim2.fromScale(1, 1),
				},
				ListLayout = {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
				},
			}, {
				Shop = c(HudTabButton, {
					LayoutOrder = 0,
					Text = "Shop",
                    TextColor3 = Styles.GREEN_TEXT,
                    OnClick = setPage(Pages.Shop),
				}),
				Menu = c(HudTabButton, {
					LayoutOrder = 1,
					Text = "Menu",
                    TextColor3 = Styles.GREEN_TEXT,
                    OnClick = setPage(Pages.Menu),
				}),
				Inventory = c(HudTabButton, {
					LayoutOrder = 2,
					Text = "Inventory",
                    TextColor3 = Styles.GREEN_TEXT,
                    OnClick = setPage(Pages.Menu),
				}),
			}),
		}),

		UISizeConstraint = c("UISizeConstraint", {
			MaxSize = Vector2.new(590, math.huge),
			MinSize = Vector2.new(390, math.huge),
		}),
	})
end
--[[
    Component: AdBoard/PassBoard
    Description: Body panel for a game pass or developer product board — icon, price
    pill, description and purchase button.

    Layout reproduces the original hand-built SurfaceGui. Two things the old per-board
    script did imperatively are handled declaratively here:
      * the price pill was resized from TextBounds after two `wait()`s; it now sizes
        itself with AutomaticSize
      * TextScaled was toggled based on TextFits; the description now just wraps
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> config
local AdBoardConfig = require(Shared.Configuration.AdBoardConfig)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement

---> public
return function(props: {
	Description: string,
	Image: string,
	Price: string,
	Color: Color3,
	OnPurchase: () -> (),
})
	return c("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(30, 30),
		Size = UDim2.new(1, -60, 1, -60),
	}, {
		DescriptionFrame = c("Frame", {
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Size = UDim2.fromScale(1, 1),
		}, {
			Content = c("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.05, 0),
				Size = UDim2.new(0.9, 5, 0.75, 0),
			}, {
				Icon = c("ImageLabel", {
					BackgroundTransparency = 1,
					Image = props.Image,
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.4, 1),
				}, {
					-- The price pill hangs off the bottom of the icon, as in V3.
					PriceFrame = c("ImageLabel", {
						AnchorPoint = Vector2.new(0.5, 0),
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundTransparency = 1,
						Image = AdBoardConfig.BUTTON_IMAGE,
						ImageColor3 = props.Color,
						Position = UDim2.fromScale(0.5, 0.75),
						ScaleType = Enum.ScaleType.Slice,
						Size = UDim2.fromScale(0, 0.15),
						SliceCenter = Rect.new(256, 256, 256, 256),
					}, {
						UIListLayout = c("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							Padding = UDim.new(0.02, 0),
							SortOrder = Enum.SortOrder.LayoutOrder,
							VerticalAlignment = Enum.VerticalAlignment.Center,
						}),

						UIPadding = c("UIPadding", {
							PaddingLeft = UDim.new(0, 10),
							PaddingRight = UDim.new(0, 10),
						}),

						PriceInRobux = c("TextLabel", {
							AutomaticSize = Enum.AutomaticSize.X,
							BackgroundTransparency = 1,
							FontFace = Styles.FONT_FREDOKA,
							LayoutOrder = 1,
							Size = UDim2.fromScale(0, 0.8),
							Text = props.Price,
							TextColor3 = props.Color,
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Right,
						}),

						RobuxIcon = c("ImageLabel", {
							BackgroundTransparency = 1,
							Image = AdBoardConfig.ROBUX_ICON,
							ImageColor3 = props.Color,
							LayoutOrder = 2,
							Size = UDim2.fromScale(0.7, 0.7),
							SizeConstraint = Enum.SizeConstraint.RelativeYY,
						}),
					}),
				}),

				Description = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.45, 0),
					RichText = true,
					Size = UDim2.fromScale(0.55, 1),
					Text = props.Description,
					TextColor3 = props.Color,
					TextSize = 36,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),
			}),

			Purchase = c("ImageButton", {
				BackgroundTransparency = 1,
				Image = AdBoardConfig.BUTTON_IMAGE,
				ImageColor3 = props.Color,
				LayoutOrder = 100,
				Position = UDim2.new(0.05, 0, 0.8, 5),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.new(0.9, 0, 0.15, -5),
				SliceCenter = Rect.new(256, 256, 256, 256),
				[React.Event.Activated] = props.OnPurchase,
			}, {
				Label = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.05, 0.175),
					Size = UDim2.fromScale(0.9, 0.65),
					Text = "Purchase",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				}),
			}),
		}),
	})
end

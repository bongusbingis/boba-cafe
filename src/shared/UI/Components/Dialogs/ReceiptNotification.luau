--[[
    Dialog: ReceiptNotification
    Description: Itemised receipt shown to a customer when their order is handed over.

    Props: OrderNumber?, Items ({ { Name, Quantity? } }), PreparedBy?, Total?, OnResolution
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

---> public
return function(props: {
	OrderNumber: string?,
	Items: { { Name: string, Quantity: number? } },
	PreparedBy: string?,
	Total: string?,
	OnResolution: (string) -> (),
})
	local rows: { [string]: any } = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0.02, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, item in props.Items or {} do
		rows[`Item{index}`] = c(Pane, {
			ClassName = "Frame",
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = index,
				Size = UDim2.fromScale(1, 0.11),
			},
		}, {
			Name = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Size = UDim2.fromScale(0.78, 1),
					Text = item.Name,
					TextColor3 = Styles.GREEN_DEEP,
					TextScaled = true,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			}),

			Quantity = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.8, 0),
					Size = UDim2.fromScale(0.2, 1),
					Text = `x{item.Quantity or 1}`,
					TextColor3 = Styles.GREEN_DEEP,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Right,
				},
			}),
		})
	end

	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 0.62,
		CornerRadius = Styles.CORNER_CARD,
		Stroke = { Color = Styles.GREEN_DEEP, Thickness = 3 },
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			-- Paper-white, unlike the other dialogs: it is meant to read as a receipt.
			BackgroundColor3 = Styles.CREAM,
			BackgroundTransparency = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.17, 0.5),
		},
	}, {
		Title = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.05, 0.03),
				Size = UDim2.fromScale(0.9, 0.08),
				Text = "Boba Cafe",
				TextColor3 = Styles.GREEN_DEEP,
				TextScaled = true,
			},
		}),

		OrderNumber = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.05, 0.11),
				Size = UDim2.fromScale(0.9, 0.05),
				Text = if props.OrderNumber then `Order #{props.OrderNumber}` else "",
				TextColor3 = Styles.GREEN_MID,
				TextScaled = true,
			},
		}),

		Divider = c(Pane, {
			ClassName = "Frame",
			Native = {
				BackgroundColor3 = Styles.GREEN_DEEP,
				BackgroundTransparency = 0.5,
				Position = UDim2.fromScale(0.05, 0.18),
				Size = UDim2.fromScale(0.9, 0.004),
			},
		}),

		Items = c(Pane, {
			ClassName = "ScrollingFrame",
			Native = {
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(),
				Position = UDim2.fromScale(0.05, 0.21),
				ScrollBarThickness = 3,
				Size = UDim2.fromScale(0.9, 0.5),
			},
		}, rows),

		PreparedBy = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.05, 0.74),
				Size = UDim2.fromScale(0.9, 0.05),
				Text = if props.PreparedBy then `Prepared by {props.PreparedBy}` else "",
				TextColor3 = Styles.GREEN_MID,
				TextScaled = true,
			},
		}),

		Thanks = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.05, 0.8),
				Size = UDim2.fromScale(0.9, 0.06),
				Text = "Thank you, come again!",
				TextColor3 = Styles.GREEN_DEEP,
				TextScaled = true,
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
				BackgroundColor3 = Styles.GREEN,
				BackgroundTransparency = 0,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.96),
				Size = UDim2.fromScale(0.7, 0.08),
				Text = "Close",
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
			},
		}),
	})
end

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
local PurchaseButton = require(UI.Components.Buttons.PurchaseButton)

local c = React.createElement

return function()
	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Title = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.470149, 0),
			Size = UDim2.fromScale(0.94, 0.09),
			Text = "Celebrity",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		ScrollingFrame = c("ScrollingFrame", {
			Active = true,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.112),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarThickness = 5,
			Size = UDim2.fromScale(1.02, 0.888),
		}, {
			Reasons = c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0.982, 0.21),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
			}, {
				UIListLayout = c("UIListLayout", {
					Padding = UDim.new(0.05, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				Title = c("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.485, 0),
					Size = UDim2.fromScale(0.967662, 0.255814),
					Text = "Reasons to be a Celebrity",
					TextColor3 = Styles.GREEN,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				Container = c("Frame", {
					AnchorPoint = Vector2.new(0, 1),
					BackgroundColor3 = Styles.GREEN,
					LayoutOrder = 1,
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.fromScale(1, 0.697674),
				}, {
					UICorner = c("UICorner", {
						CornerRadius = UDim.new(0.2, 0),
					}),

					Description = c("TextLabel", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.945, 0.774),
						Text = "Celebrities are the most elite type of customer here at Boba! They get unique perks to thank them for their support towards the group.",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				}),
			}),

			Perks = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.fromScale(0.982, 0.21),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
			}, {
				Container = c("Frame", {
					AnchorPoint = Vector2.new(0, 1),
					BackgroundColor3 = Styles.GREEN,
					LayoutOrder = 1,
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.fromScale(1, 0.697674),
				}, {
					UICorner = c("UICorner", {
						CornerRadius = UDim.new(0.2, 0),
					}),

					Description = c("TextLabel", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Position = UDim2.fromScale(0.180872, 0.482759),
						Size = UDim2.fromScale(0.306743, 0.774483),
						Text = [[• Private Island
• 3x Boba Bucks
• Admin Perks]],
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					Description2 = c("TextLabel", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Position = UDim2.fromScale(0.469868, 0.483),
						Size = UDim2.fromScale(0.306743, 0.774483),
						Text = [[• Custom Tag
• Kitchen Access
• Join Notification]],
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				}),

				Title = c("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.485, 0),
					Size = UDim2.fromScale(0.967662, 0.255814),
					Text = "Celebrity Perks",
					TextColor3 = Styles.GREEN,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				UIListLayout = c("UIListLayout", {
					Padding = UDim.new(0.05, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),
			}),

			Buy = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.fromScale(0.982, 0.25),
				SizeConstraint = Enum.SizeConstraint.RelativeXX,
			}, {
				Container = c(Pane, {
					ClassName = "Frame",
					ListLayout = {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0.02, 0),
					},
					Native = {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
					},
				}, {
					Celebrity1 = c(PurchaseButton, {
						Title = "1 Month",
						Price = " 500",
					}),
					Celebrity3 = c(PurchaseButton, {
						Title = "3 Months",
						Price = " 1,250",
						LayoutOrder = 1,
					}),
					Celebrity6 = c(PurchaseButton, {
						Title = "6 Months",
						Price = " 2,250",
						LayoutOrder = 2,
					}),
					Premium = c(PurchaseButton, {
						Title = "10 days",
						Price = "Free w/ Roblox Premium",
						LayoutOrder = 3,
					}),
				}),
			}),

			UIListLayout = c("UIListLayout", {
				Padding = UDim.new(0.035, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}),
	})
end

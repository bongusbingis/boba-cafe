--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local OrderTicket = require(UI.Components.Core.Hud.OrderTicket)
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local SAMPLE_ORDERS = {
	SingleHighPatience = {
		Id = "order_1",
		Label = "Medium Blueberry Boba",
		CustomerName = "Alice",
		Real = false,
		Slot = 1,
		Items = {
			{
				Item = "Boba",
				CustomInfo = {
					Size = "Medium",
					["Syrup Flavor"] = "Blueberry",
					["Tapioca Flavor"] = "Boba",
				},
			},
		},
		Patience = 0.9,
	},
	MultiMidPatience = {
		Id = "order_2",
		Label = "Strawberry + Mango Boba",
		CustomerName = "Bob",
		Real = false,
		Slot = 1,
		Items = {
			{
				Item = "Boba",
				CustomInfo = {
					Size = "Large",
					["Syrup Flavor"] = "Strawberry",
					["Tapioca Flavor"] = "Boba",
				},
			},
			{
				Item = "Boba",
				CustomInfo = {
					Size = "Medium",
					["Syrup Flavor"] = "Mango",
					["Tapioca Flavor"] = "Boba",
				},
			},
		},
		Patience = 0.5,
	},
	CriticalUrgency = {
		Id = "order_3",
		Label = "Vanilla Milk",
		CustomerName = "Charlie",
		Real = true,
		Slot = 1,
		Items = {
			{
				Item = "Flavored Milk",
				CustomInfo = {
					Size = "Small",
					["Syrup Flavor"] = "Vanilla",
				},
			},
		},
		Patience = 0.15,
	},
}

local function OrderTicketStoryContainer()
	local selectedKey, setSelectedKey = React.useState("SingleHighPatience")
	local activeOrder = SAMPLE_ORDERS[selectedKey]

	return c("Frame", {
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(36, 40, 46),
		Size = UDim2.fromScale(1, 1),
	}, {
		-- Toolbar
		Toolbar = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 16),
			Size = UDim2.fromOffset(480, 36),
			BackgroundTransparency = 1,
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			HighBtn = c("TextButton", {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(140, 32),
				BackgroundColor3 = if selectedKey == "SingleHighPatience" then Styles.GREEN else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "High Patience (90%)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setSelectedKey("SingleHighPatience")
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			MidBtn = c("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(140, 32),
				BackgroundColor3 = if selectedKey == "MultiMidPatience" then Styles.GOLD_MID else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Multi-Drink (50%)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setSelectedKey("MultiMidPatience")
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			CritBtn = c("TextButton", {
				LayoutOrder = 3,
				Size = UDim2.fromOffset(140, 32),
				BackgroundColor3 = if selectedKey == "CriticalUrgency" then Styles.RED else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Urgent / Low (15%)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setSelectedKey("CriticalUrgency")
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
		}),

		-- Ticket Frame Mount Area
		TicketMount = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(260, 400),
			BackgroundTransparency = 1,
		}, {
			Ticket = c(OrderTicket, {
				stacked = false,
				slot = 1,
				layoutOrder = 1,
				PreviewOrder = activeOrder,
				PreviewPatience = activeOrder.Patience,
			}),
		}),
	})
end

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(OrderTicketStoryContainer))

	return function()
		root:unmount()
	end
end

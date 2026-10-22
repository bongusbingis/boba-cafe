--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local ShiftCard = require(UI.Components.Core.Hud.ShiftCard)
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local SAMPLE_SHIFTS = {
	Standard = {
		Served = 8,
		Walkouts = 0,
		Stars = 2,
		Pay = 35,
		Tips = 12,
		Bonus = 5,
		Total = 52,
		StreakBonus = 0,
		Shift = 3,
		First = false,
	},
	BestShift = {
		Served = 15,
		Walkouts = 0,
		Stars = 3,
		Pay = 75,
		Tips = 25,
		Bonus = 20,
		Total = 120,
		StreakBonus = 10,
		Shift = 5,
		First = false,
		NewBestShiftPay = true,
		NextUnlock = "Master Barista Title",
	},
	FirstShift = {
		Served = 5,
		Walkouts = 1,
		Stars = 1,
		Pay = 20,
		Tips = 4,
		Bonus = 0,
		Total = 24,
		StreakBonus = 0,
		Shift = 1,
		First = true,
	},
}

local function ShiftCardStoryContainer()
	local activeShiftKey, setActiveShiftKey = React.useState("BestShift")

	return c("Frame", {
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(36, 40, 46),
		Size = UDim2.fromScale(1, 1),
	}, {
		-- Selector toolbar
		Toolbar = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 16),
			Size = UDim2.fromOffset(380, 36),
			BackgroundTransparency = 1,
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			BestBtn = c("TextButton", {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(110, 32),
				BackgroundColor3 = if activeShiftKey == "BestShift" then Styles.GOLD_MID else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Best Shift (3★)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setActiveShiftKey("BestShift")
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			StandardBtn = c("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(110, 32),
				BackgroundColor3 = if activeShiftKey == "Standard" then Styles.GREEN else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Standard (2★)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setActiveShiftKey("Standard")
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			FirstBtn = c("TextButton", {
				LayoutOrder = 3,
				Size = UDim2.fromOffset(110, 32),
				BackgroundColor3 = if activeShiftKey == "FirstShift" then Styles.ROSE_MID else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "First Shift (1★)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setActiveShiftKey("FirstShift")
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
		}),

		-- Shift Card Mount
		CardContainer = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			ShiftCard = c(ShiftCard, {
				Preview = SAMPLE_SHIFTS[activeShiftKey],
			}),
		}),
	})
end

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(ShiftCardStoryContainer))

	return function()
		root:unmount()
	end
end

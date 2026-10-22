--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local CafeRating = require(UI.Components.Core.Hud.CafeRating)
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local function CafeRatingStoryContainer()
	local currentRating, setCurrentRating = React.useState(75)

	-- Update workspace attribute so CafeRating reads the desired story state
	React.useEffect(function()
		local oldRating = workspace:GetAttribute("CafeRating")
		workspace:SetAttribute("CafeRating", currentRating)
		return function()
			workspace:SetAttribute("CafeRating", oldRating)
		end
	end, { currentRating })

	return c("Frame", {
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(36, 40, 46),
		Size = UDim2.fromScale(1, 1),
	}, {
		-- Control toolbar to test multiple cafe ratings
		Controls = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 16),
			Size = UDim2.fromOffset(450, 36),
			BackgroundTransparency = 1,
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Rating20 = c("TextButton", {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(80, 32),
				BackgroundColor3 = if currentRating == 20 then Styles.RED else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "20% (Low)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setCurrentRating(20)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			Rating50 = c("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(80, 32),
				BackgroundColor3 = if currentRating == 50 then Styles.GOLD_MID else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "50% (Mid)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setCurrentRating(50)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			Rating75 = c("TextButton", {
				LayoutOrder = 3,
				Size = UDim2.fromOffset(80, 32),
				BackgroundColor3 = if currentRating == 75 then Styles.GREEN else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "75% (Good)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setCurrentRating(75)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			Rating100 = c("TextButton", {
				LayoutOrder = 4,
				Size = UDim2.fromOffset(80, 32),
				BackgroundColor3 = if currentRating == 100 then Styles.GREEN_BADGE else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "100% (Max)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setCurrentRating(100)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
		}),

		-- Centered Preview Area
		PreviewHolder = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(0.8, 0.4),
			BackgroundTransparency = 1,
		}, {
			CafeRating = c(CafeRating, {
				CurrentPage = nil,
			}),
		}),
	})
end

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(CafeRatingStoryContainer))

	return function()
		root:unmount()
	end
end

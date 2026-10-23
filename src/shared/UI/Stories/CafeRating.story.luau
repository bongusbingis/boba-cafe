--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local TopBar = require(UI.Components.Core.Hud.TopBar)
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local function CafeRatingStoryContainer()
	local currentRating, setCurrentRating = React.useState(75)
	local isRush, setIsRush = React.useState(false)
	local isParty, setIsParty = React.useState(false)

	-- Update workspace attributes so CafeRating reads the desired story state
	React.useEffect(function()
		local oldRating = workspace:GetAttribute("CafeRating")
		local oldRush = workspace:GetAttribute("RushHour")
		local oldEnds = workspace:GetAttribute("RushEndsAt")
		local oldParty = workspace:GetAttribute("BobaParty")
		local oldBuyer = workspace:GetAttribute("BobaPartyBuyer")

		workspace:SetAttribute("CafeRating", currentRating)
		workspace:SetAttribute("RushHour", isRush or isParty)
		workspace:SetAttribute("RushEndsAt", if isRush or isParty then workspace:GetServerTimeNow() + 105 else nil)
		workspace:SetAttribute("BobaParty", isParty)
		workspace:SetAttribute("BobaPartyBuyer", if isParty then "Barista" else nil)

		return function()
			workspace:SetAttribute("CafeRating", oldRating)
			workspace:SetAttribute("RushHour", oldRush)
			workspace:SetAttribute("RushEndsAt", oldEnds)
			workspace:SetAttribute("BobaParty", oldParty)
			workspace:SetAttribute("BobaPartyBuyer", oldBuyer)
		end
	end, { currentRating, isRush, isParty })

	return c("Frame", {
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(36, 40, 46),
		Size = UDim2.fromScale(1, 1),
	}, {
		-- Control toolbar to test multiple cafe ratings & events
		Controls = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 16),
			Size = UDim2.fromOffset(580, 36),
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
				Size = UDim2.fromOffset(75, 32),
				BackgroundColor3 = if currentRating == 20
						and not isRush
						and not isParty
					then Styles.RED
					else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "20% (Low)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 12,
				[React.Event.Activated] = function()
					setCurrentRating(20)
					setIsRush(false)
					setIsParty(false)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			Rating50 = c("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(75, 32),
				BackgroundColor3 = if currentRating == 50
						and not isRush
						and not isParty
					then Styles.GOLD_MID
					else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "50% (Mid)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 12,
				[React.Event.Activated] = function()
					setCurrentRating(50)
					setIsRush(false)
					setIsParty(false)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			Rating75 = c("TextButton", {
				LayoutOrder = 3,
				Size = UDim2.fromOffset(75, 32),
				BackgroundColor3 = if currentRating == 75
						and not isRush
						and not isParty
					then Styles.GREEN
					else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "75% (Good)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 12,
				[React.Event.Activated] = function()
					setCurrentRating(75)
					setIsRush(false)
					setIsParty(false)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			Rating100 = c("TextButton", {
				LayoutOrder = 4,
				Size = UDim2.fromOffset(75, 32),
				BackgroundColor3 = if currentRating == 100
						and not isRush
						and not isParty
					then Styles.GREEN_BADGE
					else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "100% (Max)",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 12,
				[React.Event.Activated] = function()
					setCurrentRating(100)
					setIsRush(false)
					setIsParty(false)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			RushToggle = c("TextButton", {
				LayoutOrder = 5,
				Size = UDim2.fromOffset(90, 32),
				BackgroundColor3 = if isRush then Styles.GOLD_MID else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Rush Hour",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 12,
				[React.Event.Activated] = function()
					setIsRush(function(prev)
						return not prev
					end)
					setIsParty(false)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			PartyToggle = c("TextButton", {
				LayoutOrder = 6,
				Size = UDim2.fromOffset(90, 32),
				BackgroundColor3 = if isParty then Styles.ROSE_MID else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Boba Party",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 12,
				[React.Event.Activated] = function()
					setIsParty(function(prev)
						return not prev
					end)
					setIsRush(false)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
		}),

		-- Centered Preview Area with TopBar
		PreviewHolder = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(0.9, 0.5),
			BackgroundTransparency = 1,
		}, {
			TopBar = c(TopBar, {
				CurrentPage = nil,
				SetCurrentPage = function() end,
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

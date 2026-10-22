--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local EventIntro = require(UI.Components.Core.Hud.EventIntro)
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local function EventIntroStoryContainer()
	local activeIntro, setActiveIntro = React.useState("Rush")
	local buyerName = "StarBarista"

	return c("Frame", {
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(30, 32, 36),
		Size = UDim2.fromScale(1, 1),
	}, {
		-- Selector Bar
		Toolbar = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 16),
			Size = UDim2.fromOffset(450, 36),
			BackgroundTransparency = 1,
			ZIndex = 30,
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			RushBtn = c("TextButton", {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(100, 32),
				BackgroundColor3 = if activeIntro == "Rush" then Styles.GOLD else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Rush Hour",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setActiveIntro("Rush")
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			PartyBtn = c("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(100, 32),
				BackgroundColor3 = if activeIntro == "Party" then Styles.ROSE else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Boba Party",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setActiveIntro("Party")
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			ExtendedBtn = c("TextButton", {
				LayoutOrder = 3,
				Size = UDim2.fromOffset(100, 32),
				BackgroundColor3 = if activeIntro == "Extended" then Styles.ROSE_MID else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Extended",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setActiveIntro("Extended")
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			RushExtBtn = c("TextButton", {
				LayoutOrder = 4,
				Size = UDim2.fromOffset(100, 32),
				BackgroundColor3 = if activeIntro == "RushExtended" then Styles.GOLD_MID else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Rush Ext",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 13,
				[React.Event.Activated] = function()
					setActiveIntro("RushExtended")
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
		}),

		-- EventIntro Mounted
		EventMount = c(EventIntro, {
			Preview = activeIntro,
			PreviewBuyer = if activeIntro == "Party" or activeIntro == "Extended" then buyerName else nil,
		}),
	})
end

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(EventIntroStoryContainer))

	return function()
		root:unmount()
	end
end

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
local Pages = UI.Pages
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local function TopBarStoryContainer()
	local selectedPage, setSelectedPage = React.useState(nil :: ModuleScript?)

	return c("Frame", {
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(40, 44, 52),
		Size = UDim2.fromScale(1, 1),
	}, {
		-- TopBar mounted at native position
		TopBar = c(TopBar, {
			CurrentPage = selectedPage,
			SetCurrentPage = function(page: ModuleScript?)
				setSelectedPage(page)
			end,
		}),

		-- Active selection indicator
		StatusLabel = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.new(0.6, 0, 0, 40),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Text = "Active Tab: " .. (if selectedPage ~= nil then selectedPage.Name else "None"),
			TextColor3 = Styles.OFFWHITE,
			TextSize = 20,
		}),

		-- Control pills to force selection
		ControlBar = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(360, 36),
			BackgroundTransparency = 1,
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			NoneBtn = c("TextButton", {
				LayoutOrder = 1,
				Size = UDim2.fromOffset(80, 32),
				BackgroundColor3 = if selectedPage == nil then Styles.GREEN else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "None",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 14,
				[React.Event.Activated] = function()
					setSelectedPage(nil)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			ShopBtn = c("TextButton", {
				LayoutOrder = 2,
				Size = UDim2.fromOffset(80, 32),
				BackgroundColor3 = if selectedPage == Pages.Shop then Styles.GREEN else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Shop",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 14,
				[React.Event.Activated] = function()
					setSelectedPage(Pages.Shop)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			MenuBtn = c("TextButton", {
				LayoutOrder = 3,
				Size = UDim2.fromOffset(80, 32),
				BackgroundColor3 = if selectedPage == Pages.Menu then Styles.GREEN else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Menu",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 14,
				[React.Event.Activated] = function()
					setSelectedPage(Pages.Menu)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
			InventoryBtn = c("TextButton", {
				LayoutOrder = 4,
				Size = UDim2.fromOffset(80, 32),
				BackgroundColor3 = if selectedPage == Pages.Inventory then Styles.GREEN else Styles.GRAY,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Inventory",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 14,
				[React.Event.Activated] = function()
					setSelectedPage(Pages.Inventory)
				end,
			}, {
				Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			}),
		}),
	})
end

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(TopBarStoryContainer))

	return function()
		root:unmount()
	end
end

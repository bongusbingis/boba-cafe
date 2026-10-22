--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local ActionButton = require(UI.Components.Buttons.ActionButton)
local NormalButton = require(UI.Components.Buttons.NormalButton)
local PromptButton = require(UI.Components.Buttons.PromptButton)
local PurchaseButton = require(UI.Components.Buttons.PurchaseButton)
local CloseButton = require(UI.Components.Buttons.CloseButton)
local HudTabButton = require(UI.Components.Buttons.HudTabButton)
local Banner = require(UI.Components.Buttons.Banner)
local SelectionCard = require(UI.Components.Buttons.SelectionCard)
local PromptTextBox = require(UI.Components.Buttons.PromptTextBox)
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local function sectionHeader(title: string, order: number)
	return c("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		FontFace = Styles.FONT_FREDOKA,
		Text = "— " .. title .. " —",
		TextColor3 = Styles.GOLD,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function rowContainer(children: { [string]: any }, order: number, height: number?)
	return c("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height or 48),
		BackgroundTransparency = 1,
	}, children)
end

local function ButtonsCatalog()
	local clickCount, setClickCount = React.useState(0)
	local textValue, setTextValue = React.useState("Hello Boba")
	local selectedTab, setSelectedTab = React.useState("Menu")

	local function onClick()
		setClickCount(function(prev)
			return prev + 1
		end)
	end

	return c("Frame", {
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(32, 35, 40),
		Size = UDim2.fromScale(1, 1),
	}, {
		-- Top Bar
		Header = c("Frame", {
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundColor3 = Color3.fromRGB(24, 26, 30),
			BorderSizePixel = 0,
		}, {
			Title = c("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 16, 0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Design System: Button Primitives & Interactive Controls",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 18,
				TextXAlignment = Enum.TextXAlignment.Left,
				Size = UDim2.fromScale(0.6, 1),
			}),
			Counter = c("TextLabel", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -16, 0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Text = "Clicks: " .. tostring(clickCount),
				TextColor3 = Styles.GREEN_LIGHT,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Right,
				Size = UDim2.fromScale(0.3, 1),
			}),
		}),

		-- Scrollable Showcase
		Scroll = c("ScrollingFrame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, -24, 1, -54),
			BackgroundTransparency = 1,
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = Styles.GREEN_DIM,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		}, {
			Padding = c("UIPadding", {
				PaddingTop = UDim.new(0, 12),
				PaddingBottom = UDim.new(0, 24),
				PaddingLeft = UDim.new(0, 12),
				PaddingRight = UDim.new(0, 12),
			}),
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 14),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			-- 1. Action Buttons
			SecAction = sectionHeader("Action Buttons (ActionButton)", 1),
			RowAction = rowContainer({
				List = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Green = c(ActionButton, {
					LayoutOrder = 1,
					Text = "Confirm Order",
					Color = Styles.GREEN,
					Size = UDim2.fromOffset(150, 44),
					OnClick = onClick,
				}),
				Rose = c(ActionButton, {
					LayoutOrder = 2,
					Text = "Featured Action",
					Color = Styles.ROSE_MID,
					Size = UDim2.fromOffset(150, 44),
					OnClick = onClick,
				}),
				Gold = c(ActionButton, {
					LayoutOrder = 3,
					Text = "Special Bonus",
					Color = Styles.GOLD_MID,
					Size = UDim2.fromOffset(150, 44),
					OnClick = onClick,
				}),
			}, 2, 48),

			-- 2. Normal / Pill Buttons
			SecNormal = sectionHeader("Pill & Utility Buttons (NormalButton)", 3),
			RowNormal = rowContainer({
				List = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				ClockIn = c(NormalButton, {
					LayoutOrder = 1,
					Text = "Clock In",
					Color = Styles.GREEN_MID,
					Size = UDim2.fromOffset(160, 40),
					OnClick = onClick,
				}),
				ClockOut = c(NormalButton, {
					LayoutOrder = 2,
					Text = "Clock Out",
					Color = Styles.GOLD_MID,
					Size = UDim2.fromOffset(160, 40),
					OnClick = onClick,
				}),
				WithPlus = c(NormalButton, {
					LayoutOrder = 3,
					Text = "Add Shift",
					Color = Styles.GREEN,
					PlusButton = true,
					Size = UDim2.fromOffset(170, 40),
					OnClick = onClick,
					OnPlusButtonClick = onClick,
				}),
			}, 4, 44),

			-- 3. Dialog / Prompt Buttons
			SecPrompt = sectionHeader("Dialog & Modal Buttons (PromptButton)", 5),
			RowPrompt = rowContainer({
				List = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				DefaultPrompt = c(PromptButton, {
					LayoutOrder = 1,
					Text = "Accept",
					Color = Styles.GREEN_DIM,
					Size = UDim2.fromOffset(130, 40),
					OnClick = onClick,
				}),
				DangerPrompt = c(PromptButton, {
					LayoutOrder = 2,
					Text = "Cancel",
					Color = Styles.RED,
					Size = UDim2.fromOffset(130, 40),
					OnClick = onClick,
				}),
				DisabledPrompt = c(PromptButton, {
					LayoutOrder = 3,
					Text = "Unavailable",
					Disabled = true,
					Color = Styles.GRAY,
					Size = UDim2.fromOffset(130, 40),
				}),
			}, 6, 44),

			-- 4. Commerce & Purchase
			SecPurchase = sectionHeader("Purchase Buttons (PurchaseButton)", 7),
			RowPurchase = rowContainer({
				List = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 14),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Bucks = c(PurchaseButton, {
					LayoutOrder = 1,
					Title = "Small Pack",
					Price = "150 Bucks",
					OnClick = onClick,
				}),
				Robux = c(PurchaseButton, {
					LayoutOrder = 2,
					Title = "VIP Gamepass",
					Price = "R$ 499",
					OnClick = onClick,
				}),
			}, 8, 48),

			-- 5. Tabs & Navigation
			SecTabs = sectionHeader("HUD Navigation Tabs (HudTabButton)", 9),
			RowTabs = rowContainer({
				List = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				TabShop = c(HudTabButton, {
					LayoutOrder = 1,
					Text = "Shop",
					Selected = selectedTab == "Shop",
					Size = UDim2.fromOffset(100, 36),
					OnClick = function()
						setSelectedTab("Shop")
					end,
				}),
				TabMenu = c(HudTabButton, {
					LayoutOrder = 2,
					Text = "Menu",
					Selected = selectedTab == "Menu",
					ShowDot = true,
					Size = UDim2.fromOffset(100, 36),
					OnClick = function()
						setSelectedTab("Menu")
					end,
				}),
				TabInv = c(HudTabButton, {
					LayoutOrder = 3,
					Text = "Inventory",
					Selected = selectedTab == "Inventory",
					Size = UDim2.fromOffset(100, 36),
					OnClick = function()
						setSelectedTab("Inventory")
					end,
				}),
			}, 10, 40),

			-- 6. Controls & Text Input
			SecControls = sectionHeader("Modal Disc & Text Input", 11),
			RowControls = rowContainer({
				List = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 16),
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Close = c(CloseButton, {
					OnClick = onClick,
				}),
				TextBox = c(PromptTextBox, {
					Text = textValue,
					PlaceholderText = "Type promo code...",
					Size = UDim2.fromOffset(260, 40),
					OnTextChange = function(val: string)
						setTextValue(val)
					end,
				}),
			}, 12, 50),

			-- 7. Banners
			SecBanner = sectionHeader("Ribbon Banners (Banner)", 13),
			RowBanner = rowContainer({
				List = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				GoldBanner = c(Banner, {
					Color = Styles.GOLD,
					Text = "★ RUSH HOUR ACTIVE! 2x EARNINGS ★",
					Size = UDim2.new(1, 0, 0, 42),
				}),
			}, 14, 50),

			-- 8. Selection Cards
			SecCards = sectionHeader("Option Selection Swatches (SelectionCard)", 15),
			RowSelection = rowContainer({
				List = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 12),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Card1 = c(SelectionCard, {
					LayoutOrder = 1,
					Text = "Blueberry",
					Color = Color3.fromRGB(74, 122, 212),
					OnClick = onClick,
				}),
				Card2 = c(SelectionCard, {
					LayoutOrder = 2,
					Text = "Strawberry",
					Color = Color3.fromRGB(224, 98, 120),
					OnClick = onClick,
				}),
				Card3 = c(SelectionCard, {
					LayoutOrder = 3,
					Text = "Matcha",
					Color = Color3.fromRGB(118, 172, 88),
					OnClick = onClick,
				}),
			}, 16, 90),
		}),
	})
end

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(ButtonsCatalog))

	return function()
		root:unmount()
	end
end

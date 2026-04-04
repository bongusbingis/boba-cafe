local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local CapsuleTierGroup = require(UI.Components.CapsuleTierGroup)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local NametagCard = require(UI.Components.Buttons.NametagCard)
local Pane = require(UI.Components.Pane)
local usePx = require(UI.Hooks.usePx)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement
local nametagColors = InventoryItemDefinitions.Nametags

---> constants
local TIER_COLORS = InventoryItemDefinitions.Tiers
local TIER_ORDER = { "Basic", "Uncommon", "Rare", "Epic", "Legendary", "Special" }
local NAMETAG_CELL_SIZE = 90

---> public
return function()
	local px = usePx()

	local heroCards = {}
	for i, tierName in ipairs(TIER_ORDER) do
		local items = {}
		local onSaleIndex = 0
		local offSaleIndex = 0

		for name, entry in pairs(nametagColors) do
			if entry.Tier ~= tierName then
				continue
			end

			local layoutOrder
			if entry.OffSale then
				offSaleIndex += 1
				layoutOrder = offSaleIndex
			else
				onSaleIndex += 1
				layoutOrder = onSaleIndex
			end

			items[name] = c(NametagCard, {
				Name = name,
				Price = entry.Price,
				Tier = entry.Tier,
				TierColor = TIER_COLORS[tierName].Color,
				Color = entry.Color,
				Animation = entry.Animation,
				OffSale = entry.OffSale,
				LayoutOrder = layoutOrder,
				Size = UDim2.fromOffset(px(NAMETAG_CELL_SIZE), px(NAMETAG_CELL_SIZE)),
			})
		end

		if onSaleIndex + offSaleIndex > 0 then
			heroCards[tierName] = c(CapsuleTierGroup, {
				Tier = tierName,
				LayoutOrder = i,
				Items = items,
			})
		end
	end

	table.insert(
		heroCards,
		c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0.25),
			LayoutOrder = math.huge,
		})
	)

	local capsules = {}

	for k, capsule in ipairs(nametagColors.Capsules) do
		local isMiddle = k == 2
		table.insert(
			capsules,
			c(require(UI.Components.Buttons.ShopCard), {
				Name = capsule.Name,
				Price = capsule.Price,
				Image = capsule.Image,
				Size = isMiddle and UDim2.fromScale(1, 1) or UDim2.fromScale(0.875, 0.875),
				TopBanner = isMiddle and {
					Color = Styles.GREEN_BADGE,
					Text = "Best Value",
					Size = UDim2.fromScale(1, 0.2),
				} or nil,
			})
		)
	end

	return c("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromScale(0.9, 3),
	}, {
		Title = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.470149, 0),
			Size = UDim2.fromScale(0.94, 0.09),
			Text = "Nametag Cosmetics",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		Hint = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.5, 0.095),
			Size = UDim2.fromScale(0.94, 0.085),
			Text = "Open capsules to purchase cosmetics. Each capsule contains a random item!",
			TextColor3 = Styles.GRAY,
			TextScaled = true,
		}),

		CapsulePurchaseRow = c(Pane, {
			ClassName = "Frame",
			Native = {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0.8, 0.25),
				Position = UDim2.fromScale(0.475, 0.2),
				AnchorPoint = Vector2.new(0.5, 0),
			},
			ListLayout = {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
				Padding = UDim.new(0, 20),
			},
		}, capsules),

		Grid = c(Pane, {
			ClassName = "Frame",
			ListLayout = {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 20),
			},
			Native = {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0, 0.475),
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			},
		}, heroCards),
	})
end

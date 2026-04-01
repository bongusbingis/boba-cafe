local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local CapsuleTierGroup = require(UI.Components.CapsuleTierGroup)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local Pane = require(UI.Components.Pane)
local PetCard = require(UI.Components.Buttons.PetCard)
local ShopCard = require(UI.Components.Buttons.ShopCard)
local usePx = require(UI.Hooks.usePx)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement
local pets = InventoryItemDefinitions.Pets

---> constants
local TIER_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Special" }
local PET_CELL_SIZE = 90

---> public
return function()
	local px = usePx()

	local tierGroups = {}
	for i, tierName in ipairs(TIER_ORDER) do
		local items = {}
		local onSaleIndex = 0
		local offSaleIndex = 0

		for _, pet in ipairs(pets) do
			if pet.Tier ~= tierName then
				continue
			end

			local layoutOrder
			if pet.OffSale then
				offSaleIndex += 1
				layoutOrder = offSaleIndex
			else
				onSaleIndex += 1
				layoutOrder = onSaleIndex
			end

			items[pet.Name] = c(PetCard, {
				Name = pet.Name,
				Tier = pet.Tier,
				Model = pet.PetModel,
				OffSale = pet.OffSale,
				LayoutOrder = layoutOrder,
				Size = UDim2.fromOffset(px(PET_CELL_SIZE), px(PET_CELL_SIZE)),
			})
		end

		if onSaleIndex + offSaleIndex > 0 then
			tierGroups[tierName] = c(CapsuleTierGroup, {
				Tier = tierName,
				LayoutOrder = i,
				Items = items,
			})
		end
	end

	table.insert(
		tierGroups,
		c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0.25),
			LayoutOrder = math.huge,
		})
	)

	local capsules = {}
	for k, capsule in ipairs(pets.Capsules) do
		local isMiddle = k == 2
		table.insert(
			capsules,
			c(ShopCard, {
				Name = capsule.Name,
				Price = capsule.Price,
				Image = capsule.Image,
				Size = isMiddle and UDim2.fromScale(1, 1) or UDim2.fromScale(0.875, 0.875),
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
			Text = "Pets",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		Hint = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.5, 0.095),
			Size = UDim2.fromScale(0.94, 0.085),
			Text = "Open capsules to hatch your own pets. Each capsule contains a random pet!",
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
		}, tierGroups),
	})
end

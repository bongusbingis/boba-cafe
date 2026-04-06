local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Promise = require(Packages.Promise)

---> styles
local Styles = require(UI.Styles)

---> components
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local ItemCard = require(UI.Components.Buttons.ItemCard)

---> private
local c = React.createElement
local mapItemDefinitionsToInventory = require(Shared.UI.Utility.mapItemDefsToInventory)

type playerInventory = {
	Inventory: {
		[string]: {
			Name: string,
			Tier: string?,
			Equipped: boolean?,
			StackCount: number?,
			Properties: {
				[string]: any,
			}?,
		},
	},
}

local prettyName = {
	["Nametags"] = "Nametag Colors",
	["Pets"] = "Pets",
}

local function getPlayerInventoryAsync(itemType: string)
	if RunService:IsRunning() then
		local Inventory = require(ReplicatedStorage.Shared.Inventory)
		return Inventory:GetPlayerInventoryAsync(itemType, game.Players.LocalPlayer)
	else
		return Promise.resolve(mapItemDefinitionsToInventory(itemType))
	end
end

local function buildCard(_, entry, itemDef, layoutOrder, equipped, onClick)
	return c(ItemCard, {
		Name = entry.Name,
		Tier = itemDef.Tier,
		Image = itemDef.Image,
		Color = itemDef.Color,
		Model = itemDef.PetModel,
		Animation = itemDef.Animation,
		OffSale = itemDef.OffSale,
		Equipped = equipped,
		LayoutOrder = layoutOrder,
		OnClick = onClick,
	})
end

---> public
return function(props: {
	
})
	local emptyGrid = {
		UIGridLayout = c("UIGridLayout", {
			CellPadding = UDim2.fromScale(0.043, 0.03),
			CellSize = UDim2.fromScale(0.212, 0.288),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = c("UIPadding", {
			PaddingTop = UDim.new(0.02, 0),
			PaddingBottom = UDim.new(0.02, 0),
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
		}),
	}

	local gridChildren, updateGridChildren = React.useState(emptyGrid)

	React.useEffect(function()
		updateGridChildren(emptyGrid)

		for class, items in InventoryItemDefinitions do
			print(class, items)
		end

		getPlayerInventoryAsync(props.ItemType):andThen(function(playerInventory)
			local newCards = {}
			for id, entry in playerInventory.Inventory do
				local itemDef = InventoryItemDefinitions[props.ItemType][entry.Name]
				if not itemDef then
					continue
				end

				local tier = InventoryItemDefinitions.Tiers[itemDef.Tier or "Common"]
				local layoutOrder = tier.Weight * 1000

				local onClick = makeToggleHandler(props.ItemType, id, entry, itemDef, layoutOrder, updateGridChildren)
				newCards[id] = buildCard(props.ItemType, entry, itemDef, layoutOrder, entry:IsEquipped(), onClick)
			end

			updateGridChildren(function(t)
				local new = table.clone(t)
				for k, v in newCards do
					new[k] = v
				end
				return new
			end)
		end)
	end, { props.ItemType })

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
			Text = `My {prettyName[props.ItemType] or props.ItemType}`,
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		Grid = c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.112),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarImageTransparency = 1,
			ScrollBarThickness = 5,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1.02, 0.888),
		}, gridChildren),
	})
end

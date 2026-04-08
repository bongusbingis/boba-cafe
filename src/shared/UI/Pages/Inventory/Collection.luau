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
local Pane = require(UI.Components.Pane)
local ViewportModel = require(UI.Components.ViewportModel)

---> private
local c = React.createElement
local mapItemDefinitionsToInventory = require(Shared.UI.Utility.mapItemDefsToInventory)

-- All collectable item types shown in the collection view.
local ITEM_TYPES = { "Pets", "Nametags", "Capsules", "Particles" }

local function getPlayerInventoryAsync(itemType: string)
	if RunService:IsRunning() then
		local Inventory = require(ReplicatedStorage.Shared.Inventory)
		return Inventory:GetPlayerInventoryAsync(itemType, game.Players.LocalPlayer)
	else
		return Promise.resolve(mapItemDefinitionsToInventory(itemType))
	end
end

-- Fetches inventory for every item type and resolves with an array of results
-- in the same order as ITEM_TYPES.
local function getAllInventoriesAsync()
	local promises = {}
	for i, itemType in ITEM_TYPES do
		promises[i] = getPlayerInventoryAsync(itemType)
	end
	return Promise.all(promises)
end

-- Merges multiple inventory objects into a single name → true lookup.
local function buildOwnedNamesSet(inventories: { any }): { [string]: boolean }
	local owned = {}
	for _, playerInventory in inventories do
		for _, entry in playerInventory.Inventory do
			owned[entry.Name] = true
		end
	end
	return owned
end

-- Unlocked card: full-color, non-interactive ItemCard showing the real item.
local function buildUnlockedCard(itemName: string, itemDef: any, layoutOrder: number)
	return c(ItemCard, {
		Name = itemName,
		Tier = itemDef.Tier,
		Image = itemDef.Image,
		Color = itemDef.Color,
		Model = itemDef.PetModel,
		Animation = itemDef.Animation,
		OffSale = itemDef.OffSale,
		LayoutOrder = layoutOrder,
	})
end

-- Locked card: dark silhouette — pets rendered black via zero-light viewport,
-- image items shown with black tint, color items rendered near-black.
local function buildLockedCard(_itemName: string, itemDef: any, layoutOrder: number)
	local isPet = itemDef.PetModel ~= nil
	local hasImage = itemDef.Image ~= nil

	-- A dark-but-not-black background so the black silhouette is clearly visible.
	-- Lerp only 60% toward black to keep enough hue contrast.
	local tierDef = itemDef.Tier and InventoryItemDefinitions.Tiers[itemDef.Tier]
	local tierColor: Color3 = tierDef and tierDef.Color or Color3.new(0.4, 0.4, 0.5)
	local darkBg = tierColor:Lerp(Color3.new(0, 0, 0), 0.6)

	local children: { [string]: any } = {}

	if isPet then
		-- Zero-light viewport renders the model as a pure black silhouette.
		children.Viewport = c(ViewportModel, {
			Model = itemDef.PetModel,
			Size = UDim2.fromScale(1, 0.55),
			ModelRotation = 15,
			ElevationAngle = 15,
			FieldOfView = 30,
			Ambient = Color3.new(0, 0, 0),
			LightColor = Color3.new(0, 0, 0),
		})
	elseif hasImage then
		children.Image = c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = itemDef.Image,
			ImageColor3 = Color3.new(0, 0, 0),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.675, 0.675),
			ScaleType = Enum.ScaleType.Fit,
		})
	end

	local hasVisualization = isPet or hasImage
	children.NameLabel = c(Pane, {
		ClassName = "TextLabel",
		Stroke = { Thickness = 1.5, Color = Color3.new(0, 0, 0) },
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = hasVisualization and UDim2.fromScale(0.5, 0.82) or UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.22),
			Text = "???",
			TextColor3 = Color3.fromRGB(60, 60, 60),
			TextScaled = true,
		},
	})

	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 1,
		CornerRadius = Styles.CORNER_FULL,
		Native = {
			BackgroundColor3 = darkBg,
			BackgroundTransparency = 0,
			LayoutOrder = layoutOrder,
		},
	}, children)
end

-- Builds the full card grid across all item types from definitions.
-- Unlocked items sort first (low layout order); locked items sort last.
local function buildAllCards(ownedNames: { [string]: boolean })
	local newCards = {}
	for _, itemType in ITEM_TYPES do
		local definitions = InventoryItemDefinitions[itemType]
		if not definitions then
			continue
		end
		for itemName, itemDef in definitions do
			local tier = InventoryItemDefinitions.Tiers[itemDef.Tier or "Basic"]
			local tierOrder = tier and (tier.Weight * 1000) or 500

			if ownedNames[itemName] then
				newCards[itemName] = buildUnlockedCard(itemName, itemDef, tierOrder)
			else
				newCards[itemName] = buildLockedCard(itemName, itemDef, tierOrder)
			end
		end
	end
	return newCards
end

---> public
return function()
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

		getAllInventoriesAsync():andThen(function(inventories: { any })
			local ownedNames = buildOwnedNamesSet(inventories)

			-- Initial render of all cards.
			updateGridChildren(function(t)
				local new = table.clone(t)
				for k, v in buildAllCards(ownedNames) do
					new[k] = v
				end
				return new
			end)

			-- Refresh when any inventory changes (e.g. new unlock from a capsule).
			for _, playerInventory in inventories do
				playerInventory.OnChange:Connect(function(_)
					local updatedOwned = buildOwnedNamesSet(inventories)
					updateGridChildren(function(t)
						local new = table.clone(t)
						for k, v in buildAllCards(updatedOwned) do
							new[k] = v
						end
						return new
					end)
				end)
			end
		end)
	end, {})

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
			Text = "My Collection",
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

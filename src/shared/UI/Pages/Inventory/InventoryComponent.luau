local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local Knit = require(Packages.Knit)
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
			Rarity: string?,
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

local function getSellPrice(itemDef): number?
	if itemDef.SellPrice then
		return itemDef.SellPrice
	end
	local rawPrice = tonumber(itemDef.Price)
	if rawPrice then
		return math.floor(rawPrice * 0.5)
	end
	return nil
end

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
		TopBanner = equipped and { Text = "Equipped", Color = Styles.GREEN } or nil,
		LayoutOrder = (equipped and 0) or layoutOrder,
		OnClick = onClick,
	})
end

local function makeToggleHandler(itemType, id, entry, itemDef, layoutOrder, updateFn, activeDialogRef)
	return function()
		--entry:ToggleEquipped()
		if not RunService:IsRunning() then
			return
		end

		local buttons = { { Text = entry:IsEquipped() and "Unequip" or "Equip" } }
		if InventoryItemDefinitions[itemType].ActionOverride then
			buttons = InventoryItemDefinitions[itemType].ActionOverride
		end

		if itemDef.CanBeSold then
			table.insert(buttons, { Text = "Sell", Color = Styles.ROSE })
		end

		local appDialogs = Knit.GetController("DialogController")
		local dialog = appDialogs.new("ActionPrompt", {
			Title = entry.Name,
			Text = "Choose an action:",
			OffsetX = 0.1,
			Buttons = buttons,
		})
		activeDialogRef.current = dialog
		dialog:Fire():andThen(function(action: string)
			activeDialogRef.current = nil
			if action == "Close" then
				return
			end

			if action == "Sell" then
				local sellPrice = getSellPrice(itemDef)
				local priceText = if sellPrice then `[{sellPrice} Boba Bucks]` else "this item"
				local confirmDialog = appDialogs.new("ButtonPrompt", {
					Title = "Sell Item",
					Text = appDialogs.FormatBrackets(`Sell |{entry.Name}| for {priceText}?`),
					Buttons = {
						{ Text = "Sell", Color = Styles.ROSE },
						{ Text = "Cancel" },
					},
				})
				activeDialogRef.current = confirmDialog
				confirmDialog:Fire():andThen(function(choice)
					activeDialogRef.current = nil
					if choice == "Sell" then
						entry:Sell()
					end
				end)
				return
			end

			entry[action](entry)
		end)

		-- local equipped = entry:IsEquipped()
		-- updateFn(function(t)
		-- 	local new = table.clone(t)
		-- 	new[id] = buildCard(itemType, entry.Name, itemDef, layoutOrder, equipped, new[id].props.OnClick)
		-- 	return new
		-- end)
	end
end

---> public
return function(props: {
	ItemType: string,
})
	local itemDefs = InventoryItemDefinitions[props.ItemType]
	local onSaleCount = 0
	for _, entry in pairs(itemDefs) do
		if not entry.OffSale then
			onSaleCount += 1
		end
	end

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
	local activeDialogRef = React.useRef(nil)

	local function removeActiveDialogRef()
		if activeDialogRef.current then
			activeDialogRef.current:Destroy("Close")
			activeDialogRef.current = nil
		end
	end

	React.useEffect(function()
		return removeActiveDialogRef
	end, {})

	React.useEffect(function()
		removeActiveDialogRef()
		updateGridChildren(emptyGrid)
		getPlayerInventoryAsync(props.ItemType):andThen(function(playerInventory)
			playerInventory.OnChange:Connect(function(update)
				if update.action == "removed" then
					updateGridChildren(function(t)
						local new = table.clone(t)
						new[update.itemId] = nil
						return new
					end)
					return
				end

				local item = playerInventory:GetItemFromId(update.itemId)

				updateGridChildren(function(t)
					local new = table.clone(t)
					new[update.itemId] = buildCard(
						props.ItemType,
						item,
						InventoryItemDefinitions[props.ItemType][item.Name],
						0,
						item:IsEquipped(),
						makeToggleHandler(
							props.ItemType,
							update.itemId,
							item,
							InventoryItemDefinitions[props.ItemType][item.Name],
							0,
							updateGridChildren,
							activeDialogRef
						)
					)
					return new
				end)
			end)
			local newCards = {}
			for id, entry in playerInventory.Inventory do
				local itemDef = InventoryItemDefinitions[props.ItemType][entry.Name]
				if not itemDef then
					continue
				end

				local tier = InventoryItemDefinitions.Tiers[itemDef.Tier or "Common"]
				local layoutOrder = tier.Weight * 1000

				local onClick = makeToggleHandler(
					props.ItemType,
					id,
					entry,
					itemDef,
					layoutOrder,
					updateGridChildren,
					activeDialogRef
				)
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

	local itemCount = 0
	for k in gridChildren do
		if k ~= "UIGridLayout" and k ~= "UIPadding" then
			itemCount += 1
		end
	end

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

		EmptyLabel = itemCount == 0 and c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.475, 0.112),
			Size = UDim2.fromScale(0.9, 0.075),
			Text = `You don't have any {(prettyName[props.ItemType] or props.ItemType):lower()}!`,
			TextColor3 = Styles.GREEN,
			TextScaled = true,
			TextTransparency = 0.4,
		}) or nil,
	})
end

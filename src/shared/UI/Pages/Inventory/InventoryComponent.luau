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
local PetConfig = require(Shared.Configuration.PetConfig)
local ItemCard = require(UI.Components.Buttons.ItemCard)

---> private
local c = React.createElement
local mapItemDefinitionsToInventory = require(Shared.UI.Utility.mapItemDefsToInventory)
local useClock = require(UI.Hooks.useClock)

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

local function getSellPrice(tier: string): number
	local tierDef = InventoryItemDefinitions.Tiers[tier]
	if tierDef and tierDef.SellPrice then
		return tierDef.SellPrice
	end
	return 0
end

local function getPlayerInventoryAsync(itemType: string)
	if RunService:IsRunning() then
		local Inventory = require(ReplicatedStorage.Shared.Inventory)
		return Inventory:GetPlayerInventoryAsync(itemType, game.Players.LocalPlayer)
	else
		return Promise.resolve(mapItemDefinitionsToInventory(itemType))
	end
end

local function trimText(raw: string): string
	return (raw:gsub("^%s*(.-)%s*$", "%1"))
end

local function hasButton(buttons: { { Text: string } }, buttonText: string): boolean
	for _, button in ipairs(buttons) do
		if button.Text == buttonText then
			return true
		end
	end

	return false
end

local function getEntryDisplayName(entry): string
	if entry and entry.GetDisplayName then
		return entry:GetDisplayName()
	end

	local properties = entry and entry.GetProperties and entry:GetProperties() or nil
	if properties and typeof(properties.DisplayName) == "string" then
		local trimmed = trimText(properties.DisplayName)
		if trimmed ~= "" then
			return trimmed
		end
	end

	return entry.Name
end

local function buildCard(_, entry, itemDef, layoutOrder, equipped, onClick)
	return c(ItemCard, {
		Name = getEntryDisplayName(entry),
		Tier = itemDef.Tier,
		Image = itemDef.Image,
		ImageSize = entry._type == "Particles" and UDim2.fromScale(0.675, 0.675) or UDim2.fromScale(1, 1),
		Color = itemDef.Color,
		Model = itemDef.PetModel,
		Animation = itemDef.Animation,
		OffSale = itemDef.OffSale,
		TopBanner = equipped and { Text = "Equipped", Color = Styles.GREEN } or nil,
		LayoutOrder = (equipped and 0) or layoutOrder,
		OnClick = onClick,
	})
end

local function cloneButtons(buttons: { [number]: { [string]: any } }): { [number]: { [string]: any } }
	local copied = {}
	for i, button in ipairs(buttons) do
		copied[i] = table.clone(button)
	end
	return copied
end

local function resolveCapsuleUseLabel(itemType: string, itemDef: any): string?
	if itemType ~= "Capsules" then
		return nil
	end

	if itemDef and itemDef.ItemType == "Pets" then
		return "Hatch"
	end

	return "Open"
end

local function hasActivePetHatch(playerData: any): boolean
	if not playerData then
		return false
	end

	local hatchingPet = playerData.HatchingPet
	if hatchingPet and hatchingPet ~= false then
		return true
	end

	local legacyHatchingPets = playerData.HatchingPets
	if type(legacyHatchingPets) == "table" then
		return next(legacyHatchingPets) ~= nil
	end

	return false
end

local function makeToggleHandler(itemType, _id, entry, itemDef, _layoutOrder, _updateFn, activeDialogRef)
	return function()
		--entry:ToggleEquipped()
		if not RunService:IsRunning() then
			return
		end

		if activeDialogRef.current then
			return
		end

		local buttons = { { Text = entry:IsEquipped() and "Unequip" or "Equip" } }
		local actionOverride = InventoryItemDefinitions[itemType].ActionOverride
		local displayToAction: { [string]: string } = {}
		local displayName = getEntryDisplayName(entry)

		local DataController = Knit.GetController("DataController")
		DataController:GetDataAsync():andThen(function(playerData)
			local shouldDisablePetHatch = itemType == "Capsules"
				and itemDef
				and itemDef.ItemType == "Pets"
				and hasActivePetHatch(playerData)

			if actionOverride then
				buttons = cloneButtons(actionOverride)

				local capsuleUseLabel = resolveCapsuleUseLabel(itemType, itemDef)
				if capsuleUseLabel then
					for _, button in ipairs(buttons) do
						if button.Text == "Hatch" then
							button.Text = capsuleUseLabel
							displayToAction[capsuleUseLabel] = "Hatch"
							if shouldDisablePetHatch and capsuleUseLabel == "Hatch" then
								button.Disabled = true
							end
						end
					end
				end
			end

			local hasSellButton = hasButton(buttons, "Sell")
			local hasRenameButton = hasButton(buttons, "Rename")

			if itemDef.CanBeSold and not hasSellButton then
				table.insert(buttons, { Text = "Sell", Color = Styles.ROSE })
			end

			if itemType == "Pets" and not hasRenameButton then
				table.insert(buttons, { Text = "Rename", Color = Styles.GOLD })
			end

			local appDialogs = Knit.GetController("DialogController")
			local dialog = appDialogs.new("ActionPrompt", {
				Title = displayName,
				Text = "Choose an action:",
				OffsetX = 0.1,
				Buttons = buttons,
			})
			activeDialogRef.current = dialog
			dialog:Fire():andThen(function(action: string)
				activeDialogRef.current = nil
				local resolvedAction = displayToAction[action] or action
				if resolvedAction == "Close" then
					return
				end

				if resolvedAction == "Sell" then
					local sellPrice = getSellPrice(itemDef.Tier)
					local priceText = `[{sellPrice} Boba Bucks]`
					local confirmDialog = appDialogs.new("ButtonPrompt", {
						Title = "Sell Item",
						Text = appDialogs.FormatBrackets(`Sell |{displayName}| for {priceText}?`),
						Buttons = {
							{ Text = "Sell", Color = Styles.GREEN },
							{ Text = "Cancel", Color = Styles.RED },
						},
						OffsetX = 0.1,
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

				if resolvedAction == "Rename" and itemType == "Pets" then
					local function showRenamePrompt(errorText: string?)
						local text = errorText
							or string.format(
								"Enter a new name. Leave blank to reset. Max %d characters.",
								PetConfig.MAX_RENAME_LENGTH
							)

						local renameDialog = appDialogs.new("TextInputPrompt", {
							Title = "Rename Pet",
							Text = text,
							PlaceholderText = displayName,
							OffsetX = 0.1,
						})

						activeDialogRef.current = renameDialog
						renameDialog:Fire():andThen(function(newName)
							activeDialogRef.current = nil
							if typeof(newName) ~= "string" then
								return
							end

							local trimmedName = trimText(newName)
							if trimmedName ~= "" and #trimmedName > PetConfig.MAX_RENAME_LENGTH then
								showRenamePrompt(string.format("That name is too long (max %d).", PetConfig.MAX_RENAME_LENGTH))
								return
							end

							entry:Rename(trimmedName)
						end)
					end

					showRenamePrompt(nil)
					return
				end

				-- "Equip"/"Unequip" are direct methods on InventoryItem.
				-- Any other action (e.g. "Hatch") is a registered ItemAction.
				if resolvedAction == "Equip" or resolvedAction == "Unequip" then
					entry[resolvedAction](entry)
				else
					entry:Use(resolvedAction)
				end
			end)
		end):catch(function(err)
			warn("[InventoryComponent]: Failed to read player hatch state", err)
		end)

		-- local equipped = entry:IsEquipped()
		-- updateFn(function(t)
		-- 	local new = table.clone(t)
		-- 	new[id] = buildCard(itemType, entry.Name, itemDef, layoutOrder, equipped, new[id].props.OnClick)
		-- 	return new
		-- end)
	end
end

---> builds a single card representing a stack of same-name items
local function buildStackCard(itemType, name, ids, playerInventory, itemDef, layoutOrder, updateFn, aDialogRef)
	local representativeId = ids[1]
	local equipped = false
	for _, id in ids do
		local entry = playerInventory:GetItemFromId(id)
		if entry and entry:IsEquipped() then
			representativeId = id
			equipped = true
			break
		end
	end
	local representativeEntry = playerInventory:GetItemFromId(representativeId)
	if not representativeEntry then
		return nil
	end

	local count = #ids
	local onClick = makeToggleHandler(itemType, representativeId, representativeEntry, itemDef, layoutOrder, updateFn, aDialogRef)

	return c(ItemCard, {
		Name = name,
		Tier = itemDef.Tier,
		Image = itemDef.Image,
		ImageSize = representativeEntry._type == "Particles" and UDim2.fromScale(0.675, 0.675) or UDim2.fromScale(1, 1),
		Color = itemDef.Color,
		Model = itemDef.PetModel,
		Animation = itemDef.Animation,
		OffSale = itemDef.OffSale,
		TopBanner = equipped and { Text = "Equipped", Color = Styles.GREEN } or nil,
		StackCount = count,
		LayoutOrder = equipped and 0 or layoutOrder,
		OnClick = onClick,
	})
end

local BATCH_SIZE = 16
local BATCH_DELAY = 0.05

local SPIN_PERIOD = 1.4 -- seconds per full rotation cycle

---> item types where duplicate names are collapsed into one card with a ×N badge
local STACKABLE_TYPES = { ["Nametags"] = true }

local function easeInOutBack(t: number): number
	local c1 = 1.70158
	local c2 = c1 * 1.525
	if t < 0.5 then
		return ((2 * t) ^ 2 * ((c2 + 1) * (2 * t) - c2)) / 2
	else
		local x = 2 * t - 2
		return (x ^ 2 * ((c2 + 1) * x + c2) + 2) / 2
	end
end

---> public
return function(props: {
	ItemType: string,
})
	local emptyGrid = {
		UIGridLayout = c("UIGridLayout", {
			CellPadding = UDim2.fromScale(0.043, 0.03),
			CellSize = UDim2.fromScale(0.212, 0.288),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = c("UIPadding", {
			PaddingTop = UDim.new(0.01, 0),
			PaddingBottom = UDim.new(0.02, 0),
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
		}),
	}

	local gridChildren, updateGridChildren = React.useState(emptyGrid)
	local isLoading, setIsLoading = React.useState(true)
	local clockBinding = useClock()
	local activeDialogRef = React.useRef(nil)
	local stackDataRef = React.useRef(nil) -- { nameToIds: {[string]: {string}}, idToName: {[string]: string} }

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
		setIsLoading(true)
		local cancelled = false

		getPlayerInventoryAsync(props.ItemType):andThen(function(playerInventory)
			local isStackableType = STACKABLE_TYPES[props.ItemType]

			playerInventory.OnChange:Connect(function(update)
				local sd = stackDataRef.current

				if update.action == "removed" then
					if isStackableType and sd and sd.idToName[update.itemId] then
						local name = sd.idToName[update.itemId]
						sd.idToName[update.itemId] = nil
						local ids = sd.nameToIds[name]
						for i, id in ids do
							if id == update.itemId then
								table.remove(ids, i)
								break
							end
						end
						updateGridChildren(function(t)
							local new = table.clone(t)
							if #ids == 0 then
								new["stack:" .. name] = nil
							else
								local itemDef = InventoryItemDefinitions[props.ItemType][name]
								local tier = InventoryItemDefinitions.Tiers[(itemDef and itemDef.Tier) or "Basic"]
								new["stack:" .. name] = buildStackCard(props.ItemType, name, ids, playerInventory, itemDef, tier.Weight * 1000, updateGridChildren, activeDialogRef)
							end
							return new
						end)
					else
						updateGridChildren(function(t)
							local new = table.clone(t)
							new[update.itemId] = nil
							return new
						end)
					end
					return
				end

				local item = playerInventory:GetItemFromId(update.itemId)
				if not item then
					return
				end
				local itemDef = InventoryItemDefinitions[props.ItemType][item.Name]
				if not itemDef then
					return
				end

				if isStackableType and sd then
					local name = item.Name
					-- register new items that arrived after initial load
					if not sd.idToName[update.itemId] then
						if not sd.nameToIds[name] then
							sd.nameToIds[name] = {}
						end
						table.insert(sd.nameToIds[name], update.itemId)
						sd.idToName[update.itemId] = name
					end
					local ids = sd.nameToIds[name]
					local tier = InventoryItemDefinitions.Tiers[itemDef.Tier or "Basic"]
					updateGridChildren(function(t)
						local new = table.clone(t)
						new["stack:" .. name] = buildStackCard(props.ItemType, name, ids, playerInventory, itemDef, tier.Weight * 1000, updateGridChildren, activeDialogRef)
						return new
					end)
				else
					updateGridChildren(function(t)
						local new = table.clone(t)
						new[update.itemId] = buildCard(
							props.ItemType,
							item,
							itemDef,
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
				end
			end)

			local cardList = {}
			local nameGroups: { [string]: { ids: { string }, itemDef: any, layoutOrder: number } } = {}
			local newStackData = { nameToIds = {} :: { [string]: { string } }, idToName = {} :: { [string]: string } }

			for id, entry in playerInventory.Inventory do
				local itemDef = InventoryItemDefinitions[props.ItemType][entry.Name]
				if not itemDef then
					continue
				end

				local tier = InventoryItemDefinitions.Tiers[itemDef.Tier or "Basic"]
				local layoutOrder = tier.Weight * 1000

				if isStackableType then
					if not nameGroups[entry.Name] then
						nameGroups[entry.Name] = { ids = {}, itemDef = itemDef, layoutOrder = layoutOrder }
					end
					table.insert(nameGroups[entry.Name].ids, id)
					newStackData.idToName[id] = entry.Name
				else
					local onClick = makeToggleHandler(props.ItemType, id, entry, itemDef, layoutOrder, updateGridChildren, activeDialogRef)
					table.insert(cardList, { id = id, card = buildCard(props.ItemType, entry, itemDef, layoutOrder, entry:IsEquipped(), onClick) })
				end
			end

			if isStackableType then
				for name, group in nameGroups do
					newStackData.nameToIds[name] = group.ids
					local card = buildStackCard(props.ItemType, name, group.ids, playerInventory, group.itemDef, group.layoutOrder, updateGridChildren, activeDialogRef)
					if card then
						table.insert(cardList, { id = "stack:" .. name, card = card })
					end
				end
			end
			stackDataRef.current = newStackData

			local function applyBatch(startIdx: number)
				if cancelled then
					return
				end
				local isLastBatch = startIdx + BATCH_SIZE > #cardList
				updateGridChildren(function(t)
					local new = table.clone(t)
					for i = startIdx, math.min(startIdx + BATCH_SIZE - 1, #cardList) do
						new[cardList[i].id] = cardList[i].card
					end
					return new
				end)
				if isLastBatch then
					setIsLoading(false)
				else
					task.delay(BATCH_DELAY, function()
						applyBatch(startIdx + BATCH_SIZE)
					end)
				end
			end

			if #cardList < BATCH_SIZE * 2 then
				updateGridChildren(function(t)
					local new = table.clone(t)
					for _, entry in cardList do
						new[entry.id] = entry.card
					end
					return new
				end)
				setIsLoading(false)
			else
				applyBatch(1)
			end
		end)

		return function()
			cancelled = true
		end
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
			Visible = not isLoading,
		}, gridChildren),

		LoadingSpinner = isLoading and c("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = "rbxassetid://5634393881",
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.175, 0.175),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			ScaleType = Enum.ScaleType.Fit,
			Rotation = clockBinding:map(function(clock: number)
				local t = (clock % SPIN_PERIOD) / SPIN_PERIOD
				return easeInOutBack(t) * 360
			end),
		}) or nil,

		EmptyLabel = (not isLoading) and itemCount == 0 and c("TextLabel", {
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

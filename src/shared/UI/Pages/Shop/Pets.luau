local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Knit = require(Packages.Knit)

---> components
local CapsuleTierGroup = require(UI.Components.CapsuleTierGroup)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local PetCard = require(UI.Components.Buttons.PetCard)
local ShopCard = require(UI.Components.Buttons.ShopCard)
local BobaBucksShortfall = require(UI.Utility.BobaBucksShortfall)
local usePx = require(UI.Hooks.usePx)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement
local pets = InventoryItemDefinitions.Pets

---> constants
local TIER_ORDER = { "Basic", "Uncommon", "Rare", "Epic", "Legendary" }
local PET_CELL_SIZE = 90

---> public
return function()
	local px = usePx()
	local policyState, setPolicyState = React.useState("loading" :: "loading" | "allowed" | "restricted")

	React.useEffect(function()
		local alive = true
		Knit.GetService("CapsuleService")
			:GetPaidRandomPolicy()
			:andThen(function(ok, restricted)
				if alive then
					setPolicyState(if ok and restricted == false then "allowed" else "restricted")
				end
			end)
			:catch(function()
				if alive then
					setPolicyState("allowed")
				end
			end)
		return function()
			alive = false
		end
	end, {})

	local function promptPetPurchase(capsuleName: string, priceStr: string)
		local DialogController = Knit.GetController("DialogController")
		local prompt = DialogController.new("ButtonPrompt", {
			Title = `Buy {capsuleName}`,
			Text = `Buy {capsuleName} for {priceStr}?`,
			Buttons = {
				{ Text = "Buy", Color = Styles.GREEN },
				{ Text = "Cancel", Color = Styles.RED },
			},
		})
		prompt:Fire():andThen(function(choice)
			if choice ~= "Buy" then
				return
			end
			Knit.GetService("CapsuleService"):PurchasePetCapsule(capsuleName):andThen(function(ok, reason)
				if not ok and reason == "InsufficientFunds" then
					BobaBucksShortfall.Prompt({ Price = priceStr, What = capsuleName })
					return
				end
				local result = DialogController.new("ButtonPrompt", {
					Title = if ok then "Purchase Complete" else "Purchase Unavailable",
					Text = if ok
						then `{capsuleName} was added to your inventory! Go to Inventory > Capsules to hatch it.`
						elseif reason == "InventoryFull" then "Your inventory is full. Make some room and try again."
						else "The purchase could not be completed. Please try again.",
					Buttons = { { Text = "Close", Color = Styles.GREEN } },
				})
				result:Fire()
			end)
		end)
	end

	local tierGroups = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 16),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, tierName in ipairs(TIER_ORDER) do
		local items = {}
		local onSaleIndex = 0
		local offSaleIndex = 0

		for name, pet in pairs(pets) do
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

			items[name] = c(PetCard, {
				Name = name,
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

	tierGroups["BottomSpacer"] = c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 30),
		LayoutOrder = 9999,
	})

	local capsuleChildren = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
			Padding = UDim.new(0, 20),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for k, capsule in ipairs(pets.Capsules) do
		local isMiddle = k == 2
		capsuleChildren[`capsule_{k}`] = c(ShopCard, {
			Name = capsule.Name,
			Price = capsule.Price,
			Image = capsule.Image,
			ImageSize = UDim2.fromScale(1, 1),
			Size = isMiddle and UDim2.fromScale(1, 1) or UDim2.fromScale(0.875, 0.875),
			LayoutOrder = k,
			ShowPrice = true,
			OnClick = if policyState == "allowed"
				then function()
					promptPetPurchase(capsule.Name, `{capsule.Price} Boba Bucks`)
				end
				else nil,
		})
	end

	return c("ScrollingFrame", {
		Active = true,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		ScrollBarImageColor3 = Color3.new(),
		ScrollBarThickness = 5,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	}, {
		ListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		Padding = c("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
		}),

		Title = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			LayoutOrder = 1,
			Size = UDim2.new(0.94, 0, 0, 32),
			Text = "Pets",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		Hint = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			LayoutOrder = 2,
			Size = UDim2.new(0.94, 0, 0, 20),
			Text = if policyState == "restricted"
				then "Random capsule purchases are unavailable for this account."
				else "Open capsules to hatch your own pets. Each capsule contains a random pet!",
			TextColor3 = if policyState == "restricted" then Styles.RED else Styles.GRAY,
			TextScaled = true,
		}),

		CapsulePurchaseRow = if policyState == "allowed"
			then c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				Size = UDim2.new(0.85, 0, 0, 120),
			}, capsuleChildren)
			else nil,

		Grid = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 4,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, tierGroups),
	})
end

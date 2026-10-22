local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Knit = require(Packages.Knit)

---> configuration
local EventProducts = require(Shared.Utility.EventProducts)
local GamepassUtil = require(Shared.Utility.GamepassUtil)

---> styles
local Styles = require(UI.Styles)

---> components
local ShopCard = require(UI.Components.Buttons.ShopCard)
local BobaBucksShortfall = require(UI.Utility.BobaBucksShortfall)

---> private
local c = React.createElement

local HEADLESS_PASS_ID = 14067340

type FeaturedCardData = {
	Key: string,
	Name: string,
	Price: string?,
	Image: string,
	Tier: string?,
	Owned: boolean?,
	TopBanner: { Color: Color3, Text: string, Size: UDim2 }?,
	LayoutOrder: number,
	OnClick: () -> (),
}

---> public
return function()
	local localPlayer = Players.LocalPlayer
	local headlessPrice, setHeadlessPrice = React.useState("\u{e002} 250")
	local headlessOwned, setHeadlessOwned = React.useState(false)
	local bobaPartyPrice, setBobaPartyPrice = React.useState("\u{e002} 249")

	React.useEffect(function()
		local mounted = true
		task.spawn(function()
			-- Fetch Headless Head gamepass info
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(HEADLESS_PASS_ID, Enum.InfoType.GamePass)
			end)
			if mounted and ok and typeof(info) == "table" and info.PriceInRobux ~= nil then
				setHeadlessPrice(`\u{e002} {info.PriceInRobux}`)
			end

			-- Check Headless Head ownership
			if localPlayer then
				local ownOk, owns = pcall(function()
					return GamepassUtil:PlayerOwnsPassAsync(localPlayer, HEADLESS_PASS_ID)
				end)
				if mounted and ownOk and owns then
					setHeadlessOwned(true)
				end
			end

			-- Fetch Boba Party price
			local partyPrices = EventProducts.fetchPrices()
			if mounted and partyPrices["BobaParty"] then
				setBobaPartyPrice(`\u{e002} {partyPrices["BobaParty"]}`)
			end
		end)

		local conn = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
			if wasPurchased and player == localPlayer and passId == HEADLESS_PASS_ID and mounted then
				setHeadlessOwned(true)
			end
		end)

		return function()
			mounted = false
			conn:Disconnect()
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

	local function promptNametagPurchase(packName: string, packSize: number, priceStr: string)
		local DialogController = Knit.GetController("DialogController")
		local prompt = DialogController.new("ButtonPrompt", {
			Title = `Buy {packName}`,
			Text = `Buy {packName} for {priceStr}?`,
			Buttons = {
				{ Text = "Buy", Color = Styles.GREEN },
				{ Text = "Cancel", Color = Styles.RED },
			},
		})
		prompt:Fire():andThen(function(choice)
			if choice ~= "Buy" then
				return
			end
			Knit.GetService("CapsuleService"):PurchaseNametagCapsules(packSize):andThen(function(ok, reason)
				if not ok and reason == "InsufficientFunds" then
					BobaBucksShortfall.Prompt({ Price = priceStr, What = packName })
					return
				end
				local result = DialogController.new("ButtonPrompt", {
					Title = if ok then "Purchase Complete" else "Purchase Unavailable",
					Text = if ok
						then `{packName} was added to your inventory!`
						elseif reason == "InventoryFull" then "Your inventory is full. Make some room and try again."
						else "The purchase could not be completed. Please try again.",
					Buttons = { { Text = "Close", Color = Styles.GREEN } },
				})
				result:Fire()
			end)
		end)
	end

	local featuredCards: { FeaturedCardData } = {
		{
			Key = "HeadlessHead",
			Name = "Headless Head",
			Owned = headlessOwned,
			Price = headlessPrice,
			Image = "rbxassetid://16728123607",
			TopBanner = {
				Color = if headlessOwned then Styles.GREEN_BADGE else Styles.ROSE_MID,
				Text = if headlessOwned then "Owned" else "New Pass",
				Size = UDim2.fromScale(1.05, 0.28),
			},
			LayoutOrder = 1,
			OnClick = function()
				if localPlayer then
					MarketplaceService:PromptGamePassPurchase(localPlayer, HEADLESS_PASS_ID)
				end
			end,
		},
		{
			Key = "BobaParty",
			Name = "Boba Party",
			Price = bobaPartyPrice,
			Image = "rbxassetid://16728139086",
			TopBanner = {
				Color = Styles.GREEN_BADGE,
				Text = "Event",
				Size = UDim2.fromScale(1.05, 0.28),
			},
			LayoutOrder = 2,
			OnClick = function()
				local partyProduct = nil
				for _, prod in EventProducts.Products do
					if prod.Key == "BobaParty" then
						partyProduct = prod
						break
					end
				end
				if partyProduct then
					EventProducts.prompt(partyProduct)
				end
			end,
		},
		{
			Key = "EpicPetCapsule",
			Name = "Epic Pet Capsule",
			Price = " 1,200",
			Image = "rbxassetid://9369156094",
			Tier = "Epic",
			TopBanner = {
				Color = Styles.GREEN_BADGE,
				Text = "Featured",
				Size = UDim2.fromScale(1.05, 0.28),
			},
			LayoutOrder = 3,
			OnClick = function()
				promptPetPurchase("Epic Pet Capsule", "1,200 Boba Bucks")
			end,
		},
		{
			Key = "RarePetCapsule",
			Name = "Rare Pet Capsule",
			Price = " 250",
			Image = "rbxassetid://7621095542",
			Tier = "Rare",
			LayoutOrder = 4,
			OnClick = function()
				promptPetPurchase("Rare Pet Capsule", "250 Boba Bucks")
			end,
		},
		{
			Key = "RegularPetCapsule",
			Name = "Regular Pet Capsule",
			Price = " 75",
			Image = "rbxassetid://6073658218",
			Tier = "Basic",
			LayoutOrder = 5,
			OnClick = function()
				promptPetPurchase("Regular Pet Capsule", "75 Boba Bucks")
			end,
		},
		{
			Key = "NametagCapsule10",
			Name = "10 Nametag Capsules",
			Price = " 1,350",
			Image = "rbxassetid://6073658218",
			TopBanner = {
				Color = Styles.GREEN_BADGE,
				Text = "Best Value",
				Size = UDim2.fromScale(1.05, 0.28),
			},
			LayoutOrder = 6,
			OnClick = function()
				promptNametagPurchase("10 Nametag Capsules", 10, "1,350 Boba Bucks")
			end,
		},
		{
			Key = "NametagCapsule1",
			Name = "Nametag Capsule",
			Price = " 150",
			Image = "rbxassetid://6073658218",
			LayoutOrder = 7,
			OnClick = function()
				promptNametagPurchase("Nametag Capsule", 1, "150 Boba Bucks")
			end,
		},
	}

	local gridChildren = {
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

	for _, card in ipairs(featuredCards) do
		gridChildren[card.Key] = c(ShopCard, {
			Name = card.Name,
			Price = card.Price,
			Image = card.Image,
			ImageSize = UDim2.fromScale(1, 1),
			Tier = card.Tier,
			Owned = card.Owned,
			TopBanner = card.TopBanner,
			LayoutOrder = card.LayoutOrder,
			OnClick = card.OnClick,
		})
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
			Text = "Featured",
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

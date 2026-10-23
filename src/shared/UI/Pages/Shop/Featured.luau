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
local ProductIds = require(Shared.Configuration.ProductIds)

---> styles
local Styles = require(UI.Styles)

---> components
local ShopCard = require(UI.Components.Buttons.ShopCard)
local Pane = require(UI.Components.Pane)
local PromptButton = require(UI.Components.Buttons.PromptButton)
local BobaBucksShortfall = require(UI.Utility.BobaBucksShortfall)
local usePx = require(UI.Hooks.usePx)

---> private
local c = React.createElement

local HEADLESS_PASS_ID = 14067340
local HERO_HEIGHT = 130
local GRID_CARD_WIDTH = 150

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

-- Full-width hero offer: image left, tag/title/lines in the middle, price +
-- button right. Page-local composition (like StatCard): Pane + Styles tokens only.
local function HeroCard(props)
	local px = usePx()
	return c(Pane, {
		ClassName = "Frame",
		CornerRadius = Styles.CORNER_CARD,
		Stroke = { Color = (props.Fill or Styles.GREEN):Lerp(Color3.new(0, 0, 0), 0.15), Thickness = 3 },
		ListLayout = {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.02, 0),
		},
		Native = {
			BackgroundColor3 = props.Fill or Styles.GREEN,
			BackgroundTransparency = 0,
			LayoutOrder = props.LayoutOrder,
			Size = UDim2.new(0.98, 0, 0, px(HERO_HEIGHT)),
		},
	}, {
		Image = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = props.Image,
			LayoutOrder = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(px(90), px(90)),
		}),

		Info = c(Pane, {
			ClassName = "Frame",
			ListLayout = {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0.015, 0),
			},
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.fromScale(0.44, 0.9),
			},
		}, {
			Tag = if props.Tag ~= nil
				then c(Pane, {
					ClassName = "TextLabel",
					CornerRadius = 1,
					MaxTextSize = 14,
					Padding = {
						PaddingTop = UDim.new(0, 2),
						PaddingBottom = UDim.new(0, 2),
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
					},
					Native = {
						AutomaticSize = Enum.AutomaticSize.X,
						BackgroundColor3 = props.TagColor or Styles.GREEN_BADGE,
						BackgroundTransparency = 0,
						FontFace = Styles.FONT_FREDOKA,
						LayoutOrder = 1,
						Size = UDim2.fromScale(0, 0.18),
						Text = props.Tag,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
					},
				})
				else nil,
			Title = c(Pane, {
				ClassName = "TextLabel",
				MaxTextSize = 24,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					LayoutOrder = 2,
					Size = UDim2.fromScale(1, 0.3),
					Text = props.Title,
					TextColor3 = props.TitleColor or Color3.new(1, 1, 1),
					TextScaled = true,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			}),
			Lines = c(Pane, {
				ClassName = "TextLabel",
				MaxTextSize = 14,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					LayoutOrder = 3,
					Size = UDim2.fromScale(1, 0.52),
					Text = table.concat(props.Lines, "\n"),
					TextColor3 = props.LinesColor or Color3.new(1, 1, 1),
					TextScaled = true,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				},
			}),
		}),

		Buy = c(Pane, {
			ClassName = "Frame",
			ListLayout = {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0.04, 0),
			},
			Native = {
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				Size = UDim2.fromScale(0.32, 0.86),
			},
		}, {
			Price = c(Pane, {
				ClassName = "TextLabel",
				MaxTextSize = 20,
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0.3),
					Text = props.Price or "...",
					TextColor3 = props.PriceColor or Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Center,
				},
			}),
			Button = c(PromptButton, {
				Text = props.ButtonText,
				Color = props.ButtonColor or Styles.GREEN,
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0.5),
				OnClick = props.OnClick,
			}),
		}),
	})
end

---> public
return function()
	local px = usePx()
	local localPlayer = Players.LocalPlayer
	local headlessPrice, setHeadlessPrice = React.useState("\u{e002} 250")
	local headlessOwned, setHeadlessOwned = React.useState(false)
	local pumpkinPrice, setPumpkinPrice = React.useState(nil)
	local pumpkinOwned, setPumpkinOwned = React.useState(false)
	local bobaPartyPrice, setBobaPartyPrice = React.useState("\u{e002} 249")
	-- SEASON-PASS: live prices for the two new products (nil while unfetched),
	-- plus the one-time bundle flag that hides the starter hero once claimed.
	local seasonPrice, setSeasonPrice = React.useState(nil)
	local starterPrice, setStarterPrice = React.useState(nil)
	local starterClaimed, setStarterClaimed = React.useState(false)
	local randomPolicyRestricted, setRandomPolicyRestricted = React.useState(false)

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

			-- Check Pumpkin Launcher pass info & ownership
			local pumpkinPassId = ProductIds.PumpkinLauncherPass
			if pumpkinPassId ~= nil then
				local okPumpkin, pumpkinInfo = pcall(function()
					return MarketplaceService:GetProductInfo(pumpkinPassId, Enum.InfoType.GamePass)
				end)
				if mounted and okPumpkin and typeof(pumpkinInfo) == "table" and pumpkinInfo.PriceInRobux ~= nil then
					setPumpkinPrice(`\u{e002} {pumpkinInfo.PriceInRobux}`)
				end

				if localPlayer then
					local ownOk, owns = pcall(function()
						return GamepassUtil:PlayerOwnsPassAsync(localPlayer, pumpkinPassId)
					end)
					if mounted and ownOk and owns then
						setPumpkinOwned(true)
					end
				end
			end

			-- Fetch Boba Party price
			local partyPrices = EventProducts.fetchPrices()
			if mounted and partyPrices["BobaParty"] then
				setBobaPartyPrice(`\u{e002} {partyPrices["BobaParty"]}`)
			end

			-- SEASON-PASS: live prices only (DEC-026), never hardcoded.
			local function fetchProductPrice(id: number?)
				if id == nil then
					return nil
				end
				local priceOk, priceInfo = pcall(function()
					return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product)
				end)
				if priceOk and typeof(priceInfo) == "table" and priceInfo.PriceInRobux ~= nil then
					return `\u{e002} {priceInfo.PriceInRobux}`
				end
				return nil
			end
			if mounted then
				setSeasonPrice(fetchProductPrice(ProductIds.SeasonPass))
				setStarterPrice(fetchProductPrice(ProductIds.StarterBundle))
			end

			-- SEASON-PASS: hide the Starter Bundle hero once claimed.
			local dataOk, dataController = pcall(function()
				return Knit.GetController("DataController")
			end)
			if mounted and dataOk and dataController then
				dataController
					:GetDataAsync()
					:andThen(function(data)
						if mounted and typeof(data) == "table" and data.StarterBundleClaimed == true then
							setStarterClaimed(true)
						end
					end)
					:catch(function() end)
			end

			-- PolicyService: check if paid random items (capsules) are restricted
			local capOk, capsuleService = pcall(function()
				return Knit.GetService("CapsuleService")
			end)
			if mounted and capOk and capsuleService then
				capsuleService
					:GetPaidRandomPolicy()
					:andThen(function(okPolicy, restricted)
						if mounted and okPolicy and restricted == true then
							setRandomPolicyRestricted(true)
						end
					end)
					:catch(function() end)
			end
		end)

		local conn = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
			if wasPurchased and player == localPlayer and mounted then
				if passId == HEADLESS_PASS_ID then
					setHeadlessOwned(true)
				elseif ProductIds.PumpkinLauncherPass ~= nil and passId == ProductIds.PumpkinLauncherPass then
					setPumpkinOwned(true)
				end
			end
		end)

		return function()
			mounted = false
			conn:Disconnect()
		end
	end, {})

	local function promptPetPurchase(capsuleName: string, priceStr: string)
		if randomPolicyRestricted then
			return
		end
		local DialogController = Knit.GetController("DialogController")
		local prompt = DialogController.new("ButtonPrompt", {
			Title = `Buy {capsuleName}`,
			Text = `Buy {capsuleName} for {priceStr}?\nHatch chances are displayed in the Pets tab.`,
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
		if randomPolicyRestricted then
			return
		end
		local DialogController = Knit.GetController("DialogController")
		local prompt = DialogController.new("ButtonPrompt", {
			Title = `Buy {packName}`,
			Text = `Buy {packName} for {priceStr}?\nRarity chances are displayed in the Nametags tab.`,
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

	local function promptStarterPurchase()
		local id = ProductIds.StarterBundle
		if id ~= nil and localPlayer then
			MarketplaceService:PromptProductPurchase(localPlayer, id)
		end
	end

	local function openSeasonTab()
		pcall(function()
			Knit.GetController("DialogController").OpenShopRequested:Fire("Season")
		end)
	end

	-- The collectible grid under the heroes: the same ShopCards as before,
	-- but demoted to "More to Collect" so the money offers lead the page.
	-- Paid random items (capsules) are hidden when restricted by Roblox PolicyService.
	local gridCards: { FeaturedCardData } = {
		{
			Key = "PumpkinLauncher",
			Name = "Pumpkin Launcher",
			Owned = pumpkinOwned,
			Price = pumpkinPrice or (if ProductIds.PumpkinLauncherPass == nil then "Coming Soon" else nil),
			Image = "rbxassetid://16728123607",
			TopBanner = {
				Color = if pumpkinOwned then Styles.GREEN_BADGE else Color3.fromRGB(240, 110, 25),
				Text = if pumpkinOwned then "Owned" else "Halloween",
				Size = UDim2.fromScale(1.05, 0.28),
			},
			LayoutOrder = 1,
			OnClick = function()
				if localPlayer and ProductIds.PumpkinLauncherPass ~= nil then
					MarketplaceService:PromptGamePassPurchase(localPlayer, ProductIds.PumpkinLauncherPass)
				end
			end,
		},
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
			LayoutOrder = 2,
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
			LayoutOrder = 3,
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
	}

	if not randomPolicyRestricted then
		table.insert(gridCards, {
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
			LayoutOrder = 4,
			OnClick = function()
				promptPetPurchase("Epic Pet Capsule", "1,200 Boba Bucks")
			end,
		})
		table.insert(gridCards, {
			Key = "RarePetCapsule",
			Name = "Rare Pet Capsule",
			Price = " 250",
			Image = "rbxassetid://7621095542",
			Tier = "Rare",
			LayoutOrder = 5,
			OnClick = function()
				promptPetPurchase("Rare Pet Capsule", "250 Boba Bucks")
			end,
		})
		table.insert(gridCards, {
			Key = "RegularPetCapsule",
			Name = "Regular Pet Capsule",
			Price = " 75",
			Image = "rbxassetid://6073658218",
			Tier = "Basic",
			LayoutOrder = 6,
			OnClick = function()
				promptPetPurchase("Regular Pet Capsule", "75 Boba Bucks")
			end,
		})
		table.insert(gridCards, {
			Key = "NametagCapsule10",
			Name = "10 Nametag Capsules",
			Price = " 1,350",
			Image = "rbxassetid://6073658218",
			TopBanner = {
				Color = Styles.GREEN_BADGE,
				Text = "Best Value",
				Size = UDim2.fromScale(1.05, 0.28),
			},
			LayoutOrder = 7,
			OnClick = function()
				promptNametagPurchase("10 Nametag Capsules", 10, "1,350 Boba Bucks")
			end,
		})
		table.insert(gridCards, {
			Key = "NametagCapsule1",
			Name = "Nametag Capsule",
			Price = " 150",
			Image = "rbxassetid://6073658218",
			LayoutOrder = 8,
			OnClick = function()
				promptNametagPurchase("Nametag Capsule", 1, "150 Boba Bucks")
			end,
		})
	end

	local gridChildren = {
		UIPadding = c("UIPadding", {
			PaddingTop = UDim.new(0.01, 0),
			PaddingBottom = UDim.new(0.02, 0),
			PaddingLeft = UDim.new(0.01, 0),
			PaddingRight = UDim.new(0.01, 0),
		}),
	}
	for _, card in ipairs(gridCards) do
		gridChildren[card.Key] = c(ShopCard, {
			Name = card.Name,
			Price = card.Price,
			Image = card.Image,
			ImageSize = UDim2.fromScale(1, 1),
			Tier = card.Tier,
			Owned = card.Owned,
			TopBanner = card.TopBanner,
			LayoutOrder = card.LayoutOrder,
			ShowPrice = true,
			Size = UDim2.fromOffset(px(GRID_CARD_WIDTH), px(GRID_CARD_WIDTH)),
			OnClick = card.OnClick,
		})
	end

	local starterAvailable = ProductIds.StarterBundle ~= nil and not starterClaimed
	local seasonAvailable = ProductIds.SeasonPass ~= nil

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

		Scroll = c("ScrollingFrame", {
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
		}, {
			UIListLayout = c("UIListLayout", {
				Padding = UDim.new(0.02, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			StarterHero = if starterAvailable
				then c(HeroCard, {
					LayoutOrder = 1,
					Fill = Styles.GREEN,
					Title = "Starter Bundle",
					Lines = { "• 300 Boba Bucks", "• 1 Regular Pet Capsule", "• 1 Nametag Capsule" },
					Image = "rbxassetid://6073658218",
					Tag = "One-Time Offer",
					TagColor = Styles.GOLD_MID,
					Price = starterPrice,
					ButtonText = "Buy",
					ButtonColor = Styles.GREEN_DEEP,
					OnClick = promptStarterPurchase,
				})
				else nil,

			SeasonHero = if seasonAvailable
				then c(HeroCard, {
					LayoutOrder = 2,
					Fill = Styles.GREEN_LIGHT,
					TitleColor = Styles.GREEN_DEEP,
					LinesColor = Styles.GREEN_DEEP,
					PriceColor = Styles.GREEN_DEEP,
					Title = "Season 1",
					Lines = {
						"• 30 tiers of rewards",
						"• 550 Boba Bucks + capsules + nametag",
						"• Free track for everyone",
					},
					Image = "rbxassetid://16728139086",
					Tag = "New Season",
					TagColor = Styles.ROSE_MID,
					Price = seasonPrice,
					ButtonText = "View Season",
					ButtonColor = Styles.GREEN,
					OnClick = openSeasonTab,
				})
				else nil,

			MoreTitle = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = 3,
				Size = UDim2.fromScale(0.96, 0.05),
				Text = "More to Collect",
				TextColor3 = Styles.GREEN,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Grid = c(Pane, {
				ClassName = "Frame",
				ListLayout = {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, px(14)),
					Wraps = true,
					HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
				},
				Native = {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					LayoutOrder = 4,
					Size = UDim2.fromScale(0.98, 0),
				},
			}, gridChildren),
		}),
	})
end

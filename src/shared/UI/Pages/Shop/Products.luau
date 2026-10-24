local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Knit = require(Packages.Knit)

---> config
local ProductIds = require(Shared.Configuration.ProductIds)
local UIFlags = require(Shared.Configuration.UIFlags)
local EventProducts = require(Shared.Utility.EventProducts)
local NicknamePrompt = require(Shared.UI.Utility.NicknamePrompt)

---> styles
local Styles = require(UI.Styles)

---> components
local ShopCategory = require(script.Parent.ShopCategory)

---> private
local c = React.createElement

---> Boba Bucks Robux packs (M3-STUBS). IDs live in ProductIds; nil = pack inert.
--- Price display always uses live Marketplace metadata (DEC-026), never hardcoded prices.
local BOBA_BUCKS_PACKS = {
	{ Key = "Pack50", Amount = 50 },
	{ Key = "Pack150", Amount = 150 },
	{ Key = "Pack500", Amount = 500 },
	{ Key = "Pack1000", Amount = 1000 },
	{ Key = "Pack5000", Amount = 5000 },
}

local function packLabel(amount: number): string
	return `{amount} Boba Bucks`
end

local function packProductId(key: string): number?
	return ProductIds.BobaBucks[key]
end

---> public
return function()
	-- Live Robux prices keyed by pack Key. Empty while the stub is nil or unfetched,
	-- in which case the row shows no price and its purchase path stays inert.
	local prices, setPrices = React.useState({})
	local nicknamePrice, setNicknamePrice = React.useState(nil)
	local cleanerPrice, setCleanerPrice = React.useState(nil)
	local stockerPrice, setStockerPrice = React.useState(nil)

	React.useEffect(function()
		local mounted = true
		task.spawn(function()
			local fetched = {}
			for _, pack in BOBA_BUCKS_PACKS do
				local id = packProductId(pack.Key)
				if id ~= nil then
					local ok, info = pcall(function()
						return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product)
					end)
					if ok and typeof(info) == "table" and info.PriceInRobux ~= nil then
						fetched[pack.Key] = tostring(info.PriceInRobux)
					end
				end
			end
			if mounted then
				setPrices(fetched)
			end

			local nickId = ProductIds.ChangeNickname
			if nickId ~= nil then
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfoAsync(nickId, Enum.InfoType.Product)
				end)
				if mounted and ok and typeof(info) == "table" and info.PriceInRobux ~= nil then
					setNicknamePrice(tostring(info.PriceInRobux))
				end
			end

			if ProductIds.BobaBuddy then
				local cleanerId = ProductIds.BobaBuddy.Cleaner
				if cleanerId ~= nil then
					local ok, info = pcall(function()
						return MarketplaceService:GetProductInfoAsync(cleanerId, Enum.InfoType.Product)
					end)
					if mounted and ok and typeof(info) == "table" and info.PriceInRobux ~= nil then
						setCleanerPrice(tostring(info.PriceInRobux))
					end
				end
				local stockerId = ProductIds.BobaBuddy.Stocker
				if stockerId ~= nil then
					local ok, info = pcall(function()
						return MarketplaceService:GetProductInfoAsync(stockerId, Enum.InfoType.Product)
					end)
					if mounted and ok and typeof(info) == "table" and info.PriceInRobux ~= nil then
						setStockerPrice(tostring(info.PriceInRobux))
					end
				end
			end
		end)
		return function()
			mounted = false
		end
	end, {})

	-- Boba Party / Rush Hour developer products (live prices; party hidden on cooldown).
	local eventPrices, setEventPrices = React.useState({})
	local _eventTick, setEventTick = React.useState(0)
	-- SEASON-PASS: live price for the Starter Bundle product and a flag that
	-- hides the row once the one-time bundle is claimed.
	local starterPrice, setStarterPrice = React.useState(nil)
	local starterClaimed, setStarterClaimed = React.useState(false)

	React.useEffect(function()
		local mounted = true
		task.spawn(function()
			local fetched = EventProducts.fetchPrices()
			if mounted then
				setEventPrices(fetched)
			end
		end)
		local function bump()
			setEventTick(function(n)
				return n + 1
			end)
		end
		local conns = {
			workspace:GetAttributeChangedSignal("BobaParty"):Connect(bump),
			workspace:GetAttributeChangedSignal("BobaPartyCooldownEndsAt"):Connect(bump),
		}
		-- The cooldown ends by clock, not by attribute change.
		task.spawn(function()
			while mounted do
				task.wait(5)
				if mounted then
					bump()
				end
			end
		end)
		return function()
			mounted = false
			for _, conn in conns do
				conn:Disconnect()
			end
		end
	end, {})

	local eventItems = {}
	for _, product in EventProducts.Products do
		if EventProducts.available(product) then
			table.insert(eventItems, {
				Label = `{product.Name} · {product.Blurb}`,
				Price = eventPrices[product.Key],
				Product = product,
			})
		end
	end

	-- SEASON-PASS: Starter Bundle — one-time Robux product, hidden once
	-- claimed. Live price only (DEC-026).
	React.useEffect(function()
		local mounted = true
		task.spawn(function()
			local id = ProductIds.StarterBundle
			if id ~= nil then
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product)
				end)
				if mounted and ok and typeof(info) == "table" and info.PriceInRobux ~= nil then
					setStarterPrice(`\u{e002} {info.PriceInRobux}`)
				end
			end
			local okC, dataController = pcall(function()
				return Knit.GetController("DataController")
			end)
			if mounted and okC and dataController then
				dataController
					:GetDataAsync()
					:andThen(function(data)
						if mounted and typeof(data) == "table" and data.StarterBundleClaimed == true then
							setStarterClaimed(true)
						end
					end)
					:catch(function() end)
			end
		end)
		return function()
			mounted = false
		end
	end, {})

	local function onPurchaseEvent(item)
		if item.Product ~= nil then
			EventProducts.prompt(item.Product)
		end
	end

	local function onPurchaseStarter(_item)
		local id = ProductIds.StarterBundle
		if id ~= nil then
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
		end
	end

	local starterItems = {
		{ Label = "Starter Bundle · 300 BB + 2 capsules", Price = starterPrice },
	}

	local bucksItems = {}
	for i, pack in BOBA_BUCKS_PACKS do
		bucksItems[i] = {
			Label = packLabel(pack.Amount),
			Price = prices[pack.Key],
		}
	end

	local function onPurchaseBucks(item)
		for _, pack in BOBA_BUCKS_PACKS do
			if packLabel(pack.Amount) == item.Label then
				local id = packProductId(pack.Key)
				if id ~= nil then
					MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
				end
				return
			end
		end
	end

	local function onPurchaseBuddy(item)
		if not ProductIds.BobaBuddy then
			return
		end
		local isCleaner = string.find(item.Label, "Cleaner") ~= nil
		local id = if isCleaner then ProductIds.BobaBuddy.Cleaner else ProductIds.BobaBuddy.Stocker
		if id ~= nil then
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
		end
	end

	local buddyItems = {
		{
			Label = "Boba Buddy: Cleaner",
			Price = if cleanerPrice then cleanerPrice else "49",
		},
		{
			Label = "Boba Buddy: Stocker",
			Price = if stockerPrice then stockerPrice else "99",
		},
	}

	local function onPurchaseNickname(_item)
		NicknamePrompt.Open()
	end

	local nicknameItems = {
		{ Label = "Change Nickname", Price = nicknamePrice },
	}

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
			Text = "Products",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		Categories = c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.112),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarThickness = 5,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1, 0.888),
		}, {
			UIListLayout = c("UIListLayout", {
				Padding = UDim.new(0.02, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			StarterBundle = if ProductIds.StarterBundle ~= nil and not starterClaimed
				then c(ShopCategory, {
					Title = "Starter Bundle",
					Items = starterItems,
					LayoutOrder = -1,
					OnPurchase = onPurchaseStarter,
				})
				else nil,

			BobaBucks = c(ShopCategory, {
				Title = "Boba Bucks",
				Items = bucksItems,
				LayoutOrder = 0,
				OnPurchase = onPurchaseBucks,
			}),

			BobaBuddy = c(ShopCategory, {
				Title = "Boba Buddy (3 Min)",
				Items = buddyItems,
				LayoutOrder = 1,
				OnPurchase = onPurchaseBuddy,
			}),

			Events = if #eventItems > 0
				then c(ShopCategory, {
					Title = "Cafe Events",
					Items = eventItems,
					LayoutOrder = 2,
					OnPurchase = onPurchaseEvent,
				})
				else nil,

			Roleplay = if ProductIds.ChangeNickname ~= nil
				then c(ShopCategory, {
					Title = "Roleplay",
					Items = nicknameItems,
					LayoutOrder = 3,
					OnPurchase = onPurchaseNickname,
				})
				else nil,

			-- Hidden while Points have no use (UIFlags.SHOW_POINTS).
			Points = if UIFlags.SHOW_POINTS
				then c(ShopCategory, {
					Title = "Points",
					Items = {
						{ Label = "100 Points", Price = "500" },
						{ Label = "500 Points", Price = "2,000" },
						{ Label = "1,500 Points", Price = "5,000" },
						{ Label = "5,000 Points", Price = "15,000" },
						{ Label = "15,000 Points", Price = "40,000" },
					},
					LayoutOrder = 1,
				})
				else nil,

			Spacer = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 9999,
				Size = UDim2.new(1, 0, 0, 40),
				Visible = true,
			}),
		}),
	})
end

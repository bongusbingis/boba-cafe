local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> config
local ProductIds = require(Shared.Configuration.ProductIds)

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
		end)
		return function()
			mounted = false
		end
	end, {})

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
			Text = "Currency",
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

			BobaBucks = c(ShopCategory, {
				Title = "Boba Bucks",
				Items = bucksItems,
				LayoutOrder = 0,
				OnPurchase = onPurchaseBucks,
			}),

			Points = c(ShopCategory, {
				Title = "Points",
				Items = {
					{ Label = "100 Points", Price = "500" },
					{ Label = "500 Points", Price = "2,000" },
					{ Label = "1,500 Points", Price = "5,000" },
					{ Label = "5,000 Points", Price = "15,000" },
					{ Label = "15,000 Points", Price = "40,000" },
				},
				LayoutOrder = 1,
			}),

			Spacer = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = math.huge,
				Size = UDim2.fromScale(1, 0.05),
			}),
		}),
	})
end

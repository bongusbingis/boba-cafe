local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> configuration
local PassCatalog = require(Shared.Configuration.PassCatalog)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local ProductIds = require(Shared.Configuration.ProductIds)

---> styles
local Styles = require(UI.Styles)

---> components
local ShopCard = require(UI.Components.Buttons.ShopCard)

---> private
local c = React.createElement

type PassCardData = {
	PassId: number,
	Name: string,
	Image: string,
	Price: string?,
	OffSale: boolean?,
	IsOwned: boolean?,
}

---> public
return function()
	local passStates, setPassStates =
		React.useState({} :: { [number]: { Price: string?, OffSale: boolean?, Owned: boolean? } })

	React.useEffect(function()
		local mounted = true
		local localPlayer = Players.LocalPlayer

		task.spawn(function()
			local updates: { [number]: { Price: string?, OffSale: boolean?, Owned: boolean? } } = {}

			for passId, catalogEntry in PassCatalog do
				if not catalogEntry.Listed then
					continue
				end

				local isOwned = false
				if localPlayer then
					local ok, owns = pcall(function()
						return GamepassUtil:PlayerOwnsPassAsync(localPlayer, passId)
					end)
					if ok and owns then
						isOwned = true
					end
				end

				local priceText: string? = nil
				local offSale = false
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
				end)

				if ok and typeof(info) == "table" then
					if info.IsForSale == false then
						offSale = true
					elseif info.PriceInRobux ~= nil then
						priceText = `\u{e002} {info.PriceInRobux}`
					end
				else
					offSale = true
				end

				updates[passId] = {
					Price = priceText,
					OffSale = offSale,
					Owned = isOwned,
				}
			end

			if mounted then
				setPassStates(updates)
			end
		end)

		local conn = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
			if wasPurchased and player == localPlayer and mounted then
				setPassStates(function(prev)
					local copy = table.clone(prev)
					local entry = copy[passId] or {}
					copy[passId] = {
						Price = entry.Price,
						OffSale = entry.OffSale,
						Owned = true,
					}
					return copy
				end)
			end
		end)

		return function()
			mounted = false
			conn:Disconnect()
		end
	end, {})

	-- Build sorted card list
	local passList: { PassCardData } = {}
	for passId, catalogEntry in PassCatalog do
		if not catalogEntry.Listed then
			continue
		end
		local def = PassCatalog[passId]
		local state = passStates[passId]
		local image = if def and def.Icon and def.Icon ~= "" then def.Icon else "rbxassetid://16728123607"
		local name = if def and def.Name then def.Name else catalogEntry.Name

		table.insert(passList, {
			PassId = passId,
			Name = name,
			Image = image,
			Price = if state then state.Price else nil,
			OffSale = if state then state.OffSale else false,
			IsOwned = if state then state.Owned else false,
		})
	end

	-- Sorting rules:
	-- 1. Unowned and on-sale passes appear first
	-- 2. Off-sale unowned passes
	-- 3. Owned passes appear at the end of the list (high layout order)
	table.sort(passList, function(a, b)
		if a.IsOwned ~= b.IsOwned then
			return not a.IsOwned
		end
		local aOffSale = a.OffSale and not (a.PassId == 2055509330 or a.Name == "Pumpkin Launcher")
		local bOffSale = b.OffSale and not (b.PassId == 2055509330 or b.Name == "Pumpkin Launcher")
		if aOffSale ~= bOffSale then
			return not aOffSale
		end
		return a.Name < b.Name
	end)

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

	for index, pass in ipairs(passList) do
		local isPumpkin = pass.Name == "Pumpkin Launcher"
			or (ProductIds.PumpkinLauncherPass ~= nil and pass.PassId == ProductIds.PumpkinLauncherPass)
		-- Display pricing and ownership in the ribbon banner so it never overlaps the pass name
		local topBanner = nil
		if pass.IsOwned then
			topBanner = {
				Color = Styles.GREEN_BADGE,
				Text = "Owned",
				Size = UDim2.fromScale(1.05, 0.28),
			}
		elseif isPumpkin then
			topBanner = {
				Color = Color3.fromRGB(240, 110, 25),
				Text = if pass.Price then pass.Price else "Halloween",
				Size = UDim2.fromScale(1.05, 0.28),
			}
		elseif pass.OffSale then
			topBanner = {
				Color = Styles.GRAY,
				Text = "Off Sale",
				Size = UDim2.fromScale(1.05, 0.28),
			}
		elseif pass.Price then
			topBanner = {
				Color = Styles.GREEN,
				Text = pass.Price,
				Size = UDim2.fromScale(1.05, 0.28),
			}
		end

		gridChildren[`pass_{pass.PassId}`] = c(ShopCard, {
			Name = pass.Name,
			Image = pass.Image,
			ImageSize = UDim2.fromScale(1, 1),
			OffSale = pass.OffSale and not isPumpkin,
			Owned = pass.IsOwned,
			TopBanner = topBanner,
			LayoutOrder = index,
			OnClick = function()
				local localPlayer = Players.LocalPlayer
				if localPlayer and pass.PassId > 0 then
					MarketplaceService:PromptGamePassPurchase(localPlayer, pass.PassId)
				end
			end,
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
			Text = "Game Passes",
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

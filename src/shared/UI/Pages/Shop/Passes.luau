local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> config
local Gamepasses = require(Shared.Configuration.Gamepasses)
local GamepassUtil = require(Shared.Utility.GamepassUtil)

---> components
local ShopCard = require(UI.Components.Buttons.ShopCard)

---> private
local c = React.createElement

export type Pass = {
	PassId: number,
	Name: string,
	Price: string,
	Image: string,
	Owned: boolean,
}

-- Prices and icons come from Roblox rather than the config, so they stay correct when
-- they are changed on the pass itself. Falls back to the configured icon on failure.
local function fetchPasses(): { Pass }
	local player = Players.LocalPlayer
	local passes: { Pass } = {}

	for passId, definition in Gamepasses do
		local price = "—"
		local image = definition.Icon

		-- GetProductInfo is flagged deprecated by the Luau LSP, but it remains the only
		-- in-engine way to read a game pass price. Wrapped in pcall so a throttled or
		-- failed lookup degrades to the placeholder price instead of breaking the page.
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
		end)

		if ok and info then
			if info.PriceInRobux then
				price = tostring(info.PriceInRobux)
			end
			if info.IconImageAssetId and info.IconImageAssetId ~= 0 then
				image = "rbxassetid://" .. info.IconImageAssetId
			end
		end

		table.insert(passes, {
			PassId = passId,
			Name = definition.Name,
			Price = price,
			Image = image,
			Owned = GamepassUtil:PlayerOwnsPassAsync(player, passId),
		})
	end

	-- Owned passes sink to the bottom; the rest stay alphabetical for a stable grid.
	table.sort(passes, function(a, b)
		if a.Owned ~= b.Owned then
			return not a.Owned
		end
		return a.Name < b.Name
	end)

	return passes
end

---> public
return function()
	-- nil = loading, table = loaded
	local passes, setPasses = React.useState(nil)

	React.useEffect(function()
		local cancelled = false

		task.spawn(function()
			local result = fetchPasses()
			if not cancelled then
				setPasses(result)
			end
		end)

		return function()
			cancelled = true
		end
	end, {})

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

	if passes == nil then
		gridChildren["Loading"] = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.fromScale(1, 0.2),
			Text = "Loading passes...",
			TextColor3 = Styles.GRAY,
			TextScaled = true,
		})
	else
		for index, pass in ipairs(passes) do
			gridChildren[pass.Name] = c(ShopCard, {
				Name = pass.Name,
				Price = pass.Price,
				Image = pass.Image,
				ImageSize = UDim2.fromScale(1, 1),
				-- Owned passes reuse the off-sale styling so they read as unavailable.
				OffSale = pass.Owned,
				LayoutOrder = index,
				OnClick = if pass.Owned
					then nil
					else function()
						MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.PassId)
					end,
			})
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

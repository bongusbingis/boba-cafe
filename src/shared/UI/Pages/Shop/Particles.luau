local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Knit = require(Packages.Knit)

---> styles
local Styles = require(UI.Styles)

---> components
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local ShopCard = require(UI.Components.Buttons.ShopCard)
local BobaBucksShortfall = require(UI.Utility.BobaBucksShortfall)

---> private
local c = React.createElement
local particles = InventoryItemDefinitions.Particles

---> public
return function()
	local localPlayer = Players.LocalPlayer
	local ownedParticles, setOwnedParticles = React.useState({} :: { [string]: boolean })

	React.useEffect(function()
		local mounted = true
		task.spawn(function()
			if localPlayer then
				local Inventory = require(Shared.Inventory)
				local ok, inv = pcall(function()
					return Inventory:GetPlayerInventoryAsync(localPlayer, "Particles"):await()
				end)
				if mounted and ok and inv and inv.Inventory then
					local owned = {}
					for _, item in inv.Inventory do
						owned[item.Name] = true
					end
					setOwnedParticles(owned)
				end
			end
		end)
		return function()
			mounted = false
		end
	end, {})

	local function promptPurchase(name: string, priceStr: string)
		local DialogController = Knit.GetController("DialogController")
		local prompt = DialogController.new("ButtonPrompt", {
			Title = `Buy {name}`,
			Text = `Buy {name} for {priceStr} Boba Bucks?`,
			Buttons = {
				{ Text = "Buy", Color = Styles.GREEN },
				{ Text = "Cancel", Color = Styles.RED },
			},
		})
		prompt:Fire():andThen(function(choice)
			if choice ~= "Buy" then
				return
			end
			Knit.GetService("CapsuleService"):PurchaseParticle(name):andThen(function(ok, reason)
				if not ok and reason == "InsufficientFunds" then
					BobaBucksShortfall.Prompt({ Price = priceStr, What = name })
					return
				end
				if ok then
					setOwnedParticles(function(prev)
						local copy = table.clone(prev)
						copy[name] = true
						return copy
					end)
				end
				local result = DialogController.new("ButtonPrompt", {
					Title = if ok then "Purchase Complete" else "Purchase Unavailable",
					Text = if ok
						then `{name} was added to your inventory! Go to Inventory > Particles to equip it.`
						elseif reason == "InventoryFull" then "Your inventory is full. Make some room and try again."
						else "The purchase could not be completed. Please try again.",
					Buttons = { { Text = "Close", Color = Styles.GREEN } },
				})
				result:Fire()
			end)
		end)
	end

	local onSaleCount = 0
	for _, entry in pairs(particles) do
		if entry.CanBeSold ~= false and not entry.OffSale then
			onSaleCount += 1
		end
	end

	local onSaleIndex, offSaleIndex = 0, onSaleCount
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

	for name, entry in pairs(particles) do
		local isOffSale = entry.OffSale or entry.CanBeSold == false
		local isOwned = ownedParticles[name] == true
		local layoutOrder
		if isOffSale then
			offSaleIndex += 1
			layoutOrder = offSaleIndex
		else
			onSaleIndex += 1
			layoutOrder = onSaleIndex
		end

		local topBanner = nil
		if isOwned then
			topBanner = {
				Color = Styles.GREEN_BADGE,
				Text = "Owned",
				Size = UDim2.fromScale(1.05, 0.28),
			}
		end

		gridChildren[name] = c(ShopCard, {
			Name = name,
			Price = entry.Price,
			Tier = entry.Tier,
			Image = entry.Image,
			ImageSize = UDim2.fromScale(0.675, 0.675),
			OffSale = isOffSale,
			TopBanner = topBanner,
			LayoutOrder = layoutOrder,
			OnClick = function()
				if isOwned then
					local DialogController = Knit.GetController("DialogController")
					local ownedNotice = DialogController.new("ButtonPrompt", {
						Title = "Already Owned",
						Text = `You already own {name}! Go to Inventory > Particles to equip it.`,
						Buttons = { { Text = "Close", Color = Styles.GREEN } },
					})
					ownedNotice:Fire()
					return
				end
				promptPurchase(name, entry.Price or "150")
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
			Text = "Particles",
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

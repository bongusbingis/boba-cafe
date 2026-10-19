local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> components
local CapsuleTierGroup = require(UI.Components.CapsuleTierGroup)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local NametagCard = require(UI.Components.Buttons.NametagCard)
local Pane = require(UI.Components.Pane)
local usePx = require(UI.Hooks.usePx)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement
local nametagColors = InventoryItemDefinitions.Nametags
local CapsuleService = require(Packages.Knit).GetService("CapsuleService")

---> constants
local TIER_COLORS = InventoryItemDefinitions.Tiers
local TIER_ORDER = { "Basic", "Uncommon", "Rare", "Epic", "Legendary", "Special" }
local NAMETAG_CELL_SIZE = 90

---> public
return function()
	local px = usePx()
	local policyState, setPolicyState = React.useState("loading")
	React.useEffect(function()
		local alive = true
		CapsuleService:GetPaidRandomPolicy()
			:andThen(function(ok, restricted)
				if alive then
					setPolicyState(
						if ok and restricted == false then "allowed" elseif ok then "restricted" else "unavailable"
					)
				end
			end)
			:catch(function()
				if alive then
					setPolicyState("unavailable")
				end
			end)
		return function()
			alive = false
		end
	end, {})
	if policyState == "restricted" then
		return c(require(script.Parent.DirectCosmeticsPurchase))
	end

	local totalWeight = 0
	local tierCounts = {}
	for _, entry in pairs(nametagColors) do
		local tier = TIER_COLORS[entry.Tier]
		if tier and tier.Weight > 0 then
			totalWeight += tier.Weight
			tierCounts[entry.Tier] = (tierCounts[entry.Tier] or 0) + 1
		end
	end

	local heroCards = {}
	for i, tierName in ipairs(TIER_ORDER) do
		local items = {}
		local onSaleIndex = 0
		local offSaleIndex = 0

		for name, entry in pairs(nametagColors) do
			if entry.Tier ~= tierName then
				continue
			end

			local layoutOrder
			if entry.OffSale then
				offSaleIndex += 1
				layoutOrder = offSaleIndex
			else
				onSaleIndex += 1
				layoutOrder = onSaleIndex
			end

			items[name] = c(NametagCard, {
				Name = `{name}\n{string.format(
					"%.2f%%",
					TIER_COLORS[tierName].Weight / totalWeight / tierCounts[tierName] * 100
				)}`,
				Price = entry.Price,
				Tier = entry.Tier,
				TierColor = TIER_COLORS[tierName].Color,
				Color = entry.Color,
				Animation = entry.Animation,
				OffSale = entry.OffSale,
				LayoutOrder = layoutOrder,
				Size = UDim2.fromOffset(px(NAMETAG_CELL_SIZE), px(NAMETAG_CELL_SIZE)),
			})
		end

		if onSaleIndex + offSaleIndex > 0 then
			heroCards[tierName] = c(CapsuleTierGroup, {
				Tier = tierName,
				LayoutOrder = i,
				Items = items,
			})
		end
	end

	table.insert(
		heroCards,
		c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0.25),
			LayoutOrder = math.huge,
		})
	)

	local capsules = {}

	for k, capsule in ipairs(nametagColors.Capsules) do
		local isBestValue = k == 3
		table.insert(
			capsules,
			c(require(UI.Components.Buttons.ShopCard), {
				Name = capsule.Name,
				Price = capsule.Price,
				Image = capsule.Image,
				ImageSize = UDim2.fromScale(1, 1),
				Size = isBestValue and UDim2.fromScale(1, 1) or UDim2.fromScale(0.875, 0.875),
				TopBanner = isBestValue and {
					Color = Styles.GREEN_BADGE,
					Text = "Best Value",
					Size = UDim2.fromScale(1, 0.2),
				} or nil,
				OnClick = policyState == "allowed"
						and function()
							local Controller = require(Packages.Knit).GetController("DialogController")
							local prompt = Controller.new("ButtonPrompt", {
								Title = "Buy Nametag Capsules",
								Text = `Buy {capsule.Name} for {capsule.Price} Boba Bucks?`,
								Buttons = {
									{ Text = "Buy", Color = Styles.GREEN },
									{ Text = "Cancel", Color = Styles.RED },
								},
							})
							prompt:Fire():andThen(function(choice)
								if choice ~= "Buy" then
									return
								end
								local amount = if k == 1 then 1 elseif k == 2 then 10 else 50
								CapsuleService:PurchaseNametagCapsules(amount):andThen(function(ok, reason)
									local result = Controller.new("ButtonPrompt", {
										Title = if ok then "Purchase Complete" else "Purchase Unavailable",
										Text = if ok
											then "Your capsules were added to your inventory."
											elseif
												reason == "RefundPending"
											then "Your purchase failed and the refund could not be issued automatically. Please contact support."
											else "The purchase could not be completed. Please try again.",
										Buttons = { { Text = "Close", Color = Styles.GREEN } },
									})
									result:Fire()
								end)
							end)
						end
					or nil,
			})
		)
	end

	return c("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromScale(0.9, 3),
	}, {
		Title = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.470149, 0),
			Size = UDim2.fromScale(0.94, 0.09),
			Text = "Nametag Cosmetics",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		Hint = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.5, 0.095),
			Size = UDim2.fromScale(0.94, 0.085),
			Text = "Open capsules to purchase cosmetics. Each capsule contains a random item!",
			TextColor3 = Styles.GRAY,
			TextScaled = true,
		}),

		CapsulePurchaseRow = policyState == "allowed" and c(Pane, {
			ClassName = "Frame",
			Native = {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(0.8, 0.25),
				Position = UDim2.fromScale(0.475, 0.2),
				AnchorPoint = Vector2.new(0.5, 0),
			},
			ListLayout = {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
				Padding = UDim.new(0, 20),
			},
		}, capsules) or nil,

		PolicyNotice = policyState ~= "allowed" and c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.04, 0.2),
			Size = UDim2.fromScale(0.92, 0.12),
			Text = if policyState == "restricted"
				then "Random capsule purchases are unavailable for this account."
				elseif
					policyState == "unavailable"
				then "Purchase availability could not be checked. Please try again later."
				else "Checking purchase availability...",
			TextColor3 = Styles.GRAY,
			TextScaled = true,
		}) or nil,

		Grid = c(Pane, {
			ClassName = "Frame",
			ListLayout = {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 20),
			},
			Native = {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0, 0.475),
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
			},
		}, heroCards),
	})
end

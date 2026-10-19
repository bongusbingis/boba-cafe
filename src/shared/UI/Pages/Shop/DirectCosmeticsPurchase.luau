local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local NametagCard = require(UI.Components.Buttons.NametagCard)

---> private
local c = React.createElement
local nametagColors = InventoryItemDefinitions.Nametags

---> tier colors
local TIER_COLORS = InventoryItemDefinitions.Tiers

---> public
return function()
	local restricted, setRestricted = React.useState(false)
	React.useEffect(function()
		local alive = true
		Knit.GetService("CapsuleService")
			:GetPaidRandomPolicy()
			:andThen(function(ok, isRestricted)
				if alive then
					setRestricted(ok and isRestricted == true)
				end
			end)
			:catch(function()
				if alive then
					setRestricted(false)
				end
			end)
		return function()
			alive = false
		end
	end, {})

	local onSaleCount = 0
	for _, entry in pairs(nametagColors) do
		if not entry.OffSale then
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

	for name, entry in pairs(nametagColors) do
		local layoutOrder
		if entry.OffSale then
			offSaleIndex += 1
			layoutOrder = offSaleIndex
		else
			onSaleIndex += 1
			layoutOrder = onSaleIndex
		end

		gridChildren[name] = c(NametagCard, {
			Name = name,
			Price = entry.Price,
			Tier = entry.Tier,
			TierColor = TIER_COLORS[entry.Tier] or TIER_COLORS.Basic,
			Color = entry.Color,
			Animation = entry.Animation,
			OffSale = entry.OffSale,
			LayoutOrder = layoutOrder,
			OnClick = restricted
					and function()
						local Controller = Knit.GetController("DialogController")
						local prompt = Controller.new("ButtonPrompt", {
							Title = "Buy Nametag",
							Text = `Buy |{name}| for {entry.Price} Boba Bucks?`,
							Buttons = {
								{ Text = "Buy", Color = Styles.GREEN },
								{ Text = "Cancel", Color = Styles.RED },
							},
						})
						prompt:Fire():andThen(function(choice)
							if choice ~= "Buy" then
								return
							end
							Knit.GetService("CapsuleService")
								:PurchaseDeterministicNametag(name)
								:andThen(function(ok, reason)
									local result = Controller.new("ButtonPrompt", {
										Title = if ok then "Purchase Complete" else "Purchase Unavailable",
										Text = if ok
											then `|{name}| was added to your inventory.`
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
			Text = "Nametag Colors",
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

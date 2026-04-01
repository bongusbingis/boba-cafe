local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)

---> components
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)
local NametagCard = require(UI.Components.Buttons.NametagCard)
local Pane = require(UI.Components.Pane)

---> styles
local Styles = require(UI.Styles)
local GREEN = Styles.GREEN_MID
local GREEN_DEEP = Styles.GREEN_DEEP

---> private
local c = React.createElement
local nametagColors = InventoryItemDefinitions.Nametags

---> tier colors
local TIER_COLORS = InventoryItemDefinitions.Tiers

local function HeroCard(props)
	return c(Pane, {
		ClassName = "ImageButton",
		CornerRadius = UDim.new(0.06, 0),
		Stroke = { Color = GREEN, Thickness = styles.strokeThickness },
		Native = {
			AutoButtonColor = false,
			Size = UDim2.fromScale(1, 1),
		},
	}, {
		-- Product image, left half
		Image = c("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Image = props.Item.Image,
			Position = UDim2.fromScale(-0.05, 0.5),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.43, 0.82),
		}),

		-- Info panel, right half
		Info = c("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.975, 0.5),
			Size = UDim2.fromScale(0.65, 0.88),
		}, {
			Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0.06, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			Name = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0.22),
				Text = props.Item.Name,
				TextColor3 = GREEN,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Desc = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0.29),
				Text = props.Item.Description,
				TextColor3 = GREEN_DEEP,
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			PriceRow = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 3,
				Size = UDim2.fromScale(0.3, 0.2),
			}, {
				Pill = c(Pane, {
					ClassName = "TextLabel",
					CornerRadius = UDim.new(1, 0),
					Native = {
						FontFace = Styles.FONT_FREDOKA,
						Size = UDim2.fromScale(0.78, 1),
						Text = props.Item.Price,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Center,
						BackgroundTransparency = 0,
						BackgroundColor3 = GREEN,
					},
				}),
			}),
		}),
	})
end

---> public
return function()
	local onSaleCount = 0
	for _, entry in ipairs(nametagColors) do
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

	for _, entry in ipairs(nametagColors) do
		local layoutOrder
		if entry.OffSale then
			offSaleIndex += 1
			layoutOrder = offSaleIndex
		else
			onSaleIndex += 1
			layoutOrder = onSaleIndex
		end

		gridChildren[entry.Name] = c(NametagCard, {
			Name = entry.Name,
			Price = entry.Price,
			Tier = entry.Tier,
			TierColor = TIER_COLORS[entry.Tier] or TIER_COLORS.Basic,
			Color = entry.Color,
			Animation = entry.Animation,
			OffSale = entry.OffSale,
			LayoutOrder = layoutOrder,
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

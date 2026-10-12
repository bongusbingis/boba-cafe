--[[
    Component: AdBoard/CelebrityBoard
    Description: Body panel for the Celebrity board — a perks list plus a row of
    subscription duration tiles.

    Different content from PassBoard, but the same abstraction: everything comes from
    AdBoardConfig.CELEBRITY and there is no per-board script. In V3 this lived as a
    hand-built ScreenGui under StarterGui.Ads with its own CelebrityHandler LocalScript,
    and the perk descriptions were stored as nested StringValues under each label.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> config
local AdBoardConfig = require(Shared.Configuration.AdBoardConfig)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement

local CONFIG = AdBoardConfig.CELEBRITY

---> public
return function(props: {
	OnPurchase: (productId: number?) -> (),
	OnPerkHover: ((perk: { Label: string, Description: string }?) -> ())?,
})
	local color = CONFIG.Color

	---> perks grid
	local perkChildren: { [string]: any } = {
		UIGridLayout = c("UIGridLayout", {
			CellPadding = UDim2.new(),
			CellSize = UDim2.fromScale(0.5, 0.2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, perk in CONFIG.Perks do
		perkChildren[perk.Label] = c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_DENKONE,
			LayoutOrder = index,
			Size = UDim2.fromScale(1, 0.2),
			Text = `• {perk.Label}`,
			TextColor3 = color,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			-- V3 stashed the description in nested StringValues and read them back on
			-- hover; it is just a closure over config data now.
			[React.Event.MouseEnter] = props.OnPerkHover and function()
				props.OnPerkHover(perk)
			end or nil,
			[React.Event.MouseLeave] = props.OnPerkHover and function()
				props.OnPerkHover(nil)
			end or nil,
		})
	end

	---> purchase tiles
	local tileChildren: { [string]: any } = {
		UIListLayout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0.006, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, tier in CONFIG.Tiers do
		tileChildren[tier.Duration] = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = AdBoardConfig.BUTTON_IMAGE,
			ImageColor3 = color,
			LayoutOrder = index,
			ScaleType = Enum.ScaleType.Slice,
			Size = UDim2.fromScale(0.245, 1),
			SliceCenter = Rect.new(256, 256, 256, 256),
			SliceScale = 0.03,
		}, {
			Duration = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 0.05),
				Size = UDim2.fromScale(1, 0.25),
				Text = tier.Duration,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			}),

			Price = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0, 0.3),
				-- The Premium tile carries a sentence rather than a price, so it needs
				-- the taller box the original gave it.
				Size = if tier.IsPremium then UDim2.fromScale(1, 0.7) else UDim2.fromScale(1, 0.2),
				Text = tier.Price,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
			}),

			-- Premium is informational: no product to prompt.
			Button = if tier.IsPremium
				then nil
				else c("TextButton", {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Size = UDim2.fromScale(1, 1),
					Text = "",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 2,
					[React.Event.Activated] = function()
						props.OnPurchase(tier.ProductId)
					end,
				}),
		})
	end

	local function label(text: string, position: UDim2, size: UDim2, order: number)
		return c("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_DENKONE,
			LayoutOrder = order,
			Position = position,
			Size = size,
			Text = text,
			TextColor3 = color,
			TextScaled = true,
			TextStrokeColor3 = Color3.new(1, 1, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0, 0.05),
		Size = UDim2.fromScale(1, 0.9),
	}, {
		Heading = label(CONFIG.Heading, UDim2.fromScale(0.05, 0), UDim2.fromScale(0.9, 0.1), 1),
		Blurb = label(CONFIG.Blurb, UDim2.fromScale(0.05, 0.1), UDim2.fromScale(0.9, 0.1), 2),
		PerksHeading = label(CONFIG.PerksHeading, UDim2.fromScale(0.05, 0.25), UDim2.fromScale(0.9, 0.1), 3),

		Perks = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.05, 0.35),
			Size = UDim2.fromScale(0.9, 0.3),
		}, perkChildren),

		Footer = label(CONFIG.Footer, UDim2.fromScale(0.05, 0.6), UDim2.fromScale(0.9, 0.1), 4),

		Tiers = c("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.05, 0.7),
			Size = UDim2.fromScale(0.9, 0.25),
		}, tileChildren),
	})
end

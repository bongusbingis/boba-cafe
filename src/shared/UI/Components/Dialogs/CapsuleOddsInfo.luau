--[[
    Dialog: CapsuleOddsInfo
    Description: Drop-rate breakdown for a capsule.

    Odds are derived from the tier weights in InventoryItemDefinitions rather than
    written out by hand, so the displayed rates cannot drift from what CapsuleUtil
    actually rolls.

    Props: CapsuleName, ItemType?, MinTier?, OnResolution
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> config
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)

---> styles
local Styles = require(UI.Styles)

---> components
local Pane = require(UI.Components.Pane)

---> private
local c = React.createElement

--- Tier order matters for display; iterate a fixed list rather than the dictionary,
--- whose order is undefined.
local TIER_ORDER = { "Basic", "Uncommon", "Rare", "Epic", "Legendary", "Special" }

--- Normalises tier weights into percentages over the tiers a capsule can actually roll.
local function computeOdds(minTier: string?)
	local tiers = InventoryItemDefinitions.Tiers
	local eligible = {}
	local total = 0

	local reachedMin = minTier == nil

	for _, name in TIER_ORDER do
		local definition = tiers[name]
		if not definition then
			continue
		end

		if minTier and name == minTier then
			reachedMin = true
		end

		-- Weight 0 tiers (Special) are never rolled randomly.
		if reachedMin and (definition.Weight or 0) > 0 then
			table.insert(eligible, { Name = name, Weight = definition.Weight, Color = definition.Color })
			total += definition.Weight
		end
	end

	for _, entry in eligible do
		entry.Percent = if total > 0 then (entry.Weight / total) * 100 else 0
	end

	return eligible
end

---> public
return function(props: {
	CapsuleName: string,
	MinTier: string?,
	OnResolution: (string) -> (),
})
	local odds = computeOdds(props.MinTier)

	local rows: { [string]: any } = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0.02, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, entry in odds do
		rows[entry.Name] = c(Pane, {
			ClassName = "Frame",
			CornerRadius = Styles.CORNER_PILL,
			Native = {
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.7,
				LayoutOrder = index,
				Size = UDim2.fromScale(1, 0.13),
			},
		}, {
			Tier = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.06, 0.15),
					Size = UDim2.fromScale(0.5, 0.7),
					Text = entry.Name,
					TextColor3 = entry.Color,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				},
			}),

			Percent = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.44, 0.15),
					Size = UDim2.fromScale(0.5, 0.7),
					Text = string.format("%.2f%%", entry.Percent),
					TextColor3 = Styles.OFFWHITE,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Right,
				},
			}),
		})
	end

	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 1.1,
		CornerRadius = Styles.CORNER_CARD,
		Stroke = { Color = Styles.OFFWHITE, Thickness = 3.5 },
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Styles.GREEN_MID,
			BackgroundTransparency = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.26, 0.4),
		},
	}, {
		Title = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.05, 0.04),
				Size = UDim2.fromScale(0.75, 0.11),
				Text = props.CapsuleName,
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}),

		Subtitle = c(Pane, {
			ClassName = "TextLabel",
			Native = {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.05, 0.15),
				Size = UDim2.fromScale(0.75, 0.06),
				Text = "Drop rates",
				TextColor3 = Styles.CREAM,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
		}),

		Close = c(Pane, {
			ClassName = "TextButton",
			CornerRadius = Styles.CORNER_FULL,
			OnClick = function()
				props.OnResolution("Close")
			end,
			Native = {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Styles.RED,
				BackgroundTransparency = 0,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.95, 0.04),
				Size = UDim2.fromScale(0.11, 0.1),
				Text = "X",
				TextColor3 = Styles.OFFWHITE,
				TextScaled = true,
			},
		}),

		Rows = c(Pane, {
			ClassName = "Frame",
			Native = {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.95),
				Size = UDim2.fromScale(0.88, 0.72),
			},
		}, rows),
	})
end

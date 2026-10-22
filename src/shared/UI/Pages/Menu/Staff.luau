--[[
	Staff (Menu tab)
	Your rank at a glance: a rank card (level and title on a ShopCategory header,
	the HUD LevelBar's gold XP bar, the next title to earn), six work stats in the
	Statistics card style, then the title roadmap as ShopCategory rows.
	UI-REVISION: restructured from a loose bar + ten-card dump; title rows no longer
	carry the currency glyph.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local Knit = require(Packages.Knit)

---> styles
local Styles = require(UI.Styles)

---> components
local ShopCategory = require(UI.Pages.Shop.ShopCategory)

---> configuration
local Progression = require(Shared.Configuration.Progression)
local Titles = require(Shared.Configuration.Titles)

---> constants
local HEADER_IMAGE = "http://www.roblox.com/asset/?id=13465572823"
local FOOTER_IMAGE = "http://www.roblox.com/asset/?id=13465749908"
local ROW_WIDTH = 0.981

---> private
local c = React.createElement

local function formatThousands(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Stat card copied from Statistics.luau (Denk label over Fredoka value).
local function StatCard(props: {
	Label: string,
	Value: string,
	LayoutOrder: number,
})
	return c("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
	}, {
		UIPadding = c("UIPadding", {
			PaddingLeft = UDim.new(0.07, 0),
			PaddingRight = UDim.new(0.07, 0),
			PaddingTop = UDim.new(0.1, 0),
			PaddingBottom = UDim.new(0.1, 0),
		}),
		UIListLayout = c("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0.04, 0),
		}),
		LabelText = c("TextLabel", {
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0.35),
			Text = props.Label,
			TextColor3 = Styles.GREEN_LIGHT,
			TextScaled = true,
			FontFace = Styles.FONT_DENKONE,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		ValueText = c("TextLabel", {
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0.55),
			Text = props.Value,
			TextColor3 = Styles.GREEN,
			TextScaled = true,
			FontFace = Styles.FONT_FREDOKA,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

-- ShopCategory anatomy (header slice, GREEN body, footer slice) holding the XP bar.
local function RankCard(props: {
	Heading: string,
	Progress: number,
	BarText: string,
	Caption: string,
	LayoutOrder: number,
})
	return c("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0),
	}, {
		UIListLayout = c("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		Header = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = HEADER_IMAGE,
			ImageColor3 = Styles.GREEN_LIGHT,
			LayoutOrder = 1,
			Size = UDim2.fromScale(ROW_WIDTH, 0.065),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
			SliceCenter = Rect.new(0, 0, 1019, 40),
		}, {
			Title = c("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.132084),
				Size = UDim2.fromScale(0.94, 0.7),
				Text = props.Heading,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),
		Body = c("Frame", {
			BackgroundColor3 = Styles.GREEN,
			BorderSizePixel = 0,
			LayoutOrder = 2,
			Size = UDim2.fromScale(ROW_WIDTH, 0.12),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
		}, {
			Bar = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Styles.OFFWHITE,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.14),
				Size = UDim2.fromScale(0.94, 0.36),
			}, {
				Corner = c("UICorner", { CornerRadius = Styles.CORNER_FULL }),
				Fill = c("Frame", {
					BackgroundColor3 = Styles.GOLD,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(math.max(props.Progress, 0.04), 1),
					Visible = props.Progress > 0,
				}, {
					Corner = c("UICorner", { CornerRadius = Styles.CORNER_FULL }),
				}),
				Text = c("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.6, 0.78),
					Text = props.BarText,
					TextColor3 = Styles.GREEN_DEEP,
					TextScaled = true,
					ZIndex = 2,
				}),
			}),
			Caption = c("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromScale(0.5, 0.6),
				Size = UDim2.fromScale(0.94, 0.28),
				Text = props.Caption,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}),
		Footer = c("ImageLabel", {
			BackgroundTransparency = 1,
			Image = FOOTER_IMAGE,
			ImageColor3 = Styles.GREEN_LIGHT,
			LayoutOrder = 3,
			Size = UDim2.fromScale(ROW_WIDTH, 0.02),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
		}),
	})
end

-- Story preview: a level 3 player part way to level 4.
local function sampleData()
	return {
		Level = 3,
		XP = 33,
		Titles = nil,
		Statistics = { OrdersPrepared = 12, ShiftsCompleted = 2, SpillsCleaned = 3 },
	}
end

return function()
	local playerData, setPlayerData = React.useState(nil)

	React.useEffect(function()
		if not RunService:IsRunning() then
			setPlayerData(sampleData())
			return
		end
		local DataController = Knit.GetController("DataController")
		DataController:GetDataAsync():andThen(function(data)
			setPlayerData(data)
		end)
	end, {})

	local isLoaded = playerData ~= nil
	local level = if isLoaded then playerData.Level or 1 else 1
	local xpInto = if isLoaded then playerData.XP or 0 else 0
	local atMax = level >= Progression.MAX_LEVEL
	local xpForLevel = if atMax then 0 else Progression.XpToNext(level)
	local progress = if atMax then 1 else math.clamp(xpInto / math.max(1, xpForLevel), 0, 1)

	local titlesData = Titles.Normalize(if isLoaded then playerData.Titles else nil)
	if isLoaded then
		for titleId in Titles.LevelOwned(level) do
			titlesData.Owned[titleId] = true
		end
		if titlesData.Equipped == "" then
			titlesData.Equipped = Titles.HighestLevelTitleId(level)
		end
	end
	local ownedCount = 0
	for _ in titlesData.Owned do
		ownedCount += 1
	end
	local allTitles = Titles.All()
	local equippedText = Titles.TextFor(titlesData.Equipped)
	local nextTitle = nil
	for _, def in allTitles do
		if def.Source == "Level" and def.Level ~= nil and def.Level > level then
			nextTitle = def
			break
		end
	end

	local totalRecipes = 0
	local unlockedRecipes = 0
	for _, minLvl in Progression.MIN_LEVEL_BY_ITEM do
		totalRecipes += 1
		if level >= minLvl then
			unlockedRecipes += 1
		end
	end

	local stats = if isLoaded and typeof(playerData.Statistics) == "table" then playerData.Statistics else nil
	local function stat(key: string): string
		if not isLoaded then
			return "..."
		end
		return formatThousands(if stats then stats[key] or 0 else 0)
	end

	local heading = if not isLoaded
		then "Loading..."
		elseif equippedText ~= "" then `Level {level} · {equippedText}`
		else `Level {level}`
	local barText = if not isLoaded
		then ""
		elseif atMax then "Max level!"
		else `{formatThousands(xpInto)} / {formatThousands(xpForLevel)} XP`
	local caption = if not isLoaded
		then ""
		elseif nextTitle then `Next title: {nextTitle.Text} at Level {nextTitle.Level}`
		else "Every level title earned!"

	local cards = {
		{ Label = "Orders Served", Value = stat("OrdersPrepared") },
		{ Label = "Shifts Completed", Value = stat("ShiftsCompleted") },
		{ Label = "Recipes Unlocked", Value = if isLoaded then `{unlockedRecipes} / {totalRecipes}` else "..." },
		{ Label = "Order Tickets", Value = if isLoaded then tostring(Progression.SlotsFor(level)) else "..." },
		{ Label = "Titles Earned", Value = if isLoaded then `{ownedCount} / {#allTitles}` else "..." },
		{ Label = "Spills Cleaned", Value = stat("SpillsCleaned") },
	}

	local gridChildren = {
		UIGridLayout = c("UIGridLayout", {
			CellSize = UDim2.fromScale(0.47, 0.3),
			CellPadding = UDim2.fromScale(0.025, 0.03),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, card in ipairs(cards) do
		gridChildren[card.Label] = c(StatCard, {
			Label = card.Label,
			Value = card.Value,
			LayoutOrder = i,
		})
	end

	-- Title roadmap: the name on the left, its status on the right.
	local function statusFor(def, isOwned: boolean): string
		if titlesData.Equipped == def.Id then
			return "Equipped"
		elseif isOwned then
			return "Earned"
		elseif def.Source == "Level" then
			return `Level {def.Level}`
		end
		return def.Description
	end

	local levelItems = {}
	local manualItems = {}
	for _, def in allTitles do
		local isOwned = titlesData.Owned[def.Id] == true
		if def.Source == "Level" then
			table.insert(levelItems, { Label = def.Text, Price = statusFor(def, isOwned) })
		elseif Titles.IsSecret(def, isOwned) then
			table.insert(manualItems, { Label = "???", Price = "???" })
		elseif isOwned or not Titles.IsHidden(def, isOwned) then
			table.insert(manualItems, { Label = def.Text, Price = statusFor(def, isOwned) })
		end
	end

	local bodyChildren = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0.02, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Spacer = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 9999,
			Size = UDim2.new(1, 0, 0, 60),
		}),
		Rank = c(RankCard, {
			Heading = heading,
			Progress = progress,
			BarText = barText,
			Caption = caption,
			LayoutOrder = 1,
		}),
		Cards = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.fromScale(ROW_WIDTH, 0.42),
			SizeConstraint = Enum.SizeConstraint.RelativeXX,
		}, gridChildren),
		LevelTitles = c(ShopCategory, {
			Title = "Level Titles",
			Items = levelItems,
			LayoutOrder = 3,
			PriceGlyph = "",
		}),
	}
	if #manualItems > 0 then
		bodyChildren.ManualTitles = c(ShopCategory, {
			Title = "Event Titles",
			Items = manualItems,
			LayoutOrder = 4,
			PriceGlyph = "",
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
			Text = "Staff",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		Body = c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.112),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarThickness = 5,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1, 0.888),
		}, bodyChildren),
	})
end

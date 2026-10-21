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
local ShopCategory = require(UI.Pages.Shop.ShopCategory)

---> configuration
local Progression = require(Shared.Configuration.Progression)
local Titles = require(Shared.Configuration.Titles)

---> private
local c = React.createElement

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
		UICorner = c("UICorner", { CornerRadius = Styles.CORNER_CARD }),
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

return function()
	local playerData, setPlayerData = React.useState(nil)

	React.useEffect(function()
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
	local ordersServed = if stats then stats.OrdersPrepared or 0 else 0
	local shiftsCompleted = if stats then stats.ShiftsCompleted or 0 else 0
	local spillsCleaned = if stats then stats.SpillsCleaned or 0 else 0

	local cards = {
		{ Label = "Level", Value = if isLoaded then tostring(level) else "..." },
		{ Label = "Title", Value = if isLoaded then (if equippedText ~= "" then equippedText else "None") else "..." },
		{
			Label = "XP",
			Value = if not isLoaded then "..." elseif atMax then "Max level!" else `{xpInto} / {xpForLevel}`,
		},
		{ Label = "Order Tickets", Value = if isLoaded then tostring(Progression.SlotsFor(level)) else "..." },
		{ Label = "Orders Served", Value = if isLoaded then tostring(ordersServed) else "..." },
		{ Label = "Shifts Completed", Value = if isLoaded then tostring(shiftsCompleted) else "..." },
		{ Label = "Recipes Unlocked", Value = if isLoaded then `{unlockedRecipes} / {totalRecipes}` else "..." },
		{ Label = "Titles Earned", Value = if isLoaded then `{ownedCount} / {#allTitles}` else "..." },
		{
			Label = "Next Title",
			Value = if not isLoaded
				then "..."
				elseif nextTitle then `{nextTitle.Text} (Level {nextTitle.Level})`
				else "All earned!",
		},
		{ Label = "Spills Cleaned", Value = if isLoaded then tostring(spillsCleaned) else "..." },
	}

	local gridChildren = {
		UIGridLayout = c("UIGridLayout", {
			CellSize = UDim2.fromScale(0.47, 0.17),
			CellPadding = UDim2.fromScale(0.025, 0.025),
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

	local levelItems = {}
	local manualItems = {}
	for _, def in allTitles do
		local isOwned = titlesData.Owned[def.Id] == true
		if def.Source == "Level" then
			table.insert(levelItems, {
				Label = `Level {def.Level} — {def.Text}`,
				Price = if isOwned then "Earned" else def.Description,
			})
		else
			if isOwned then
				table.insert(manualItems, {
					Label = def.Text,
					Price = "Earned",
				})
			elseif Titles.IsSecret(def, isOwned) then
				table.insert(manualItems, {
					Label = "???",
					Price = "???",
				})
			elseif not Titles.IsHidden(def, isOwned) then
				table.insert(manualItems, {
					Label = def.Text,
					Price = def.Description,
				})
			end
		end
	end

	local bodyChildren = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0.02, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Spacer = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = math.huge,
			Size = UDim2.fromScale(1, 0.05),
		}),
		ProgressBar = c("Frame", {
			BackgroundColor3 = Styles.OFFWHITE,
			BorderSizePixel = 0,
			LayoutOrder = 1,
			Size = UDim2.fromScale(0.981, 0.045),
		}, {
			UICorner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Fill = c("Frame", {
				BackgroundColor3 = Styles.GREEN,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(progress, 1),
			}, {
				UICorner = c("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			}),
		}),
		Cards = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0.95),
		}, gridChildren),
		LevelTitles = c(ShopCategory, {
			Title = "Level Titles",
			Items = levelItems,
			LayoutOrder = 3,
		}),
	}
	if #manualItems > 0 then
		bodyChildren.ManualTitles = c(ShopCategory, {
			Title = "Event Titles",
			Items = manualItems,
			LayoutOrder = 4,
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

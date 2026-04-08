local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)

---> styles
local Styles = require(UI.Styles)

---> components
local ShopCategory = require(UI.Pages.Shop.ShopCategory)

---> data
local Menu = require(Shared.Ordering.Menu)

---> private
local c = React.createElement

local function buildSubItems(itemData: { [string]: any }): { ShopCategory.SubItem }?
	local subItems = {}

	if itemData.RequiredSelection then
		local groups = {}
		for groupName in pairs(itemData.RequiredSelection) do
			table.insert(groups, groupName)
		end
		table.sort(groups)
		for _, groupName in ipairs(groups) do
			table.insert(subItems, { Label = groupName, IsHeader = true })
			local options = {}
			for optionName in pairs(itemData.RequiredSelection[groupName]) do
				table.insert(options, optionName)
			end
			table.sort(options)
			for _, optionName in ipairs(options) do
				table.insert(subItems, { Label = optionName })
			end
		end
	end

	if itemData.Select then
		local groups = {}
		for groupName in pairs(itemData.Select) do
			table.insert(groups, groupName)
		end
		table.sort(groups)
		for _, groupName in ipairs(groups) do
			table.insert(subItems, { Label = groupName, IsHeader = true })
			for _, optionName in ipairs(itemData.Select[groupName]) do
				table.insert(subItems, { Label = optionName })
			end
		end
	end

	if itemData.Options then
		table.insert(subItems, { Label = "Options", IsHeader = true })
		local options = {}
		for optionName in pairs(itemData.Options) do
			table.insert(options, optionName)
		end
		table.sort(options)
		for _, optionName in ipairs(options) do
			table.insert(subItems, { Label = optionName })
		end
	end

	return if #subItems > 0 then subItems else nil
end

local function buildItemList(items: { [string]: any }): { ShopCategory.Item }
	local list = {}
	for itemKey, itemData in pairs(items) do
		table.insert(list, { Label = itemKey, SubItems = buildSubItems(itemData) })
	end
	table.sort(list, function(a, b)
		return a.Label < b.Label
	end)
	return list
end

---> public
return function()
	local categorySections = {
		UIListLayout = c("UIListLayout", {
			Padding = UDim.new(0.02, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		Spacer = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = math.huge,
			Size = UDim2.fromScale(1, 0.05),
		}),
	}

	local topSpecial = Menu["TopMenuSpecial"]
	if topSpecial then
		categorySections["TopMenuSpecial"] = c(ShopCategory, {
			Title = topSpecial.Title,
			Items = buildItemList(topSpecial.Items),
			LayoutOrder = 0,
			Color = topSpecial.Color,
		})
	end

	-- FoodTable categories sorted by LayoutOrder
	local foodCategories = {}
	for categoryName, categoryData in pairs(Menu["FoodTable"]) do
		table.insert(foodCategories, {
			Name = categoryName,
			Data = categoryData,
		})
	end
	table.sort(foodCategories, function(a, b)
		return a.Data.LayoutOrder < b.Data.LayoutOrder
	end)

	for i, category in ipairs(foodCategories) do
		categorySections[category.Name] = c(ShopCategory, {
			Title = category.Name,
			Items = buildItemList(category.Data.Items),
			LayoutOrder = i,
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
			Text = "Food Menu",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		Hint = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.5, 0.093),
			Size = UDim2.fromScale(0.94, 0.048),
			Text = "Click an item to view its available flavors, sizes, and modifications.",
			TextColor3 = Styles.GRAY,
			TextScaled = true,
			TextWrapped = true,
		}),

		Categories = c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0, 0.148),
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarThickness = 5,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1, 0.852),
		}, categorySections),
	})
end

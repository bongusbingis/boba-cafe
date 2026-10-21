--[[
	BobaPhone/BuildOrderRequest
	Pure cart + request mapping for the Boba Phone (REVIVAL-001 BOBA-PHONE D2/D5).

	Mirrors Pages/MobileOrder onSelectItem/onAddItem/onSubmitOrder exactly:
	Select/Options defaults, launch-filtered required picks, a 3-item cap, and a
	request of { Category, Item, CustomInfo } per entry. DefaultInfo is never
	sent: the server rebuilds each item from its own Menu.
]]

local BuildOrderRequest = {}

BuildOrderRequest.MAX_ITEMS = 3

export type CartEntry = {
	Category: string,
	Item: string,
	DefaultInfo: { [string]: any },
	CustomInfo: { [string]: any },
}

-- Launch-only copy of menu.FoodTable (MobileOrder buildLaunchFoodTable).
function BuildOrderRequest.launchFoodTable(menu: any): { [string]: any }
	local filtered: { [string]: any } = {}
	for categoryKey, data in menu.FoodTable do
		local items: { [string]: any } = {}
		local any = false
		for itemKey, itemData in data.Items do
			if menu.IsLaunchItem(categoryKey, itemKey) then
				items[itemKey] = itemData
				any = true
			end
		end
		if any then
			local copy = table.clone(data)
			copy.Items = items
			filtered[categoryKey] = copy
		end
	end
	return filtered
end

-- Launch-only options for one RequiredSelection group (MobileOrder launchOptions).
function BuildOrderRequest.launchOptions(menu: any, typeName: string, options: { [string]: any }): { [string]: any }
	local allowed = menu.LaunchChoices[typeName]
	if not allowed then
		return options
	end
	local keep: { [string]: any } = {}
	for optionKey, optionData in options do
		if table.find(allowed, optionKey) then
			keep[optionKey] = optionData
		end
	end
	return keep
end

-- Select/Options defaults for one tap (MobileOrder onSelectItem).
function BuildOrderRequest.defaultInfoFor(itemData: { [string]: any }): { [string]: any }
	local info: { [string]: any } = {}
	if itemData.Select then
		for selectType, options in itemData.Select do
			info[selectType] = options[1]
		end
	end
	if itemData.Options then
		for optionType, defaultValue in itemData.Options do
			info[optionType] = defaultValue
		end
	end
	return info
end

-- One launch-filtered required-selection step per group (MobileOrder queue).
function BuildOrderRequest.requiredQueueFor(
	menu: any,
	itemData: { [string]: any }
): { { name: string, options: { [string]: any } } }
	local queue: { { name: string, options: { [string]: any } } } = {}
	if itemData.RequiredSelection then
		for typeName, options in itemData.RequiredSelection do
			table.insert(queue, {
				name = typeName,
				options = BuildOrderRequest.launchOptions(menu, typeName, options),
			})
		end
	end
	return queue
end

function BuildOrderRequest.cartEntry(
	category: string,
	itemKey: string,
	itemData: { [string]: any },
	info: { [string]: any }
): CartEntry
	return {
		Category = category,
		Item = itemKey,
		DefaultInfo = itemData,
		CustomInfo = info,
	}
end

-- A new cart with the entry appended; a no-op once the cart holds MAX_ITEMS.
function BuildOrderRequest.appendCapped(cart: { CartEntry }, entry: CartEntry): { CartEntry }
	local nextCart = table.clone(cart)
	if #nextCart >= BuildOrderRequest.MAX_ITEMS then
		return nextCart
	end
	table.insert(nextCart, entry)
	return nextCart
end

-- The server request: DefaultInfo dropped, the choice kept (MobileOrder onSubmitOrder).
function BuildOrderRequest.toRequest(cart: { CartEntry }): { [string]: any }
	local request: { [string]: any } = table.create(#cart)
	for i, entry in cart do
		request[i] = { Category = entry.Category, Item = entry.Item, CustomInfo = entry.CustomInfo }
	end
	return request
end

return BuildOrderRequest

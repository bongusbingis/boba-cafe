local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local usePx = require(ReplicatedStorage.Shared.UI.Hooks.usePx)
local React = require(Packages.React)
local Knit = require(Packages.Knit)

---> components
local Pane = require(UI.Components.Pane)
local TopBar = require(script.TopBar)
local RightPanel = require(script.RightPanel)
local CategoryPage = require(script.CategoryPage)
local ItemPage = require(script.ItemPage)
local RequiredSelectionPage = require(script.RequiredSelectionPage)
local SizeOptionsPage = require(script.SizeOptionsPage)

---> data
local FoodService = require(Shared.Ordering.Menu)
local MistakeText = require(Shared.Ordering.MistakeText)
-- Only launch items are orderable (server refuses the rest): hide the others.
local function buildLaunchFoodTable()
	local filtered = {}
	for categoryKey, data in FoodService.FoodTable do
		local items = {}
		local any = false
		for itemKey, itemData in data.Items do
			if FoodService.IsLaunchItem(categoryKey, itemKey) then
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

local function launchOptions(typeName, options)
	local allowed = FoodService.LaunchChoices[typeName]
	if not allowed then
		return options
	end
	local keep = {}
	for optionKey, optionData in options do
		if table.find(allowed, optionKey) then
			keep[optionKey] = optionData
		end
	end
	return keep
end

local FoodTable = buildLaunchFoodTable()

---> styles
local Styles = require(UI.Styles)

---> constants
local DEFAULT_BAR_COLOR = Color3.fromRGB(224, 94, 88)
local MAX_ORDER_ITEMS = 3

---> private
local c = React.createElement

-- The server's not-clocked-in rejection for tablet submits (barista clocked out
-- between Take Order and submit). Matches CustomerService/OrderService exactly.
local CLOCKED_OUT_MESSAGE = "You must be clocked in."

-- Clock-in upsell: the tablet submit failed because the barista is clocked out.
-- Asks to clock in (ButtonPrompt, DEC-013) instead of only toasting; confirming
-- clocks in through the same ShiftService path as the HUD clock button and leaves
-- the tablet open so the player can submit again, declining just dismisses.
local clockInPromptOpen = false

local function offerClockIn()
	if clockInPromptOpen then
		return
	end
	if Players.LocalPlayer:GetAttribute("ClockedIn") == true then
		return -- clocked in since the server rejected (stale result)
	end
	clockInPromptOpen = true
	local ok, dialog = pcall(function()
		return Knit.GetController("DialogController").new("ButtonPrompt", {
			Title = "Clock In Required",
			Text = "You need to be clocked in for this. Do you want to clock in?",
			Buttons = {
				{ Text = "Clock In", Color = Styles.GREEN },
				{ Text = "Cancel", Color = Styles.RED },
			},
		})
	end)
	if not ok or dialog == nil then
		clockInPromptOpen = false
		warn("[Ordering] Clock-in prompt failed: " .. tostring(dialog))
		return
	end
	dialog
		:Fire()
		:andThen(function(choice)
			clockInPromptOpen = false
			if choice == "Clock In" then
				task.spawn(function()
					local clockOk, err = pcall(function()
						Knit.GetService("ShiftService"):SetClockedIn(true)
					end)
					if not clockOk then
						warn("[Ordering] Clock in request failed: " .. tostring(err))
					end
				end)
			end
		end)
		:catch(function()
			clockInPromptOpen = false
		end)
end

local function resolveItemName(orderItem: { [string]: any }): string
	local name: string = orderItem.DefaultInfo.ItemName
	if orderItem.DefaultInfo.Select and typeof(orderItem.CustomInfo) == "table" then
		for variantType in orderItem.DefaultInfo.Select do
			local chosen = orderItem.CustomInfo[variantType]
			if typeof(chosen) == "string" then
				name = chosen .. " " .. name
			end
		end
	end
	return name
end

local function resolveItemDescription(orderItem)
	local lines = {}
	if orderItem.DefaultInfo.RequiredSelection then
		local groups = {}
		for selType in orderItem.DefaultInfo.RequiredSelection do
			table.insert(groups, selType)
		end
		table.sort(groups, function(a, b)
			local orderA = if a == "Syrup Flavor" then 1 elseif a == "Tapioca Flavor" then 2 else 3
			local orderB = if b == "Syrup Flavor" then 1 elseif b == "Tapioca Flavor" then 2 else 3
			return orderA < orderB
		end)
		for _, selType in ipairs(groups) do
			table.insert(lines, selType .. ":\n	- " .. (orderItem.CustomInfo[selType] or "?"))
		end
	end
	if orderItem.DefaultInfo.Options then
		for optType, defaultValue in orderItem.DefaultInfo.Options do
			local chosen = orderItem.CustomInfo[optType]
			if chosen ~= defaultValue then
				table.insert(lines, if chosen then ("+ " .. optType) else ("- NO " .. optType))
			end
		end
	end
	return table.concat(lines, "\n")
end

local function itemsMatch(a: any, b: any): boolean
	if a.Category ~= b.Category or a.Item ~= b.Item then
		return false
	end
	local aInfo = a.CustomInfo or {}
	local bInfo = b.CustomInfo or {}
	if aInfo.Size ~= bInfo.Size then
		return false
	end
	if aInfo["Syrup Flavor"] ~= bInfo["Syrup Flavor"] then
		return false
	end
	if aInfo["Tapioca Flavor"] ~= bInfo["Tapioca Flavor"] then
		return false
	end
	local aIced = (aInfo.Iced == true or aInfo.Ice == true)
	local bIced = (bInfo.Iced == true or bInfo.Ice == true)
	if aIced ~= bIced then
		return false
	end
	local aSugar = (aInfo.Sugar == true)
	local bSugar = (bInfo.Sugar == true)
	if aSugar ~= bSugar then
		return false
	end
	return true
end

-- AUDIT-FIX D3.1a, narrowed by DEC-059: the scripted first-session NPC's order as tablet items, so the
-- tutorial Submit is one tap. Used only when the server sets Prefill. Starts from the same Select and
-- Option defaults as onItemSelected, then the customer's choices. Unknown items are skipped.
local function prefillFromNpc(npcOrderData: any): { any }
	local items = {}
	if npcOrderData == nil or typeof(npcOrderData.Orders) ~= "table" then
		return items
	end
	for _, order in npcOrderData.Orders do
		local category = FoodService.FoodTable[order.Category]
		local def = if category and category.Items then category.Items[order.Item] else nil
		if def == nil or #items >= MAX_ORDER_ITEMS then
			continue
		end
		local info: { [string]: any } = {}
		if def.Select then
			for selType, options in def.Select do
				info[selType] = options[1]
			end
		end
		if def.Options then
			for optType, defaultValue in def.Options do
				info[optType] = defaultValue
			end
		end
		if typeof(order.CustomInfo) == "table" then
			for key, value in order.CustomInfo do
				info[key] = value
			end
		end
		table.insert(items, { Category = order.Category, Item = order.Item, DefaultInfo = def, CustomInfo = info })
	end
	return items
end

local function validateSubmittedOrder(submittedList: { any }, expectedList: { any }?): boolean
	if typeof(expectedList) ~= "table" or #submittedList ~= #expectedList then
		return false
	end
	local used = table.create(#expectedList, false)
	for _, submitted in submittedList do
		local found = false
		for j, expected in expectedList do
			if not used[j] and itemsMatch(submitted, expected) then
				used[j] = true
				found = true
				break
			end
		end
		if not found then
			return false
		end
	end
	return true
end

-- AUDIT-FIX D1.3: names the first field that differs, e.g. "Wrong size: they wanted Medium".
local function describeMismatch(submittedList: { any }, expectedList: { any }?): string
	if typeof(expectedList) ~= "table" then
		return MistakeText.Field(nil, nil)
	end
	if #submittedList ~= #expectedList then
		return MistakeText.Field("Count", #expectedList)
	end
	local usedExpected = table.create(#expectedList, false)
	local unmatched = {}
	for _, submitted in submittedList do
		local found = false
		for j, expected in expectedList do
			if not usedExpected[j] and itemsMatch(submitted, expected) then
				usedExpected[j] = true
				found = true
				break
			end
		end
		if not found then
			table.insert(unmatched, submitted)
		end
	end
	local firstExpected = nil
	for j, expected in expectedList do
		if usedExpected[j] then
			continue
		end
		firstExpected = firstExpected or expected
		for _, submitted in unmatched do
			if submitted.Category ~= expected.Category or submitted.Item ~= expected.Item then
				continue
			end
			local want = expected.CustomInfo or {}
			local have = submitted.CustomInfo or {}
			if want.Size ~= have.Size then
				return MistakeText.Field("Size", want.Size)
			elseif want["Syrup Flavor"] ~= have["Syrup Flavor"] then
				return MistakeText.Field("Syrup", want["Syrup Flavor"])
			elseif want["Tapioca Flavor"] ~= have["Tapioca Flavor"] then
				return MistakeText.Field("Tapioca", want["Tapioca Flavor"])
			elseif (want.Iced == true or want.Ice == true) ~= (have.Iced == true or have.Ice == true) then
				return MistakeText.Field("Iced", want.Iced == true or want.Ice == true)
			end
			return MistakeText.Field("Sugar", want.Sugar == true)
		end
	end
	if firstExpected == nil then
		return MistakeText.Field(nil, nil)
	end
	local category = FoodService.FoodTable[firstExpected.Category]
	local def = if category and category.Items then category.Items[firstExpected.Item] else nil
	local name = if def and def.ItemName then def.ItemName else firstExpected.Item
	local syrup = (firstExpected.CustomInfo or {})["Syrup Flavor"]
	return MistakeText.Field("Item", if syrup then `{syrup} {name}` else name)
end

---> public
return function(props: {
	Args: { any }?,
	ClosePage: (() -> ())?,
	OnClose: (() -> ())?,
})
	-- An NPC's tablet (NpcId) or a real customer at the counter (CounterCustomerId, DEC-059).
	local npcOrderData = if props.Args
			and typeof(props.Args[1]) == "table"
			and (props.Args[1].NpcId ~= nil or props.Args[1].CounterCustomerId ~= nil)
		then props.Args[1]
		else nil
	local counterData = if npcOrderData ~= nil and npcOrderData.CounterCustomerId ~= nil then npcOrderData else nil

	-- TAKEOVER-REVIEW-FIX P2-1: the tablet's NPC comes only from this page's own Args. The page can close without
	-- closeMenu (HUD page switch), so clear the controller's copy on unmount and never fall back to it.
	React.useEffect(function()
		return function()
			if npcOrderData == nil then
				return
			end
			pcall(function()
				local controller = Knit.GetController("OrderController")
				if controller and controller.ActiveNpcOrder == npcOrderData then
					controller.ActiveNpcOrder = nil
				end
			end)
			-- Closing a counter tablet frees the customer for another barista. The server only
			-- releases this tablet's own lock (LockId), so a stale close changes nothing.
			if counterData ~= nil and RunService:IsRunning() then
				pcall(function()
					Knit.GetService("CustomerService")
						:CancelCounterOrder(counterData.CounterCustomerId, counterData.LockId)
						:catch(warn)
				end)
			end
		end
	end, {})

	local function closeMenu()
		pcall(function()
			local controller = Knit.GetController("OrderController")
			if controller and controller.CloseOrdering then
				controller:CloseOrdering()
			end
		end)
		if props.ClosePage then
			props.ClosePage()
		elseif props.OnClose then
			props.OnClose()
		end
	end

	local notepadVisible, setNotepadVisible = React.useState(npcOrderData ~= nil)
	local px = usePx()
	local freeformNotes, setFreeformNotes = React.useState("")

	---> page routing
	-- Pages: "CategorySelect" | "ItemSelect" | "RequiredSelection" | "SizeOptions"
	local page, setPage = React.useState("CategorySelect")

	---> item-builder state
	local selCategory, setSelCategory = React.useState(nil :: string?)
	local selItemKey, setSelItemKey = React.useState(nil :: string?)
	local customInfo, setCustomInfo = React.useState({} :: { [string]: any })

	-- Queue of required-selection steps for the current item: { { name: string, options: table } }
	local reqSelQueue, setReqSelQueue = React.useState({} :: { any })
	local reqSelIdx, setReqSelIdx = React.useState(1)

	---> order accumulation
	local orderItems, setOrderItems = React.useState(function(): { any }
		if npcOrderData ~= nil and npcOrderData.Prefill == true then
			return prefillFromNpc(npcOrderData)
		end
		return {}
	end)

	---> barista info (local player, loaded async)
	local function readPlayerLevel(): number
		local localPlayer = Players.LocalPlayer
		local val = localPlayer and localPlayer:GetAttribute("Level")
		if typeof(val) == "number" then
			return val
		end
		return 1
	end

	local staffLevel, setStaffLevel = React.useState(readPlayerLevel)
	local staffAvatarUrl, setStaffAvatarUrl = React.useState("rbxasset://textures/ui/GuiImagePlaceholder.png")

	---> load local player info once on mount
	React.useEffect(function()
		local localPlayer = Players.LocalPlayer

		task.spawn(function()
			local ok, url = pcall(
				Players.GetUserThumbnailAsync,
				Players,
				localPlayer.UserId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size352x352
			)
			if ok then
				setStaffAvatarUrl(url)
			end
		end)

		local function updateLevel()
			local val = localPlayer and localPlayer:GetAttribute("Level")
			if typeof(val) == "number" then
				setStaffLevel(val)
			end
		end

		updateLevel()
		local levelConn = localPlayer and localPlayer:GetAttributeChangedSignal("Level"):Connect(updateLevel)

		local dataOk, dataController = pcall(function()
			return Knit.GetController("DataController")
		end)
		if dataOk and dataController then
			dataController
				:GetDataAsync()
				:andThen(function(data)
					if typeof(data) == "table" and typeof(data.Level) == "number" then
						setStaffLevel(data.Level)
					end
				end)
				:catch(function() end)
		end

		return function()
			if levelConn then
				levelConn:Disconnect()
			end
		end
	end, {})

	---> computed TopBar props based on current page
	local topBarTitle = "Order"
	local topBarColor = DEFAULT_BAR_COLOR

	if selCategory and FoodTable[selCategory] then
		topBarColor = FoodTable[selCategory].Color
	end

	if page == "ItemSelect" and selCategory then
		topBarTitle = selCategory
	elseif page == "RequiredSelection" and reqSelQueue[reqSelIdx] then
		local stepName = reqSelQueue[reqSelIdx].name
		topBarTitle = if stepName == "Syrup Flavor" then "Boba Tea Flavor" else stepName
	elseif page == "SizeOptions" then
		local itemDef = if selCategory
				and selItemKey
				and FoodTable[selCategory]
			then FoodTable[selCategory].Items[selItemKey]
			else nil
		topBarTitle = if itemDef and itemDef.Select and itemDef.Select.Size then "Select Size" else "Add to Order"
	end

	---> navigation handlers

	local function goBack()
		if page == "ItemSelect" then
			setPage("CategorySelect")
		elseif page == "RequiredSelection" then
			if reqSelIdx > 1 then
				setReqSelIdx(reqSelIdx - 1)
			else
				setSelCategory(nil)
				setSelItemKey(nil)
				setCustomInfo({})
				setReqSelQueue({})
				setReqSelIdx(1)
				setPage("ItemSelect")
			end
		elseif page == "SizeOptions" then
			if #reqSelQueue > 0 then
				setReqSelIdx(#reqSelQueue)
				setPage("RequiredSelection")
			else
				setSelCategory(nil)
				setSelItemKey(nil)
				setCustomInfo({})
				setReqSelQueue({})
				setReqSelIdx(1)
				setPage("ItemSelect")
			end
		end
	end

	local function cancelItemConfig()
		setSelCategory(nil)
		setSelItemKey(nil)
		setCustomInfo({})
		setReqSelQueue({})
		setReqSelIdx(1)
		setPage("CategorySelect")
	end

	local function onCategorySelected(categoryKey: string)
		setSelCategory(categoryKey)
		setPage("ItemSelect")
	end

	local function onItemSelected(itemKey: string)
		local item = FoodTable[selCategory :: string].Items[itemKey]

		-- Initialise customInfo with Select defaults and Option defaults.
		local info: { [string]: any } = {}
		if item.Select then
			for selType, options in item.Select do
				info[selType] = options[1]
			end
		end
		if item.Options then
			for optType, defaultValue in item.Options do
				info[optType] = defaultValue
			end
		end

		-- Build the required-selection queue.
		-- Deterministic order: "Syrup Flavor" (Boba Tea Flavor) first, then "Tapioca Flavor".
		local queue = {}
		if item.RequiredSelection then
			for typeName, options in item.RequiredSelection do
				table.insert(queue, { name = typeName, options = launchOptions(typeName, options) })
			end
			table.sort(queue, function(a, b)
				local orderA = if a.name == "Syrup Flavor" then 1 elseif a.name == "Tapioca Flavor" then 2 else 3
				local orderB = if b.name == "Syrup Flavor" then 1 elseif b.name == "Tapioca Flavor" then 2 else 3
				return orderA < orderB
			end)
		end

		setSelItemKey(itemKey)
		setCustomInfo(info)
		setReqSelQueue(queue)
		setReqSelIdx(1)
		setPage(if #queue > 0 then "RequiredSelection" else "SizeOptions")
	end

	local function onAddToOrder(overrideInfo: { [string]: any }?)
		if not selCategory or not selItemKey then
			return
		end
		if #orderItems >= MAX_ORDER_ITEMS then
			return
		end
		local item = FoodTable[selCategory :: string].Items[selItemKey :: string]
		local finalInfo = if typeof(overrideInfo) == "table" then overrideInfo else customInfo

		local newOrder = table.clone(orderItems)
		table.insert(newOrder, {
			Category = selCategory,
			Item = selItemKey,
			DefaultInfo = item,
			CustomInfo = finalInfo,
		})
		setOrderItems(newOrder)

		setSelCategory(nil)
		setSelItemKey(nil)
		setCustomInfo({})
		setReqSelQueue({})
		setReqSelIdx(1)
		setPage("CategorySelect")
	end

	local function onReqSelOptionPicked(optionKey: string)
		local newInfo = table.clone(customInfo)
		newInfo[reqSelQueue[reqSelIdx].name] = optionKey
		setCustomInfo(newInfo)

		if reqSelIdx < #reqSelQueue then
			setReqSelIdx(reqSelIdx + 1)
		else
			setPage("SizeOptions")
		end
	end

	local function onOrderItemRemoved(index: number)
		local newOrder = table.clone(orderItems)
		table.remove(newOrder, index)
		setOrderItems(newOrder)
	end

	local isSubmitting = React.useRef(false)

	-- Players can only order for themselves. The server replies { Success, Message? }; on failure the order is kept
	-- so the player can adjust it and try again.
	local function submitOrder()
		if isSubmitting.current or #orderItems == 0 then
			return
		end

		if not RunService:IsRunning() then
			closeMenu()
			return
		end

		-- The server rebuilds each item from its own Menu, so only the choice is sent.
		local request = table.create(#orderItems)
		for i, orderItem in orderItems do
			request[i] = { Category = orderItem.Category, Item = orderItem.Item, CustomInfo = orderItem.CustomInfo }
		end

		if counterData ~= nil then
			-- A real customer's order: nothing to match on the client; the server rebuilds it.
			isSubmitting.current = true
			task.spawn(function()
				local ok, result = pcall(function()
					return Knit.GetService("CustomerService")
						:SubmitCounterOrder(counterData.CounterCustomerId, counterData.LockId, request)
						:expect()
				end)
				isSubmitting.current = false
				local success = ok and typeof(result) == "table" and result.Success == true
				local message = if ok and typeof(result) == "table" then result.Message else nil
				if not success and message == CLOCKED_OUT_MESSAGE then
					offerClockIn()
					return
				end
				Knit.GetController("DialogController"):Notify({
					Title = if success then "Order Placed" else "Order Error",
					Description = message or (if success then "Order placed." else "Unable to submit order."),
				})
				if success then
					closeMenu()
					setOrderItems({})
					setSelCategory(nil)
					setPage("CategorySelect")
				end
			end)
			return
		end

		if npcOrderData ~= nil then
			local matches = validateSubmittedOrder(request, npcOrderData.Orders)
			if not matches then
				Knit.GetController("DialogController"):Notify({
					Title = "Order Error",
					Description = describeMismatch(request, npcOrderData.Orders),
				})
				return
			end

			isSubmitting.current = true
			task.spawn(function()
				local ok, result = pcall(function()
					return Knit.GetService("CustomerService"):SubmitNpcOrder(npcOrderData.NpcId, request):expect()
				end)
				isSubmitting.current = false
				local success = ok and typeof(result) == "table" and result.Success == true
				local message = if ok and typeof(result) == "table" then result.Message else nil

				if not success then
					if message == CLOCKED_OUT_MESSAGE then
						offerClockIn()
						return
					end
					Knit.GetController("DialogController"):Notify({
						Title = "Order Error",
						Description = message or "That doesn't match what the customer asked for!",
					})
					return
				end

				closeMenu()
				setOrderItems({})
				setSelCategory(nil)
				setPage("CategorySelect")
			end)
			return
		end

		isSubmitting.current = true
		task.spawn(function()
			-- Knit client methods return a Promise; expect() yields and throws on rejection.
			local ok, result = pcall(function()
				return Knit.GetService("OrderService"):CreateOrder(Players.LocalPlayer.UserId, request):expect()
			end)
			isSubmitting.current = false
			if not ok then
				warn("[Ordering] CreateOrder failed:", result)
			end

			local success = ok and typeof(result) == "table" and result.Success == true
			local message = if ok and typeof(result) == "table" then result.Message else nil
			Knit.GetController("DialogController"):Notify({
				Title = if success then "Order Placed" else "Order Failed",
				Description = message or (if success then "Your order was sent." else "Unable to submit order."),
			})

			if success then
				setOrderItems({})
				setSelCategory(nil)
				setPage("CategorySelect")
				closeMenu()
			end
		end)
	end

	local cardSize = usePx()(125)
	local activeItem = if selCategory and selItemKey
		then FoodTable[selCategory :: string].Items[selItemKey :: string]
		else nil
	local currentReqStep = reqSelQueue[reqSelIdx]

	-- Pick the active page content and whether/how the content area is offset below the TopBar
	local isRootPage = page == "CategorySelect"
	local contentPos = if isRootPage then UDim2.fromScale(0, 0) else UDim2.fromScale(0, 0.112254)
	local contentSize = if isRootPage then UDim2.fromScale(1, 1) else UDim2.fromScale(1, 0.887746)

	local activeContent = if page == "CategorySelect"
		then c(CategoryPage, {
			FoodTable = FoodTable,
			CardSize = cardSize,
			OnCategorySelected = onCategorySelected,
		})
		elseif page == "ItemSelect" then c(ItemPage, {
			SelectedCategory = selCategory,
			FoodTable = FoodTable,
			OnItemSelected = onItemSelected,
		})
		elseif page == "RequiredSelection" then c(RequiredSelectionPage, {
			Step = currentReqStep,
			CustomInfo = customInfo,
			OnOptionPicked = onReqSelOptionPicked,
		})
		elseif page == "SizeOptions" then c(SizeOptionsPage, {
			Item = activeItem,
			CustomInfo = customInfo,
			OrderItemsCount = #orderItems,
			MaxOrderItems = MAX_ORDER_ITEMS,
			OnCustomInfoChanged = setCustomInfo,
			OnAddToOrder = onAddToOrder,
			OnCancel = cancelItemConfig,
		})
		else nil

	local function renderNotepad()
		local isNpcOrder = npcOrderData ~= nil and npcOrderData.CounterCustomerId == nil
		local parsedItems: { { Index: number, Title: string, Extras: { string } } } = {}

		if isNpcOrder then
			if typeof(npcOrderData.Orders) == "table" and #npcOrderData.Orders > 0 then
				for i, order in ipairs(npcOrderData.Orders) do
					local cInfo = order.CustomInfo or {}
					local size = cInfo.Size
					local syrup = cInfo["Syrup Flavor"]
					local tapioca = cInfo["Tapioca Flavor"]
					local iced = cInfo.Iced == true or cInfo.Ice == true
					local sugar = cInfo.Sugar == true

					local name = order.Item or "Item"
					if order.Category == "Boba Teas" or string.find(tostring(name), "Boba") then
						if syrup ~= nil then
							name = syrup .. " Boba"
						else
							name = "Boba"
						end
					elseif order.Category == "Coffees" then
						if name == "Regular" then
							name = "Regular Coffee"
						end
					end
					if size ~= nil then
						name = size .. " " .. name
					end

					local extras = {}
					if tapioca ~= nil then
						table.insert(extras, tapioca .. " Tapioca")
					end
					if iced then
						table.insert(extras, "Ice")
					end
					if sugar then
						table.insert(extras, "Sugar")
					end

					table.insert(parsedItems, {
						Index = i,
						Title = name,
						Extras = extras,
					})
				end
			elseif npcOrderData.RequestedText and #npcOrderData.RequestedText > 0 then
				local rawLines = npcOrderData.RequestedText:split("\n")
				for i, line in ipairs(rawLines) do
					local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
					if #trimmed > 0 then
						local parts = trimmed:split(", ")
						local title = parts[1] or trimmed
						local extras = {}
						for p = 2, #parts do
							table.insert(extras, parts[p])
						end
						table.insert(parsedItems, {
							Index = i,
							Title = title,
							Extras = extras,
						})
					end
				end
			end
		end

		local orderItemElements: { [string]: any } = {
			UIListLayout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, px(8)),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			UIPadding = c("UIPadding", {
				PaddingTop = UDim.new(0, px(4)),
				PaddingBottom = UDim.new(0, px(8)),
				PaddingLeft = UDim.new(0, px(2)),
				PaddingRight = UDim.new(0, px(4)),
			}),
		}

		for _, item in ipairs(parsedItems) do
			local extraElements = {}
			if #item.Extras > 0 then
				extraElements["UIListLayout"] = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, px(2)),
					SortOrder = Enum.SortOrder.LayoutOrder,
				})
				for extraIdx, extra in ipairs(item.Extras) do
					extraElements[`extra_{extraIdx}`] = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						LayoutOrder = extraIdx,
						Size = UDim2.new(1, 0, 0, px(22)),
						Text = `  •  {extra}`,
						TextColor3 = Color3.fromRGB(60, 60, 60),
						TextSize = 16,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
					})
				end
			end

			orderItemElements[`item_{item.Index}`] = c(Pane, {
				ClassName = "Frame",
				CornerRadius = Styles.CORNER_CARD,
				Stroke = { Color = Color3.fromRGB(220, 220, 220), Thickness = 1 },
				ListLayout = {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, px(4)),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				Padding = {
					PaddingTop = UDim.new(0, px(8)),
					PaddingBottom = UDim.new(0, px(8)),
					PaddingLeft = UDim.new(0, px(10)),
					PaddingRight = UDim.new(0, px(10)),
				},
				Native = {
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Color3.fromRGB(248, 248, 248),
					BackgroundTransparency = 0,
					LayoutOrder = item.Index,
					Size = UDim2.fromScale(1, 0),
				},
			}, {
				HeaderRow = c(Pane, {
					ClassName = "Frame",
					ListLayout = {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, px(8)),
						VerticalAlignment = Enum.VerticalAlignment.Center,
					},
					Native = {
						BackgroundTransparency = 1,
						LayoutOrder = 1,
						Size = UDim2.new(1, 0, 0, px(26)),
					},
				}, {
					NumberBadge = c(Pane, {
						ClassName = "Frame",
						CornerRadius = 1,
						Native = {
							BackgroundColor3 = Color3.fromRGB(51, 51, 51),
							BackgroundTransparency = 0,
							Size = UDim2.fromOffset(px(22), px(22)),
						},
					}, {
						BadgeText = c("TextLabel", {
							BackgroundTransparency = 1,
							FontFace = Styles.FONT_FREDOKA,
							Size = UDim2.fromScale(1, 1),
							Text = tostring(item.Index),
							TextColor3 = Color3.new(1, 1, 1),
							TextSize = 14,
						}),
					}),

					ItemTitle = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Styles.FONT_FREDOKA,
						Size = UDim2.new(1, -px(30), 1, 0),
						Text = item.Title,
						TextColor3 = Color3.fromRGB(20, 20, 20),
						TextSize = 18,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				}),

				ExtrasList = if #item.Extras > 0
					then c("Frame", {
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						LayoutOrder = 2,
						Size = UDim2.fromScale(1, 0),
					}, extraElements)
					else nil,
			})
		end

		orderItemElements["BottomSpacer"] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 9999,
			Size = UDim2.new(1, 0, 0, px(24)),
			Visible = true,
		})

		return c(Pane, {
			ClassName = "Frame",
			CornerRadius = Styles.CORNER_CARD,
			Stroke = {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(51, 51, 51),
				Thickness = 3,
			},
			Native = {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Styles.OFFWHITE,
				BackgroundTransparency = 0,
				ClipsDescendants = true,
				Position = UDim2.fromScale(-0.02, 0.02),
				Size = UDim2.fromScale(0.34, 0.58),
				Visible = notepadVisible,
			},
		}, {
			HeaderBar = c(Pane, {
				ClassName = "Frame",
				Native = {
					BackgroundColor3 = Color3.fromRGB(51, 51, 51),
					BackgroundTransparency = 0,
					Position = UDim2.new(0, 0, 0, 0),
					Size = UDim2.new(1, 0, 0, px(38)),
				},
			}, {
				Title = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromOffset(px(12), 0),
					Size = UDim2.fromScale(0.7, 1),
					Text = if isNpcOrder then "Order Ticket" else "Notepad",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 18,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),

				CloseBtn = c(Pane, {
					ClassName = "TextButton",
					CornerRadius = 1,
					OnClick = function()
						setNotepadVisible(false)
					end,
					Native = {
						AnchorPoint = Vector2.new(1, 0.5),
						AutoButtonColor = true,
						BackgroundColor3 = Color3.fromRGB(70, 70, 70),
						BackgroundTransparency = 0,
						FontFace = Styles.FONT_FREDOKA,
						Position = UDim2.new(1, -px(8), 0.5, 0),
						Size = UDim2.fromOffset(px(24), px(24)),
						Text = "✕",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 13,
					},
				}),
			}),

			Description = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Position = UDim2.fromOffset(px(12), px(42)),
				Size = UDim2.new(1, -px(24), 0, px(22)),
				Text = if counterData ~= nil
					then "Take the customer's order:"
					elseif npcOrderData ~= nil then "Customer's requested order:"
					else "Use this page to take notes on customer orders.",
				TextColor3 = Color3.fromRGB(65, 65, 65),
				TextSize = 15,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Content = if isNpcOrder and #parsedItems > 0
				then c("ScrollingFrame", {
					Active = true,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					CanvasSize = UDim2.new(),
					Position = UDim2.fromOffset(px(10), px(68)),
					ScrollBarImageColor3 = Color3.fromRGB(180, 180, 180),
					ScrollBarThickness = 4,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					Size = UDim2.new(1, -px(20), 1, -px(76)),
				}, orderItemElements)
				else c(Pane, {
					ClassName = "Frame",
					CornerRadius = Styles.CORNER_CARD,
					Stroke = { Color = Color3.fromRGB(215, 215, 215), Thickness = 1 },
					Padding = {
						PaddingLeft = UDim.new(0, px(8)),
						PaddingRight = UDim.new(0, px(8)),
						PaddingTop = UDim.new(0, px(8)),
						PaddingBottom = UDim.new(0, px(8)),
					},
					Native = {
						BackgroundColor3 = Color3.fromRGB(248, 248, 248),
						BackgroundTransparency = 0,
						Position = UDim2.fromOffset(px(10), px(68)),
						Size = UDim2.new(1, -px(20), 1, -px(76)),
					},
				}, {
					TextBox = c("TextBox", {
						BackgroundTransparency = 1,
						ClearTextOnFocus = false,
						FontFace = Styles.FONT_FREDOKA,
						PlaceholderColor3 = Styles.GRAY,
						PlaceholderText = "Type customer notes here...",
						Size = UDim2.fromScale(1, 1),
						Text = if npcOrderData ~= nil then (npcOrderData.RequestedText or "") else freeformNotes,
						TextColor3 = Color3.fromRGB(45, 55, 45),
						TextSize = 16,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Top,
						[React.Change.Text] = function(rbx: TextBox)
							setFreeformNotes(rbx.Text)
						end,
					}),
				}),
		})
	end

	---> main render
	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 1.53648,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.65, 0.6),
			Size = UDim2.fromScale(1, 1),
		},
	}, {
		Base = c(Pane, {
			ClassName = "ImageLabel",
			Native = {
				BackgroundTransparency = 1,
				Image = "http://www.roblox.com/asset/?id=13675614099",
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			},
		}, {
			Container = c(Pane, {
				ClassName = "Frame",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.95, 0.925),
				},
			}, {
				Top = c(Pane, {
					ClassName = "ImageLabel",
					Native = {
						BackgroundTransparency = 1,
						Image = "http://www.roblox.com/asset/?id=13675646315",
						Position = UDim2.fromScale(0, 0),
						Size = UDim2.fromScale(1, 0.0926297),
					},
				}, {
					Title = c(Pane, {
						ClassName = "TextLabel",
						Native = {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundTransparency = 1,
							FontFace = Styles.FONT_FREDOKA,
							Position = UDim2.fromScale(0.78, 0.49),
							Size = UDim2.fromScale(0.338597, 0.64),
							Text = "Boba Ordering System",
							TextColor3 = Color3.new(1, 1, 1),
							TextScaled = true,
						},
					}),

					NotepadToggle = c(Pane, {
						ClassName = "ImageButton",
						OnClick = function()
							setNotepadVisible(function(v)
								return not v
							end)
						end,
						Native = {
							AutoButtonColor = false,
							BackgroundTransparency = 1,
							Image = "http://www.roblox.com/asset/?id=13927899272",
							Position = UDim2.fromScale(0.02, 0.191),
							ScaleType = Enum.ScaleType.Fit,
							Size = UDim2.fromScale(0.0345125, 0.587943),
						},
					}),
				}),

				Bottom = c(Pane, {
					ClassName = "ImageLabel",
					Native = {
						AnchorPoint = Vector2.new(0, 1),
						BackgroundTransparency = 1,
						Image = "http://www.roblox.com/asset/?id=13675645871",
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.fromScale(1, 0.0926297),
					},
				}, {
					Minimize = c(Pane, {
						ClassName = "TextButton",
						Native = {
							AnchorPoint = Vector2.new(0.5, 0.5),
							AutoButtonColor = false,
							BackgroundTransparency = 1,
							FontFace = Styles.FONT_FREDOKA,
							Position = UDim2.fromScale(0.515, 0.5),
							Size = UDim2.fromScale(0.05, 1),
							Text = "",
							TextColor3 = Color3.new(),
						},
					}),
				}),

				Display = c(Pane, {
					ClassName = "Frame",
					Native = {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 0,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 0.815),
					},
				}, {
					Players = c(RightPanel, {
						OrderItems = orderItems,
						MaxOrderItems = MAX_ORDER_ITEMS,
						StaffAvatarUrl = staffAvatarUrl,
						StaffLevel = staffLevel,
						StaffRole = `Level {staffLevel}`,
						ResolveItemName = resolveItemName,
						ResolveItemDescription = resolveItemDescription,
						OnOrderItemRemoved = onOrderItemRemoved,
						OnSubmit = submitOrder,
						NpcOrderText = npcOrderData and npcOrderData.RequestedText,
						NpcId = npcOrderData and npcOrderData.NpcId,
						PatienceEnd = npcOrderData and npcOrderData.PatienceEnd,
						PatienceTotal = npcOrderData and npcOrderData.PatienceTotal,
						IsNpc = npcOrderData ~= nil and npcOrderData.CounterCustomerId == nil,
					}),

					Pages = c(Pane, {
						ClassName = "Frame",
						Native = {
							BackgroundTransparency = 1,
							ClipsDescendants = true,
							Size = UDim2.fromScale(0.749779, 1),
						},
					}, {
						TopBar = (not isRootPage) and c(TopBar, {
							Title = topBarTitle,
							Color = topBarColor,
							OnBack = goBack,
						}) or nil,

						Content = c(Pane, {
							ClassName = "Frame",
							Native = {
								BackgroundTransparency = 1,
								Position = contentPos,
								Size = contentSize,
							},
						}, {
							ActivePage = activeContent,
						}),
					}),
				}),
			}),
		}),

		Close = c(Pane, {
			ClassName = "ImageButton",
			OnClick = closeMenu,
			Native = {
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Image = "http://www.roblox.com/asset/?id=13438417284",
				Position = UDim2.fromScale(0.936353, -0.0389084),
				Size = UDim2.fromScale(0.094, 0.144),
				ZIndex = 2,
			},
		}, {
			Inner = c(Pane, {
				ClassName = "ImageLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "http://www.roblox.com/asset/?id=13438418840",
					ImageColor3 = Styles.RED,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.835405, 0.835405),
					ZIndex = 2,
				},
			}),

			Label = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.744808, 0.744808),
					Text = "X",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 2,
				},
			}),
		}),

		Notepad = renderNotepad(),
	})
end

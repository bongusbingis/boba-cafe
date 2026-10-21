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

---> utility
local RankUtil = require(Shared.Utility.RankUtil)

---> styles
local Styles = require(UI.Styles)

---> constants
local DEFAULT_BAR_COLOR = Color3.fromRGB(224, 94, 88)
local MAX_ORDER_ITEMS = 3

---> private
local c = React.createElement

local function resolveItemName(orderItem: { [string]: any }): string
	local name: string = orderItem.DefaultInfo.ItemName
	if orderItem.DefaultInfo.Select then
		for variantType in orderItem.DefaultInfo.Select do
			local chosen = orderItem.CustomInfo[variantType]
			if chosen then
				name = chosen .. " " .. name
			end
		end
	end
	return name
end

local function resolveItemDescription(orderItem)
	local lines = {}
	if orderItem.DefaultInfo.RequiredSelection then
		for selType in orderItem.DefaultInfo.RequiredSelection do
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

local function validateSubmittedOrder(submittedList: { any }, expectedList: { any }): boolean
	if #submittedList ~= #expectedList then
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

---> public
return function(props: {
	Args: { any }?,
	ClosePage: (() -> ())?,
	OnClose: (() -> ())?,
})
	local npcOrderData = if props.Args
			and typeof(props.Args[1]) == "table"
			and props.Args[1].NpcId ~= nil
		then props.Args[1]
		else nil

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
	local orderItems, setOrderItems = React.useState({} :: { any })

	---> barista info (local player, loaded async)
	local staffRole, setStaffRole = React.useState("Staff")
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

		task.spawn(function()
			local role = RankUtil:GetRoleAsync(localPlayer)
			setStaffRole(role)
		end)
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
		topBarTitle = reqSelQueue[reqSelIdx].name
	elseif page == "SizeOptions" then
		topBarTitle = "Add to Order"
	end

	---> navigation handlers

	local function goBack()
		if page == "ItemSelect" then
			setPage("CategorySelect")
		elseif page == "RequiredSelection" then
			if reqSelIdx > 1 then
				setReqSelIdx(reqSelIdx - 1)
			else
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
				setSelItemKey(nil)
				setCustomInfo({})
				setPage("ItemSelect")
			end
		end
	end

	local function cancelItemConfig()
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
		local queue = {}
		if item.RequiredSelection then
			for typeName, options in item.RequiredSelection do
				table.insert(queue, { name = typeName, options = launchOptions(typeName, options) })
			end
		end

		setSelItemKey(itemKey)
		setCustomInfo(info)
		setReqSelQueue(queue)
		setReqSelIdx(1)
		setPage(if #queue > 0 then "RequiredSelection" else "SizeOptions")
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

	local function onAddToOrder()
		if not selCategory or not selItemKey then
			return
		end
		local item = FoodTable[selCategory :: string].Items[selItemKey :: string]

		local newOrder = table.clone(orderItems)
		table.insert(newOrder, {
			Category = selCategory,
			Item = selItemKey,
			DefaultInfo = item,
			CustomInfo = customInfo,
		})
		setOrderItems(newOrder)

		setSelItemKey(nil)
		setCustomInfo({})
		setReqSelQueue({})
		setReqSelIdx(1)
		setPage("CategorySelect")
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

		if npcOrderData ~= nil then
			local matches = validateSubmittedOrder(request, npcOrderData.Orders)
			if not matches then
				Knit.GetController("DialogController"):Notify({
					Title = "Order Error",
					Description = "That doesn't match what the customer asked for!",
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
		local noteText = if npcOrderData ~= nil then (npcOrderData.RequestedText or "") else ""
		return c(Pane, {
			ClassName = "Frame",
			CornerRadius = UDim.new(0, 12),
			Stroke = {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = 5,
			},
			Native = {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.fromRGB(51, 51, 51),
				BackgroundTransparency = 0,
				ClipsDescendants = true,
				Position = UDim2.fromScale(-0.42, 0.5),
				Size = UDim2.fromScale(0.4, 0.911841),
				Visible = notepadVisible,
			},
		}, {
			Title = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.00462942, 0.0193365),
					Size = UDim2.fromScale(0.991803, 0.0662963),
					Text = "Notepad",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				},
			}),

			Description = c(Pane, {
				ClassName = "TextLabel",
				Native = {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.00462942, 0.0994445),
					Size = UDim2.fromScale(0.991803, 0.0662963),
					Text = if npcOrderData ~= nil
						then "Customer's requested order:"
						else "Use this page to take notes on customer orders.",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				},
			}),

			Notes = c(Pane, {
				ClassName = "Frame",
				Native = {
					Active = true,
					AutoLocalize = false,
					BackgroundColor3 = Color3.fromRGB(74, 74, 74),
					BackgroundTransparency = 0,
					Position = UDim2.fromScale(0.0409836, 0.179426),
					Selectable = true,
					Size = UDim2.fromScale(0.913934, 0.790031),
				},
			}, {
				TextBox = c("TextBox", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					AutoLocalize = false,
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json"),
					Position = UDim2.fromScale(0.502242, 0.497798),
					Size = UDim2.fromScale(0.932735, 0.941467),
					Text = noteText,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				}, {
					UITextSizeConstraint = c("UITextSizeConstraint", { MaxTextSize = 25 }),
				}),
			}),

			CloseBtn = c(Pane, {
				ClassName = "TextButton",
				OnClick = function()
					setNotepadVisible(false)
				end,
				Native = {
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Position = UDim2.fromScale(0.877049, 0.00828708),
					Size = UDim2.fromScale(0.118852, 0.0607716),
					Text = ">",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				},
			}),
		})
	end

	---> main render
	return c(Pane, {
		ClassName = "Frame",
		AspectRatio = 1.53648,
		Native = {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.6),
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
						StaffRole = staffRole,
						ResolveItemName = resolveItemName,
						ResolveItemDescription = resolveItemDescription,
						OnOrderItemRemoved = onOrderItemRemoved,
						OnSubmit = submitOrder,
						NpcOrderText = npcOrderData and npcOrderData.RequestedText,
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

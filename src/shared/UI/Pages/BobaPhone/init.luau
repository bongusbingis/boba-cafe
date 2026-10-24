--[[
	BobaPhone (REVIVAL-001 BOBA-PHONE)
	Faithful React port of the legacy Boba ordering app
	(StarterGui.UIArchive.OldUI.BobaPhone, Boba app only: no Home screen, no
	other app, no Home/History tabs). Look is legacy (DEC-043 Q20=A): legacy
	fonts, colours, asset ids and sizing; no docs/STYLE.md tokens.

	Data comes from Shared.Ordering.Menu filtered to launch items; the request
	is { Category, Item, CustomInfo } x1-3 sent via OrderService:CreateOrder,
	and the result is shown with DialogController:Toast. No level reads.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local Knit = require(Packages.Knit)

local FoodService = require(Shared.Ordering.Menu)
local BuildOrderRequest = require(script.BuildOrderRequest)
local ViewportModel = require(UI.Components.ViewportModel)

local c = React.createElement
local localPlayer = Players.LocalPlayer

local FoodTable = BuildOrderRequest.launchFoodTable(FoodService)

---> legacy look (dumped from __REACT_SCREEN lines 549-1380 + PhoneMenuController)
local ACCENT = Color3.fromRGB(255, 104, 5)
local TEXT_DARK = Color3.fromRGB(48, 48, 48)
local TEXT_MUTED = Color3.fromRGB(128, 128, 128)
local TOGGLE_GREY = Color3.fromRGB(204, 204, 204)
local ROW_GREY = Color3.fromRGB(179, 179, 179)
local ROW_TOP = Color3.fromRGB(153, 153, 153)
local CENTER_GREY = Color3.fromRGB(228, 228, 228)
local TAB_GREEN = Color3.fromRGB(96, 202, 94)
local PLACE_GREEN = Color3.fromRGB(92, 194, 90)
local ADD_GREEN = Color3.fromRGB(136, 170, 122)
local CARD_VIEWPORT_FALLBACK = Color3.fromRGB(136, 170, 122)

local ORDER_ICON = "http://www.roblox.com/asset/?id=8267206830"
local ROW_DECO = "http://www.roblox.com/asset/?id=5150079965"
local REMOVE_X = "http://www.roblox.com/asset/?id=5017723314"
local ROUND_BG = "http://www.roblox.com/asset/?id=5150445362"
local SCROLL_BAR = "http://www.roblox.com/asset/?id=4983877983"
local SCROLL_MID = "http://www.roblox.com/asset/?id=1912796145"

local CLOCKED_IN_ATTRIBUTE = "ClockedIn"

local function gotham(weight)
	return Font.new("rbxasset://fonts/families/GothamSSm.json", weight)
end

local FREDOKA = Font.new("rbxasset://fonts/families/FredokaOne.json")

-- "Medium Custom Boba": each Select value prefixes the item name (legacy AddToOrder).
local function resolveItemName(orderItem)
	local name = orderItem.DefaultInfo.ItemName or orderItem.Item
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

-- "Syrup Flavor: Taro" lines for required picks, "+ Iced" / "- NO Sugar" for
-- toggles that differ from the default (legacy AddToOrder).
local function resolveItemDescription(orderItem)
	local lines = {}
	if orderItem.DefaultInfo.RequiredSelection then
		for selType in orderItem.DefaultInfo.RequiredSelection do
			table.insert(lines, selType .. ": " .. tostring(orderItem.CustomInfo[selType]))
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

local function getOrderedCategories()
	local categories = {}
	for categoryKey, data in FoodTable do
		table.insert(categories, {
			key = categoryKey,
			layoutOrder = data.LayoutOrder or 0,
			color = data.Color,
		})
	end
	table.sort(categories, function(a, b)
		if a.layoutOrder == b.layoutOrder then
			return a.key < b.key
		end
		return a.layoutOrder < b.layoutOrder
	end)
	return categories
end

local function getOrderedItems(categoryKey)
	local categoryData = FoodTable[categoryKey]
	if not categoryData then
		return {}
	end
	local items = {}
	for itemKey, itemData in categoryData.Items do
		table.insert(items, {
			key = itemKey,
			label = itemData.ItemName or itemKey,
			layoutOrder = itemData.LayoutOrder or 0,
			data = itemData,
		})
	end
	table.sort(items, function(a, b)
		if a.layoutOrder == b.layoutOrder then
			return a.key < b.key
		end
		return a.layoutOrder < b.layoutOrder
	end)
	return items
end

local function toast(text: string)
	local ok, err = pcall(function()
		Knit.GetController("DialogController"):Toast(text)
	end)
	if not ok then
		warn("[BobaPhone] Toast failed: " .. tostring(err))
	end
end

return function(props: { Open: boolean, OnClose: (() -> ())? })
	local categories = getOrderedCategories()

	local selectedTab, setSelectedTab = React.useState("Menu")
	local orderItems, setOrderItems = React.useState({})

	local popupVisible, setPopupVisible = React.useState(false)
	local selectedCategory, setSelectedCategory = React.useState(nil)
	local selectedItemKey, setSelectedItemKey = React.useState(nil)
	local customInfo, setCustomInfo = React.useState({})
	local requiredQueue, setRequiredQueue = React.useState({})
	local selectListFor, setSelectListFor = React.useState(nil)

	local submitMessage, setSubmitMessage = React.useState("")
	local submitFailed, setSubmitFailed = React.useState(false)
	local submitting, setSubmitting = React.useState(false)

	local smallScreen, setSmallScreen = React.useState(false)
	local bodyRef = React.useRef(nil)

	local activeItemData = if selectedCategory and selectedItemKey
		then FoodTable[selectedCategory].Items[selectedItemKey]
		else nil
	local orderCount = #orderItems

	-- Closing resets popup state but keeps the cart (legacy kept it until placed).
	React.useEffect(function()
		if not props.Open then
			setPopupVisible(false)
			setSelectedCategory(nil)
			setSelectedItemKey(nil)
			setCustomInfo({})
			setRequiredQueue({})
			setSelectListFor(nil)
		end
	end, { props.Open })

	-- ModifyDeviceSize: touch + AbsoluteSize.Y < 500 moves the phone
	-- right/bottom. The ScreenGui is the body Frame's parent at runtime.
	React.useEffect(function()
		local body = bodyRef.current
		local gui = if body then (body :: Frame).Parent else nil
		local connection: RBXScriptConnection? = nil
		local function update()
			local size = if gui and (gui :: Instance):IsA("ScreenGui")
				then ((gui :: Instance) :: ScreenGui).AbsoluteSize
				else Vector2.new(0, 0)
			setSmallScreen(UserInputService.TouchEnabled and size.Y >= 1 and size.Y < 500)
		end
		update()
		if gui and (gui :: Instance):IsA("ScreenGui") then
			connection = ((gui :: Instance) :: ScreenGui):GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
		end
		return function()
			if connection then
				connection:Disconnect()
			end
		end
	end, {})

	local function closePopup()
		setPopupVisible(false)
		setSelectedCategory(nil)
		setSelectedItemKey(nil)
		setCustomInfo({})
		setRequiredQueue({})
		setSelectListFor(nil)
	end

	local function onSelectItem(categoryKey: string, itemKey: string)
		local categoryData = FoodTable[categoryKey]
		local item = if categoryData then categoryData.Items[itemKey] else nil
		if not item then
			return
		end
		setSelectedCategory(categoryKey)
		setSelectedItemKey(itemKey)
		setCustomInfo(BuildOrderRequest.defaultInfoFor(item))
		setRequiredQueue(BuildOrderRequest.requiredQueueFor(FoodService, item))
		setSelectListFor(nil)
		setPopupVisible(true)
		setSubmitMessage("")
		setSubmitFailed(false)
	end

	local function requiredDone(info, queue): boolean
		for _, step in queue do
			if info[step.name] == nil then
				return false
			end
		end
		return true
	end

	local function onRequiredOptionPicked(stepName: string, optionKey: string)
		local nextInfo = table.clone(customInfo)
		nextInfo[stepName] = optionKey
		setCustomInfo(nextInfo)
		setSelectListFor(nil)
	end

	local function onAddItem()
		if not activeItemData or not selectedCategory or not selectedItemKey then
			return
		end
		if not requiredDone(customInfo, requiredQueue) then
			return
		end
		local nextOrder = BuildOrderRequest.appendCapped(
			orderItems,
			BuildOrderRequest.cartEntry(selectedCategory, selectedItemKey, activeItemData, customInfo)
		)
		if #nextOrder == #orderItems then
			return
		end
		setOrderItems(nextOrder)
		setSelectedTab("My Order")
		closePopup()
	end

	local function onRemoveOrderItem(index: number)
		local nextOrder = table.clone(orderItems)
		table.remove(nextOrder, index)
		setOrderItems(nextOrder)
	end

	local isSubmitting = React.useRef(false)

	local function onSubmitOrder()
		if isSubmitting.current or submitting or #orderItems == 0 then
			return
		end
		-- R3: the phone and ClockedIn are mutually exclusive; the grant is
		-- removed server-side, and this guard keeps a stale phone from ordering.
		if localPlayer and localPlayer:GetAttribute(CLOCKED_IN_ATTRIBUTE) == true then
			setSubmitFailed(true)
			setSubmitMessage("Clock out to order with the phone.")
			toast("Clock out to order with the phone.")
			return
		end
		if not RunService:IsRunning() then
			setSubmitFailed(false)
			setSubmitMessage("Preview mode: order not submitted.")
			return
		end
		local request = BuildOrderRequest.toRequest(orderItems)
		local customerId = if localPlayer then localPlayer.UserId else 0
		isSubmitting.current = true
		setSubmitting(true)
		task.spawn(function()
			-- Knit client methods return a Promise; expect() yields and throws on rejection.
			local ok, result = pcall(function()
				return Knit.GetService("OrderService"):CreateOrder(customerId, request):expect()
			end)
			isSubmitting.current = false
			setSubmitting(false)
			if not ok then
				warn("[BobaPhone] failed to submit order", result)
			end
			local success = ok and typeof(result) == "table" and result.Success == true
			local message = if ok and typeof(result) == "table" then result.Message else nil
			setSubmitFailed(not success)
			if success then
				toast(message or "Order sent.")
				setSubmitMessage(message or "Order sent.")
				setOrderItems({})
				setSelectedTab("Menu")
			else
				toast(message or "Unable to submit order.")
				setSubmitMessage(message or "Unable to submit order.")
			end
		end)
	end
	local function renderItemCard(categoryKey: string, categoryColor: Color3?, item): any
		local viewModel = if item.data.View then item.data.View.Model else nil
		local picture = if viewModel ~= nil
			then c("Frame", {
				BackgroundColor3 = categoryColor or CARD_VIEWPORT_FALLBACK,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Size = UDim2.fromOffset(84, 84),
			}, {
				UICorner = c("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
				View = c(ViewportModel, {
					Model = viewModel,
					Size = UDim2.fromScale(1, 1),
				}),
			})
			else c("Frame", {
				BackgroundColor3 = categoryColor or CARD_VIEWPORT_FALLBACK,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(84, 84),
			}, {
				UICorner = c("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			})
		return c("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = item.layoutOrder,
			Size = UDim2.fromOffset(96, 122),
			Text = "",
			[React.Event.Activated] = function()
				onSelectItem(categoryKey, item.key)
			end,
		}, {
			Picture = picture,
			Name = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = FREDOKA,
				Position = UDim2.fromOffset(0, 86),
				Size = UDim2.fromOffset(96, 36),
				Text = item.label,
				TextColor3 = TEXT_DARK,
				TextScaled = true,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
			}, {
				UILimit = c("UITextSizeConstraint", {
					MaxTextSize = 12,
				}),
			}),
		})
	end

	local function renderMenuTab(): any
		local rows = {
			UIListLayout = c("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for _, category in categories do
			local cards: { [string]: any } = {
				UIListLayout = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 5),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}
			for _, item in getOrderedItems(category.key) do
				cards["Item_" .. item.key] = renderItemCard(category.key, category.color, item)
			end
			rows["Category_" .. category.key] = c("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = category.layoutOrder,
				Size = UDim2.new(1, 0, 0, 168),
			}, {
				Title = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = gotham(Enum.FontWeight.Bold),
					Position = UDim2.fromScale(0.05, 0),
					Size = UDim2.new(0.9, 0, 0, 24),
					Text = category.key,
					TextColor3 = TEXT_DARK,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Scroller = c("ScrollingFrame", {
					Active = true,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromScale(2, 0),
					MidImage = SCROLL_MID,
					Position = UDim2.fromOffset(0, 26),
					ScrollBarImageColor3 = Color3.new(),
					ScrollBarImageTransparency = 0.75,
					ScrollBarThickness = 10,
					Size = UDim2.new(1, 0, 0, 126),
					TopImage = "",
					BottomImage = "",
				}, cards),
				Deco = c("ImageLabel", {
					BackgroundTransparency = 1,
					Image = ROW_DECO,
					ImageColor3 = Color3.new(),
					ImageTransparency = 0.75,
					Position = UDim2.new(0.05, 0, 0, 154),
					Size = UDim2.new(0.9, 0, 0, 6),
				}),
			})
		end

		rows["BottomSpacer"] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 9999,
			Size = UDim2.new(1, 0, 0, 30),
			Visible = true,
		})

		return c("ScrollingFrame", {
			Active = true,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			ElasticBehavior = Enum.ElasticBehavior.Never,
			ScrollBarImageColor3 = Color3.new(),
			ScrollBarThickness = 0,
			Size = UDim2.fromScale(1, 1),
		}, rows)
	end

	local function renderOrderTab(): any
		local orderChildren: { [string]: any } = {
			UIListLayout = c("UIListLayout", {
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for i, orderItem in orderItems do
			local description = resolveItemDescription(orderItem)
			local infoLines = {}
			local lineIndex = 0
			for line in string.gmatch(description, "[^\n]+") do
				lineIndex += 1
				infoLines["Info_" .. lineIndex] = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = gotham(Enum.FontWeight.Bold),
					LayoutOrder = lineIndex,
					Size = UDim2.new(1, 0, 0, 14),
					Text = line,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			end
			orderChildren["OrderItem_" .. i] = c("Frame", {
				BackgroundColor3 = ROW_GREY,
				BorderSizePixel = 0,
				LayoutOrder = i,
				Size = UDim2.new(1, -5, 0, 20 + lineIndex * 16),
			}, {
				UIListLayout = c("UIListLayout", {
					Padding = UDim.new(0, 3),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Top = c("Frame", {
					BackgroundColor3 = ROW_TOP,
					BorderSizePixel = 0,
					LayoutOrder = 0,
					Size = UDim2.new(1, 0, 0, 20),
				}, {
					ItemName = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = gotham(Enum.FontWeight.Bold),
						Position = UDim2.fromOffset(2, 2),
						Size = UDim2.new(1, -24, 1, -4),
						Text = resolveItemName(orderItem),
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					RemoveItem = c("ImageButton", {
						BackgroundTransparency = 1,
						Image = REMOVE_X,
						Position = UDim2.new(1, -17, 0, 3),
						Size = UDim2.fromOffset(14, 14),
						[React.Event.Activated] = function()
							onRemoveOrderItem(i)
						end,
					}),
				}),
				Lines = c("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = 1,
				}, infoLines),
			})
		end
		if orderCount == 0 then
			orderChildren.Empty = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = gotham(Enum.FontWeight.Medium),
				LayoutOrder = 1,
				Size = UDim2.new(1, -10, 0, 40),
				Text = "No items yet. Add drinks or snacks from Menu.",
				TextColor3 = TEXT_MUTED,
				TextScaled = true,
			})
		else
			orderChildren["BottomSpacer"] = c("Frame", {
				BackgroundTransparency = 1,
				LayoutOrder = 9999,
				Size = UDim2.new(1, 0, 0, 30),
				Visible = true,
			})
		end
		local canPlace = orderCount > 0 and not submitting
		return c("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, {
			OrderFrame = c("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				BottomImage = SCROLL_BAR,
				MidImage = SCROLL_BAR,
				Position = UDim2.fromOffset(5, 5),
				ScrollBarImageColor3 = Color3.fromRGB(179, 179, 179),
				ScrollBarThickness = 5,
				Size = UDim2.new(1, -10, 0.84, -10),
				TopImage = SCROLL_BAR,
				VerticalScrollBarInset = Enum.ScrollBarInset.Always,
			}, orderChildren),
			PlaceButton = c("ImageButton", {
				AutoButtonColor = canPlace,
				BackgroundColor3 = if canPlace then PLACE_GREEN else TOGGLE_GREY,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 5, 0.9, 0),
				Size = UDim2.new(1, -10, 0.1, -5),
				[React.Event.Activated] = function()
					onSubmitOrder()
				end,
			}, {
				UICorner = c("UICorner", {
					CornerRadius = UDim.new(0.2, 0),
				}),
				Label = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = FREDOKA,
					Position = UDim2.fromScale(0.1, 0.1),
					Size = UDim2.fromScale(0.8, 0.8),
					Text = "Place Order",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				}),
			}),
			Footer = submitMessage ~= "" and c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = gotham(Enum.FontWeight.Medium),
				Position = UDim2.new(0, 5, 0.845, 0),
				Size = UDim2.new(1, -10, 0, 16),
				Text = submitMessage,
				TextColor3 = if submitFailed then Color3.fromRGB(190, 70, 70) else TAB_GREEN,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}) or nil,
		})
	end
	local function renderSelectRow(selectType: string, options: { string }): any
		local buttons: { [string]: any } = {
			UIListLayout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for i, option in options do
			local isSelected = customInfo[selectType] == option
			buttons["Option_" .. i] = c("ImageButton", {
				AutoButtonColor = false,
				BackgroundColor3 = if isSelected then ACCENT else Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				LayoutOrder = i,
				Size = UDim2.fromScale(1 / #options, 1),
				[React.Event.Activated] = function()
					local nextInfo = table.clone(customInfo)
					nextInfo[selectType] = option
					setCustomInfo(nextInfo)
				end,
			}, {
				Choice = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = gotham(Enum.FontWeight.Heavy),
					Position = UDim2.fromScale(0.1, 0.2),
					Size = UDim2.fromScale(0.8, 0.6),
					Text = option,
					TextColor3 = if isSelected then Color3.new(1, 1, 1) else ACCENT,
					TextScaled = true,
				}),
			})
			if i ~= #options then
				buttons["Bar_" .. i] = c("Frame", {
					BackgroundColor3 = TOGGLE_GREY,
					BorderSizePixel = 0,
					LayoutOrder = i + 0.5,
					Position = UDim2.new(1 / #options * i, -1, 0, 0),
					Size = UDim2.new(0, 2, 1, 0),
				})
			end
		end
		return c("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 80),
		}, {
			Title = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = gotham(Enum.FontWeight.Heavy),
				Position = UDim2.fromOffset(5, 20),
				Size = UDim2.new(1, -10, 0, 20),
				Text = selectType,
				TextColor3 = ACCENT,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Selector = c("ImageLabel", {
				BackgroundTransparency = 1,
				Image = ROUND_BG,
				ImageColor3 = Color3.new(),
				ImageTransparency = 0.8,
				Position = UDim2.fromOffset(0, 40),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.new(1, 0, 0, 40),
				SliceCenter = Rect.new(256, 256, 256, 256),
				SliceScale = 0.02,
			}, {
				Inner = c("Frame", {
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(5, 5),
					Size = UDim2.new(1, -10, 1, -10),
				}, {
					Choices = c("Frame", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.fromScale(1, 1),
					}, buttons),
				}),
			}),
		})
	end

	local function renderRequiredRow(step: { name: string, options: { [string]: any } }): any
		local chosen = customInfo[step.name]
		local chosenData = if chosen then step.options[chosen] else nil
		return c("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 80),
		}, {
			Title = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = gotham(Enum.FontWeight.Heavy),
				Position = UDim2.fromOffset(5, 20),
				Size = UDim2.new(1, -10, 0, 20),
				Text = step.name,
				TextColor3 = ACCENT,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Pick = c("ImageButton", {
				BackgroundTransparency = 1,
				Image = ROUND_BG,
				ImageColor3 = Color3.new(),
				ImageTransparency = 0.8,
				Position = UDim2.fromOffset(0, 40),
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.new(1, 0, 0, 40),
				SliceCenter = Rect.new(256, 256, 256, 256),
				SliceScale = 0.02,
				[React.Event.Activated] = function()
					setSelectListFor(step.name)
				end,
			}, {
				Inner = c("Frame", {
					BackgroundColor3 = if chosenData and chosenData.Color
						then chosenData.Color
						else Color3.new(1, 1, 1),
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(5, 5),
					Size = UDim2.new(1, -10, 1, -10),
				}, {
					Choice = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = gotham(Enum.FontWeight.Heavy),
						Position = UDim2.fromScale(0.1, 0.1),
						Size = UDim2.fromScale(0.8, 0.8),
						Text = chosen or "Pick one",
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 12,
						TextStrokeTransparency = 0,
						TextWrapped = true,
					}),
				}),
			}),
		})
	end

	local function renderOptionRow(optionType: string): any
		local enabled = customInfo[optionType] == true
		return c("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 30),
		}, {
			Toggle = c("ImageButton", {
				BackgroundTransparency = 1,
				Image = ROUND_BG,
				ImageColor3 = Color3.new(),
				ImageTransparency = 0.8,
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.fromOffset(30, 30),
				SliceCenter = Rect.new(256, 256, 256, 256),
				SliceScale = 0.02,
				[React.Event.Activated] = function()
					local nextInfo = table.clone(customInfo)
					nextInfo[optionType] = not nextInfo[optionType]
					setCustomInfo(nextInfo)
				end,
			}, {
				Inner = c("Frame", {
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(5, 5),
					Size = UDim2.new(1, -10, 1, -10),
				}, {
					Dot = c("Frame", {
						BackgroundColor3 = if enabled then ACCENT else TOGGLE_GREY,
						BorderSizePixel = 0,
						Position = UDim2.fromOffset(2, 2),
						Size = UDim2.new(1, -4, 1, -4),
					}),
				}),
			}),
			Title = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = gotham(Enum.FontWeight.Heavy),
				Position = UDim2.new(0, 35, 0.2, 0),
				Size = UDim2.new(1, -40, 0.6, 0),
				Text = optionType,
				TextColor3 = ACCENT,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})
	end

	local function renderItemOptions(): any
		local rows: { [string]: any } = {
			UIListLayout = c("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		local order = 0
		if activeItemData.Select then
			-- Sorted for determinism (legacy iterated in hash order).
			local names = {}
			for selectType in activeItemData.Select do
				table.insert(names, selectType)
			end
			table.sort(names)
			for _, selectType in names do
				order += 1
				rows["Select_" .. selectType] = c("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, 80),
				}, {
					Row = renderSelectRow(selectType, activeItemData.Select[selectType]),
				})
			end
		end
		if requiredQueue then
			for _, step in requiredQueue do
				order += 1
				rows["Required_" .. step.name] = c("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, 80),
				}, {
					Row = renderRequiredRow(step),
				})
			end
		end
		if activeItemData.Options then
			local names = {}
			for optionType in activeItemData.Options do
				table.insert(names, optionType)
			end
			table.sort(names)
			for _, optionType in names do
				order += 1
				rows["Option_" .. optionType] = c("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, 30),
				}, {
					Row = renderOptionRow(optionType),
				})
			end
		end
		rows["BottomSpacer"] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 9999,
			Size = UDim2.new(1, 0, 0, 20),
			Visible = true,
		})
		local done = requiredDone(customInfo, requiredQueue)
		return c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.5),
		}, {
			UICorner = c("UICorner", {
				CornerRadius = UDim.new(0.05, 0),
			}),
			Scroller = c("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				BottomImage = SCROLL_BAR,
				MidImage = SCROLL_BAR,
				Position = UDim2.fromOffset(5, 5),
				ScrollBarImageColor3 = TOGGLE_GREY,
				ScrollBarThickness = 5,
				Size = UDim2.new(1, -10, 0.85, -10),
				TopImage = SCROLL_BAR,
				VerticalScrollBarInset = Enum.ScrollBarInset.Always,
			}, rows),
			AddButton = c("ImageButton", {
				AutoButtonColor = done,
				BackgroundColor3 = if done then ADD_GREEN else TOGGLE_GREY,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 5, 0.85, 0),
				Size = UDim2.new(1, -10, 0.15, -5),
				[React.Event.Activated] = function()
					onAddItem()
				end,
			}, {
				UICorner = c("UICorner", {
					CornerRadius = UDim.new(0.2, 0),
				}),
				Label = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = FREDOKA,
					Position = UDim2.fromScale(0.1, 0.1),
					Size = UDim2.fromScale(0.8, 0.8),
					Text = if done then "Add Item" else "Pick an option",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
				}),
			}),
		})
	end

	local function renderSelectList(stepName: string): any
		local step = nil
		for _, candidate in requiredQueue do
			if candidate.name == stepName then
				step = candidate
				break
			end
		end
		if not step then
			return nil
		end
		local names = {}
		for optionKey in step.options do
			table.insert(names, optionKey)
		end
		table.sort(names, function(a, b)
			local la = if step.options[a].LayoutOrder then step.options[a].LayoutOrder else 0
			local lb = if step.options[b].LayoutOrder then step.options[b].LayoutOrder else 0
			if la == lb then
				return a < b
			end
			return la < lb
		end)
		local buttons: { [string]: any } = {
			UIListLayout = c("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}
		for i, optionKey in names do
			local optionData = step.options[optionKey]
			buttons["Choice_" .. optionKey] = c("ImageButton", {
				BackgroundTransparency = 1,
				Image = ROUND_BG,
				ImageColor3 = Color3.new(),
				ImageTransparency = 0.8,
				LayoutOrder = i,
				ScaleType = Enum.ScaleType.Slice,
				Size = UDim2.new(1, 0, 0, 40),
				SliceCenter = Rect.new(256, 256, 256, 256),
				SliceScale = 0.02,
				[React.Event.Activated] = function()
					onRequiredOptionPicked(stepName, optionKey)
				end,
			}, {
				Inner = c("Frame", {
					BackgroundColor3 = if optionData.Color then optionData.Color else Color3.new(1, 1, 1),
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(5, 5),
					Size = UDim2.new(1, -10, 1, -10),
				}, {
					Label = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = gotham(Enum.FontWeight.Heavy),
						Position = UDim2.fromScale(0.1, 0.1),
						Size = UDim2.fromScale(0.8, 0.8),
						Text = optionKey,
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 12,
						TextStrokeTransparency = 0,
						TextWrapped = true,
					}),
				}),
			})
		end
		buttons["BottomSpacer"] = c("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 9999,
			Size = UDim2.new(1, 0, 0, 20),
			Visible = true,
		})
		return c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.5),
		}, {
			UICorner = c("UICorner", {
				CornerRadius = UDim.new(0.05, 0),
			}),
			Scroller = c("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				BottomImage = SCROLL_BAR,
				MidImage = SCROLL_BAR,
				Position = UDim2.fromOffset(5, 5),
				ScrollBarImageColor3 = TOGGLE_GREY,
				ScrollBarThickness = 5,
				Size = UDim2.new(1, -10, 1, -10),
				TopImage = SCROLL_BAR,
				VerticalScrollBarInset = Enum.ScrollBarInset.Always,
			}, buttons),
		})
	end
	local popup: any = nil
	if popupVisible and activeItemData then
		local onBackdrop = if selectListFor ~= nil
			then function()
				setSelectListFor(nil)
			end
			else function()
				closePopup()
			end
		popup = c("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 2,
			[React.Event.Activated] = onBackdrop,
		}, {
			UICorner = c("UICorner", {
				CornerRadius = UDim.new(0.11, 0),
			}),
			Page = if selectListFor ~= nil then renderSelectList(selectListFor) else renderItemOptions(),
		})
	end

	local menuActive = selectedTab == "Menu"
	local bodyAnchor = if smallScreen then Vector2.new(1, 1) else Vector2.new(0.5, 1)
	local bodyPosition = if smallScreen then UDim2.new(1, -50, 1, -5) else UDim2.new(0.5, 0, 1, -70)
	local bodySize = if smallScreen then UDim2.new(0.5, 0, 1, 26) else UDim2.new(0.3, 0, 1, -20)

	if not props.Open then
		return nil
	end

	return c("Frame", {
		ref = bodyRef,
		AnchorPoint = bodyAnchor,
		BackgroundColor3 = Color3.new(),
		BorderSizePixel = 0,
		Position = bodyPosition,
		Size = bodySize,
	}, {
		UIAspectRatioConstraint = c("UIAspectRatioConstraint", {
			AspectRatio = 0.5,
		}),
		UISizeConstraint = c("UISizeConstraint", {
			MaxSize = Vector2.new(math.huge, 500),
		}),
		UICorner = c("UICorner", {
			CornerRadius = UDim.new(0.125, 0),
		}),

		TopFrame = c("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 0.063),
			ZIndex = 2,
		}, {
			Notch = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.new(),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(0.5, 1),
			}, {
				UICorner = c("UICorner", {
					CornerRadius = UDim.new(0.5, 0),
				}),
				Bottom = c("Frame", {
					BackgroundColor3 = Color3.new(),
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 0.5),
				}),
			}),
		}),

		Screen = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -16, 1, -16),
		}, {
			UICorner = c("UICorner", {
				CornerRadius = UDim.new(0.11, 0),
			}),

			Boba = c("ImageLabel", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ScaleType = Enum.ScaleType.Crop,
				Size = UDim2.fromScale(1, 1),
				TileSize = UDim2.fromOffset(300, 300),
			}, {
				UICorner = c("UICorner", {
					CornerRadius = UDim.new(0.11, 0),
				}),

				Top = c("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.fromScale(1, 0.2),
				}, {
					Title = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = gotham(Enum.FontWeight.Medium),
						Position = UDim2.fromScale(0.05, 0.4),
						Size = UDim2.fromScale(0.9, 0.25),
						Text = "Order",
						TextColor3 = Color3.new(),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					Buttons = c("Frame", {
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0, 0.8),
						Size = UDim2.fromScale(1, 0.2),
					}, {
						UIListLayout = c("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						MenuTab = c("ImageButton", {
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							LayoutOrder = 1,
							Size = UDim2.fromScale(0.5, 1),
							[React.Event.Activated] = function()
								setSelectedTab("Menu")
								setSubmitMessage("")
								setSubmitFailed(false)
							end,
						}, {
							Label = c("TextLabel", {
								BackgroundTransparency = 1,
								FontFace = gotham(Enum.FontWeight.Medium),
								Size = UDim2.fromScale(1, 0.8),
								Text = "Menu",
								TextColor3 = if menuActive then TEXT_DARK else TEXT_MUTED,
								TextScaled = true,
							}),
							Underline = c("Frame", {
								BackgroundColor3 = TAB_GREEN,
								BorderSizePixel = 0,
								Position = UDim2.fromScale(0, 0.85),
								Size = UDim2.fromScale(1, 0.15),
								Visible = menuActive,
							}),
						}),
						MyOrderTab = c("ImageButton", {
							BackgroundTransparency = 1,
							BorderSizePixel = 0,
							LayoutOrder = 2,
							Size = UDim2.fromScale(0.5, 1),
							[React.Event.Activated] = function()
								setSelectedTab("My Order")
								setSubmitMessage("")
								setSubmitFailed(false)
							end,
						}, {
							Label = c("TextLabel", {
								BackgroundTransparency = 1,
								FontFace = gotham(Enum.FontWeight.Medium),
								Size = UDim2.fromScale(1, 0.8),
								Text = "My Order",
								TextColor3 = if menuActive then TEXT_MUTED else TEXT_DARK,
								TextScaled = true,
							}),
							Underline = c("Frame", {
								BackgroundColor3 = TAB_GREEN,
								BorderSizePixel = 0,
								Position = UDim2.fromScale(0, 0.85),
								Size = UDim2.fromScale(1, 0.15),
								Visible = not menuActive,
							}),
						}),
					}),
				}),

				Center = c("Frame", {
					BackgroundColor3 = CENTER_GREY,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 0.2),
					Size = UDim2.fromScale(1, 0.65),
				}, {
					Page = if menuActive then renderMenuTab() else renderOrderTab(),
				}),

				Bottom = c("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 0.85),
					Size = UDim2.fromScale(1, 0.1),
				}, {
					OrderTab = c("Frame", {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, 0),
						Size = UDim2.fromScale(0.2, 1),
					}, {
						Icon = c("ImageLabel", {
							AnchorPoint = Vector2.new(0.5, 0),
							BackgroundTransparency = 1,
							Image = ORDER_ICON,
							ImageColor3 = TAB_GREEN,
							Position = UDim2.fromScale(0.5, 0.1),
							Size = UDim2.fromScale(0.6, 0.6),
						}),
						Label = c("TextLabel", {
							BackgroundTransparency = 1,
							FontFace = gotham(Enum.FontWeight.Bold),
							Position = UDim2.fromScale(0, 0.72),
							Size = UDim2.fromScale(1, 0.25),
							Text = "Order",
							TextColor3 = TAB_GREEN,
							TextScaled = true,
						}),
					}),
				}),

				PopUp = popup,
			}),
		}),
	})
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local React = require(Packages.React)
local Knit = require(Packages.Knit)

local FoodService = require(Shared.Ordering.Menu)
local FoodTable = FoodService.FoodTable

local c = React.createElement
local localPlayer = Players.LocalPlayer or { UserId = 0 }

local MAX_ORDER_ITEMS = 3
local ACTIVE_GREEN = Color3.fromRGB(96, 202, 94)
local BG_LIGHT = Color3.fromRGB(242, 242, 242)
local BG_CENTER = Color3.fromRGB(228, 228, 228)
local TEXT_DARK = Color3.fromRGB(48, 48, 48)
local TEXT_MUTED = Color3.fromRGB(128, 128, 128)
local DEEP_GREEN = Color3.fromRGB(18, 73, 63)
local SURFACE_WHITE = Color3.fromRGB(250, 250, 250)
local STROKE_SOFT = Color3.fromRGB(198, 198, 198)

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

local function resolveItemDescription(orderItem)
	local lines = {}

	if orderItem.DefaultInfo.RequiredSelection then
		for selType in orderItem.DefaultInfo.RequiredSelection do
			local chosen = orderItem.CustomInfo[selType] or "?"
			table.insert(lines, selType .. ": " .. chosen)
		end
	end

	if orderItem.DefaultInfo.Options then
		for optType, defaultValue in orderItem.DefaultInfo.Options do
			local chosen = orderItem.CustomInfo[optType]
			if chosen ~= defaultValue then
				table.insert(lines, if chosen then ("+ " .. optType) else ("- No " .. optType))
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
			color = itemData.Color or categoryData.Color,
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

return function(props)
	props = props or {}

	local categories = getOrderedCategories()
	local initialCategory = nil

	local selectedTab, setSelectedTab = React.useState("Menu")
	local selectedCategory, setSelectedCategory = React.useState(initialCategory)
	local menuStage, setMenuStage = React.useState("Categories")
	local orderItems, setOrderItems = React.useState({})

	local popupVisible, setPopupVisible = React.useState(false)
	local selectedItemKey, setSelectedItemKey = React.useState(nil)
	local customInfo, setCustomInfo = React.useState({})
	local requiredQueue, setRequiredQueue = React.useState({})
	local requiredIndex, setRequiredIndex = React.useState(1)

	local submitMessage, setSubmitMessage = React.useState("")

	local activeItemData = if selectedCategory and selectedItemKey
		then FoodTable[selectedCategory].Items[selectedItemKey]
		else nil
	local activeReqStep = requiredQueue[requiredIndex]
	local orderCount = #orderItems

	local function closePopup()
		setPopupVisible(false)
		setSelectedItemKey(nil)
		setCustomInfo({})
		setRequiredQueue({})
		setRequiredIndex(1)
	end

	local function onSelectItem(itemKey)
		if not selectedCategory then
			return
		end

		local item = FoodTable[selectedCategory].Items[itemKey]
		if not item then
			return
		end

		local info = {}
		if item.Select then
			for selectType, options in item.Select do
				info[selectType] = options[1]
			end
		end
		if item.Options then
			for optionType, defaultValue in item.Options do
				info[optionType] = defaultValue
			end
		end

		local queue = {}
		if item.RequiredSelection then
			for typeName, options in item.RequiredSelection do
				table.insert(queue, {
					name = typeName,
					options = options,
				})
			end
		end

		setSelectedItemKey(itemKey)
		setCustomInfo(info)
		setRequiredQueue(queue)
		setRequiredIndex(1)
		setPopupVisible(true)
		setSubmitMessage("")
	end

	local function onRequiredOptionPicked(optionKey)
		if not activeReqStep then
			return
		end

		local nextInfo = table.clone(customInfo)
		nextInfo[activeReqStep.name] = optionKey
		setCustomInfo(nextInfo)

		if requiredIndex < #requiredQueue then
			setRequiredIndex(requiredIndex + 1)
		end
	end

	local function onAddItem()
		if not activeItemData or orderCount >= MAX_ORDER_ITEMS then
			return
		end

		local nextOrder = table.clone(orderItems)
		table.insert(nextOrder, {
			Item = selectedItemKey,
			DefaultInfo = activeItemData,
			CustomInfo = customInfo,
		})
		setOrderItems(nextOrder)
		setSelectedTab("My Order")
		closePopup()
	end

	local function onRemoveOrderItem(index)
		local nextOrder = table.clone(orderItems)
		table.remove(nextOrder, index)
		setOrderItems(nextOrder)
	end

	local function onSubmitOrder()
		if #orderItems == 0 then
			return
		end

		local customerId = props.CustomerId or localPlayer.UserId
		if RunService:IsRunning() then
			local ok, err = pcall(function()
				Knit.GetService("OrderService"):CreateOrder(customerId, orderItems)
			end)
			if ok then
				setSubmitMessage("Order sent.")
				setOrderItems({})
				setSelectedTab("Menu")
				if props.OnSubmitted then
					props.OnSubmitted()
				end
			else
				setSubmitMessage("Unable to submit order.")
				warn("[MobileOrder] failed to submit order", err)
			end
		else
			setSubmitMessage("Preview mode: order not submitted.")
		end
	end

	local function renderMenuTab()
		local items = if selectedCategory then getOrderedItems(selectedCategory) else {}

		if menuStage == "Categories" then
			local categoryChildren = {
				UIListLayout = c("UIListLayout", {
					Padding = UDim.new(0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}

			for i, category in ipairs(categories) do
				categoryChildren["Category_" .. category.key] = c("TextButton", {
					AutoButtonColor = false,
					BackgroundColor3 = SURFACE_WHITE,
					BorderSizePixel = 0,
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 78),
					Text = "",
					[React.Event.Activated] = function()
						setSelectedCategory(category.key)
						setMenuStage("Items")
					end,
				}, {
					UICorner = c("UICorner", {
						CornerRadius = UDim.new(0, 12),
					}),
					UIStroke = c("UIStroke", {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = STROKE_SOFT,
						Thickness = 1,
					}),
					Badge = c("Frame", {
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = DEEP_GREEN,
						BorderSizePixel = 0,
						Position = UDim2.new(0, 10, 0.5, 0),
						Size = UDim2.fromOffset(56, 56),
					}, {
						UICorner = c("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),
						Tint = c("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = category.color or ACTIVE_GREEN,
							BackgroundTransparency = 0.05,
							BorderSizePixel = 0,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromScale(0.68, 0.68),
						}, {
							UICorner = c("UICorner", {
								CornerRadius = UDim.new(1, 0),
							}),
						}),
					}),
					Title = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
						Position = UDim2.fromOffset(76, 0),
						Size = UDim2.new(1, -110, 1, 0),
						Text = category.key,
						TextColor3 = TEXT_DARK,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					Chevron = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
						Position = UDim2.new(1, -28, 0, 0),
						Size = UDim2.fromOffset(18, 78),
						Text = ">",
						TextColor3 = TEXT_MUTED,
						TextScaled = true,
					}),
				})
			end

			return c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}, {
				CategoryList = c("ScrollingFrame", {
					Active = true,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.new(),
					Position = UDim2.fromScale(0.03, 0.03),
					ScrollBarImageColor3 = Color3.new(),
					ScrollBarThickness = 5,
					Size = UDim2.fromScale(0.94, 0.94),
				}, categoryChildren),
			})
		end

		local itemChildren = {
			UIGridLayout = c("UIGridLayout", {
				CellPadding = UDim2.fromOffset(10, 12),
				CellSize = UDim2.fromOffset(112, 154),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}

		for i, item in ipairs(items) do
			itemChildren["Item_" .. item.key] = c("TextButton", {
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = i,
				Text = "",
				[React.Event.Activated] = function()
					onSelectItem(item.key)
				end,
			}, {
				Circle = c("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = DEEP_GREEN,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromOffset(112, 112),
				}, {
					UICorner = c("UICorner", {
						CornerRadius = UDim.new(1, 0),
					}),
					Tint = c("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = item.color or ACTIVE_GREEN,
						BackgroundTransparency = 0.05,
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.72, 0.72),
					}, {
						UICorner = c("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),
					}),
				}),
				Label = c("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
					Position = UDim2.fromScale(0.5, 0.76),
					Size = UDim2.fromOffset(108, 44),
					Text = item.label,
					TextColor3 = TEXT_DARK,
					TextScaled = true,
					TextWrapped = true,
				}),
			})
		end

		if #items == 0 then
			itemChildren.Empty = c("TextLabel", {
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 50),
				Text = "No items in this category.",
				TextColor3 = TEXT_MUTED,
				TextScaled = true,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
			})
		end

		return c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Header = c("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0.12),
			}, {
				Back = c("TextButton", {
					AutoButtonColor = false,
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
					Position = UDim2.fromOffset(0, 0),
					Size = UDim2.fromOffset(30, 34),
					Text = "<",
					TextColor3 = TEXT_MUTED,
					TextScaled = true,
					[React.Event.Activated] = function()
						setMenuStage("Categories")
					end,
				}),
				Title = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
					Position = UDim2.fromOffset(36, 0),
					Size = UDim2.new(1, -36, 0, 34),
					Text = selectedCategory or "Category",
					TextColor3 = TEXT_DARK,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				SubTitle = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
					Position = UDim2.fromOffset(0, 34),
					Size = UDim2.new(1, 0, 0, 22),
					Text = "See all " .. tostring(#items),
					TextColor3 = ACTIVE_GREEN,
					TextScaled = true,
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
			}),

			Items = c("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				Position = UDim2.fromScale(0.03, 0.13),
				ScrollBarImageColor3 = Color3.new(),
				ScrollBarThickness = 5,
				Size = UDim2.fromScale(0.94, 0.84),
			}, itemChildren),
		})
	end

	local function renderOrderTab()
		local orderChildren = {
			UIListLayout = c("UIListLayout", {
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}

		for i, item in ipairs(orderItems) do
			orderChildren["OrderItem_" .. i] = c("Frame", {
				BackgroundColor3 = Color3.fromRGB(179, 179, 179),
				BorderSizePixel = 0,
				LayoutOrder = i,
				Size = UDim2.new(1, -5, 0, 88),
			}, {
				UICorner = c("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),

				Top = c("Frame", {
					BackgroundColor3 = Color3.fromRGB(153, 153, 153),
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, 28),
				}, {
					UICorner = c("UICorner", {
						CornerRadius = UDim.new(0, 8),
					}),

					Title = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
						Position = UDim2.fromOffset(8, 0),
						Size = UDim2.new(1, -40, 1, 0),
						Text = resolveItemName(item),
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),

					Remove = c("TextButton", {
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
						Position = UDim2.new(1, -30, 0, 4),
						Size = UDim2.fromOffset(24, 20),
						Text = "x",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						[React.Event.Activated] = function()
							onRemoveOrderItem(i)
						end,
					}),
				}),

				Details = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
					Position = UDim2.fromOffset(8, 32),
					Size = UDim2.new(1, -16, 1, -36),
					Text = resolveItemDescription(item),
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
				}),
			})
		end

		if orderCount == 0 then
			orderChildren.Empty = c("TextLabel", {
				BackgroundTransparency = 1,
				LayoutOrder = 1,
				Size = UDim2.new(1, -10, 0, 40),
				Text = "No items yet. Add drinks or snacks from Menu.",
				TextColor3 = TEXT_MUTED,
				TextScaled = true,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
			})
		end

		return c("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			OrderFrame = c("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				Position = UDim2.fromOffset(5, 5),
				ScrollBarImageColor3 = Color3.fromRGB(179, 179, 179),
				ScrollBarThickness = 5,
				Size = UDim2.new(1, -10, 0.82, -5),
			}, orderChildren),

			Submit = c("TextButton", {
				AutoButtonColor = orderCount > 0,
				BackgroundColor3 = if orderCount > 0 then ACTIVE_GREEN else Color3.fromRGB(140, 140, 140),
				BorderSizePixel = 0,
				Position = UDim2.new(0, 5, 0.83, 0),
				Size = UDim2.new(1, -10, 0.17, -5),
				Text = "Place Order",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				[React.Event.Activated] = function()
					onSubmitOrder()
				end,
			}, {
				UICorner = c("UICorner", {
					CornerRadius = UDim.new(0, 10),
				}),
			}),
		})
	end

	local popupRequiredDone = requiredIndex >= #requiredQueue
	local popupChildren = {
		Overlay = c("TextButton", {
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			[React.Event.Activated] = function()
				closePopup()
			end,
		}),
	}

	if popupVisible and activeItemData then
		local reqCount = #requiredQueue
		local chosenReq = 0
		if reqCount > 0 then
			for _, reqStep in ipairs(requiredQueue) do
				if customInfo[reqStep.name] ~= nil then
					chosenReq += 1
				end
			end
		end

		local popupBodyChildren = {
			UIListLayout = c("UIListLayout", {
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			Title = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 30),
				Text = activeItemData.ItemName,
				TextColor3 = TEXT_DARK,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),

			Progress = reqCount > 0 and c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 20),
				Text = "Customization " .. tostring(chosenReq) .. "/" .. tostring(reqCount),
				TextColor3 = ACTIVE_GREEN,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}) or nil,
		}

		if activeReqStep and not popupRequiredDone then
			popupBodyChildren.RequiredTitle = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 22),
				Text = activeReqStep.name,
				TextColor3 = TEXT_DARK,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			})

			local reqButtons = {
				UIListLayout = c("UIListLayout", {
					Padding = UDim.new(0, 5),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}

			local order = 0
			for optionKey, optionData in activeReqStep.options do
				order += 1
				reqButtons["Req_" .. optionKey] = c("TextButton", {
					AutoButtonColor = false,
					BackgroundColor3 = SURFACE_WHITE,
					BorderSizePixel = 0,
					LayoutOrder = order,
					Size = UDim2.new(1, 0, 0, 42),
					Text = "",
					TextColor3 = TEXT_DARK,
					TextScaled = true,
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
					[React.Event.Activated] = function()
						onRequiredOptionPicked(optionKey)
					end,
				}, {
					UICorner = c("UICorner", {
						CornerRadius = UDim.new(0, 10),
					}),
					UIStroke = c("UIStroke", {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = STROKE_SOFT,
						Thickness = 1,
					}),
					Dot = c("Frame", {
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = optionData.Color or ACTIVE_GREEN,
						BorderSizePixel = 0,
						Position = UDim2.new(0, 10, 0.5, 0),
						Size = UDim2.fromOffset(16, 16),
					}, {
						UICorner = c("UICorner", {
							CornerRadius = UDim.new(1, 0),
						}),
					}),
					Label = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
						Position = UDim2.fromOffset(34, 0),
						Size = UDim2.new(1, -42, 1, 0),
						Text = optionKey,
						TextColor3 = TEXT_DARK,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				})
			end

			popupBodyChildren.RequiredOptions = c("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				LayoutOrder = 4,
				ScrollBarImageColor3 = Color3.fromRGB(204, 204, 204),
				ScrollBarThickness = 5,
				Size = UDim2.new(1, 0, 1, -90),
			}, reqButtons)
		else
			local layoutOrder = 3
			if activeItemData.Select then
				for selectType, options in activeItemData.Select do
					popupBodyChildren["SelectTitle_" .. selectType] = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
						LayoutOrder = layoutOrder,
						Size = UDim2.new(1, 0, 0, 20),
						Text = selectType,
						TextColor3 = TEXT_DARK,
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,
					})
					layoutOrder += 1

					local selectButtons = {
						UIListLayout = c("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 4),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
					}

					for i, option in ipairs(options) do
						local isSelected = customInfo[selectType] == option
						selectButtons[option] = c("TextButton", {
							AutoButtonColor = false,
							BackgroundColor3 = if isSelected then DEEP_GREEN else Color3.fromRGB(239, 239, 239),
							BorderSizePixel = 0,
							LayoutOrder = i,
							Size = UDim2.new(1 / #options, -3, 1, 0),
							Text = option,
							TextColor3 = if isSelected then Color3.new(1, 1, 1) else TEXT_DARK,
							TextScaled = true,
							FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
							[React.Event.Activated] = function()
								local nextInfo = table.clone(customInfo)
								nextInfo[selectType] = option
								setCustomInfo(nextInfo)
							end,
						}, {
							UICorner = c("UICorner", {
								CornerRadius = UDim.new(1, 0),
							}),
							UIStroke = c("UIStroke", {
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
								Color = if isSelected then DEEP_GREEN else STROKE_SOFT,
								Thickness = 1,
							}),
						})
					end

					popupBodyChildren["Select_" .. selectType] = c("Frame", {
						BackgroundTransparency = 1,
						LayoutOrder = layoutOrder,
						Size = UDim2.new(1, 0, 0, 32),
					}, selectButtons)
					layoutOrder += 1
				end
			end

			if activeItemData.Options then
				for optionType in activeItemData.Options do
					local enabled = customInfo[optionType] == true
					popupBodyChildren["Opt_" .. optionType] = c("TextButton", {
						AutoButtonColor = false,
						BackgroundColor3 = SURFACE_WHITE,
						BorderSizePixel = 0,
						LayoutOrder = layoutOrder,
						Size = UDim2.new(1, 0, 0, 32),
						Text = "",
						TextColor3 = TEXT_DARK,
						TextScaled = true,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
						[React.Event.Activated] = function()
							local nextInfo = table.clone(customInfo)
							nextInfo[optionType] = not nextInfo[optionType]
							setCustomInfo(nextInfo)
						end,
					}, {
						UICorner = c("UICorner", {
							CornerRadius = UDim.new(0, 8),
						}),
						UIStroke = c("UIStroke", {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = STROKE_SOFT,
							Thickness = 1,
						}),
						Check = c("Frame", {
							AnchorPoint = Vector2.new(0, 0.5),
							BackgroundColor3 = if enabled then ACTIVE_GREEN else Color3.fromRGB(230, 230, 230),
							BorderSizePixel = 0,
							Position = UDim2.new(0, 10, 0.5, 0),
							Size = UDim2.fromOffset(14, 14),
						}, {
							UICorner = c("UICorner", {
								CornerRadius = UDim.new(0, 4),
							}),
						}),
						Label = c("TextLabel", {
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
							Position = UDim2.fromOffset(30, 0),
							Size = UDim2.new(1, -36, 1, 0),
							Text = optionType,
							TextColor3 = TEXT_DARK,
							TextScaled = true,
							TextXAlignment = Enum.TextXAlignment.Left,
						}),
					})
					layoutOrder += 1
				end
			end
		end

		popupChildren.ItemOptions = c("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(246, 246, 246),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.62),
			Visible = true,
			ZIndex = 3,
		}, {
			UICorner = c("UICorner", {
				CornerRadius = UDim.new(0, 16),
			}),
			UIStroke = c("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = STROKE_SOFT,
				Thickness = 1,
			}),

			Body = c("ScrollingFrame", {
				Active = true,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				Position = UDim2.fromOffset(10, 10),
				ScrollBarImageColor3 = Color3.fromRGB(204, 204, 204),
				ScrollBarThickness = 5,
				Size = UDim2.new(1, -20, 0.84, -12),
				ZIndex = 3,
			}, popupBodyChildren),

			Button = c("TextButton", {
				AutoButtonColor = true,
				BackgroundColor3 = if activeReqStep and not popupRequiredDone then Color3.fromRGB(100, 160, 255) else DEEP_GREEN,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 10, 0.86, 0),
				Size = UDim2.new(1, -20, 0.14, -10),
				Text = if activeReqStep and not popupRequiredDone then "Select an option" else "Add Item",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
				ZIndex = 3,
				[React.Event.Activated] = function()
					if activeReqStep and not popupRequiredDone then
						return
					end
					onAddItem()
				end,
			}, {
				UICorner = c("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),

			Close = c("TextButton", {
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
				Position = UDim2.new(1, -30, 0, 4),
				Size = UDim2.fromOffset(22, 22),
				Text = "x",
				TextColor3 = TEXT_MUTED,
				TextScaled = true,
				ZIndex = 4,
				[React.Event.Activated] = function()
					closePopup()
				end,
			}),
		})
	end

	return c("Frame", {
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.new(),
		BorderSizePixel = 0,
		Position = props.Position or UDim2.new(0.5, 0, 1, -70),
		Size = props.Size or UDim2.new(0.3, 0, 1, -20),
	}, {
		UIAspectRatioConstraint = c("UIAspectRatioConstraint", {
			AspectRatio = 0.5,
		}),

		UISizeConstraint = c("UISizeConstraint", {
			MaxSize = props.MaxSize or Vector2.new(math.huge, 500),
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
			BackgroundColor3 = BG_LIGHT,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -16, 1, -16),
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
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
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

					MyOrder = c("TextButton", {
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.fromScale(0.5, 1),
						Text = "",
						[React.Event.Activated] = function()
							setSelectedTab("My Order")
							setSubmitMessage("")
						end,
					}, {
						Label = c("TextLabel", {
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
							Size = UDim2.fromScale(1, 0.8),
							Text = "My Order",
							TextColor3 = if selectedTab == "My Order" then TEXT_DARK else TEXT_MUTED,
							TextScaled = true,
						}),

						Underline = c("Frame", {
							BackgroundColor3 = ACTIVE_GREEN,
							BorderSizePixel = 0,
							Position = UDim2.fromScale(0, 0.85),
							Size = UDim2.fromScale(1, 0.15),
							Visible = selectedTab == "My Order",
						}),
					}),

					Menu = c("TextButton", {
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.fromScale(0.5, 1),
						Text = "",
						[React.Event.Activated] = function()
							setSelectedTab("Menu")
							setSubmitMessage("")
						end,
					}, {
						Label = c("TextLabel", {
							BackgroundTransparency = 1,
							FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
							Size = UDim2.fromScale(1, 0.8),
							Text = "Menu",
							TextColor3 = if selectedTab == "Menu" then TEXT_DARK else TEXT_MUTED,
							TextScaled = true,
						}),

						Underline = c("Frame", {
							BackgroundColor3 = ACTIVE_GREEN,
							BorderSizePixel = 0,
							Position = UDim2.fromScale(0, 0.85),
							Size = UDim2.fromScale(1, 0.15),
							Visible = selectedTab == "Menu",
						}),
					}),
				}),
			}),

			Center = c("Frame", {
				BackgroundColor3 = BG_CENTER,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 0.2),
				Size = UDim2.fromScale(1, 0.65),
			}, {
				ActivePage = if selectedTab == "Menu" then renderMenuTab() else renderOrderTab(),
			}),

			Bottom = c("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 0.85),
				Size = UDim2.fromScale(1, 0.1),
			}, {
				OrderButton = c("Frame", {
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.fromScale(0.5, 0),
					Size = UDim2.fromScale(0.2, 1),
				}, {
					Icon = c("ImageLabel", {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Image = "http://www.roblox.com/asset/?id=8267206830",
						ImageColor3 = ACTIVE_GREEN,
						Position = UDim2.fromScale(0.5, 0.1),
						Size = UDim2.fromScale(0.6, 0.6),
					}),
					Label = c("TextLabel", {
						BackgroundTransparency = 1,
						FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
						Position = UDim2.fromScale(0, 0.72),
						Size = UDim2.fromScale(1, 0.25),
						Text = "Order",
						TextColor3 = ACTIVE_GREEN,
						TextScaled = true,
					}),
				}),
			}),

			HomeBar = c("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(186, 186, 186),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.985),
				Size = UDim2.fromScale(0.5, 0.012),
			}, {
				UICorner = c("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),

			SubmitMessage = submitMessage ~= "" and c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
				Position = UDim2.fromScale(0.03, 0.81),
				Size = UDim2.fromScale(0.94, 0.03),
				Text = submitMessage,
				TextColor3 = if string.find(submitMessage, "Unable") then Color3.fromRGB(190, 70, 70) else ACTIVE_GREEN,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}) or nil,

			Popup = c("Frame", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				Visible = popupVisible,
				ZIndex = 2,
			}, popupChildren),
		}),
	})
end

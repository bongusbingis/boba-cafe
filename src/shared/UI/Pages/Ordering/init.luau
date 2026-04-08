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
local PlayerSelectPage = require(script.PlayerSelectPage)

---> data
local FoodService = require(Shared.Ordering.Menu)
local FoodTable = FoodService.FoodTable

---> utility
local RankUtil = require(Shared.Utility.RankUtil)

---> styles
local Styles = require(UI.Styles)

---> constants
local DEFAULT_BAR_COLOR = Color3.fromRGB(224, 94, 88)
local MAX_ORDER_ITEMS = 3
local CAN_SELF_ORDER = true

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

---> public
return function(props: {
	ClosePage: (() -> ())?,
	OnClose: (() -> ())?,
})
	local function closeMenu()
		if props.ClosePage then
			props.ClosePage()
		elseif props.OnClose then
			props.OnClose()
		end
	end

	---> page routing
	-- Pages: "CategorySelect" | "ItemSelect" | "RequiredSelection" | "SizeOptions" | "PlayerSelect"
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
	local staffAvatarUrl, setStaffAvatarUrl = React.useState(
		"rbxasset://textures/ui/GuiImagePlaceholder.png"
	)

	---> nearby players (populated when entering PlayerSelect)
	local nearbyPlayers, setNearbyPlayers = React.useState({} :: { Player })

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

	---> refresh nearby players when entering PlayerSelect
	React.useEffect(function()
		if page ~= "PlayerSelect" then return end

		local localPlayer = Players.LocalPlayer
		local localChar = localPlayer.Character
		local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")

		local nearby = {}
		for _, p in Players:GetPlayers() do
			if p == localPlayer and not CAN_SELF_ORDER then continue end
			local char = p.Character
			if not char then continue end
			local root = char:FindFirstChild("HumanoidRootPart")
			if not root then continue end
			if not localRoot or (localRoot.Position - root.Position).Magnitude < 15 then
				table.insert(nearby, p)
			end
		end
		setNearbyPlayers(nearby)
	end, { page } :: { any })

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
	elseif page == "PlayerSelect" then
		topBarTitle = "Select Customer"
		topBarColor = DEFAULT_BAR_COLOR
	end

	---> navigation handlers

	local function goBack()
		if page == "ItemSelect" or page == "PlayerSelect" then
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
				table.insert(queue, { name = typeName, options = options })
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
		if not selCategory or not selItemKey then return end
		local item = FoodTable[selCategory :: string].Items[selItemKey :: string]

		local newOrder = table.clone(orderItems)
		table.insert(newOrder, {
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

	local function onPlayerSelected(player: Player)
		if RunService:IsRunning() then
			Knit.GetService("OrderService"):CreateOrder(player.UserId, orderItems)
		end
		setOrderItems({})
		setSelCategory(nil)
		setPage("CategorySelect")
		closeMenu()
	end

	local cardSize = usePx()(70)
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
		elseif page == "ItemSelect"
		then c(ItemPage, {
			SelectedCategory = selCategory,
			FoodTable = FoodTable,
			OnItemSelected = onItemSelected,
		})
		elseif page == "RequiredSelection"
		then c(RequiredSelectionPage, {
			Step = currentReqStep,
			CustomInfo = customInfo,
			OnOptionPicked = onReqSelOptionPicked,
		})
		elseif page == "SizeOptions"
		then c(SizeOptionsPage, {
			Item = activeItem,
			CustomInfo = customInfo,
			OrderItemsCount = #orderItems,
			MaxOrderItems = MAX_ORDER_ITEMS,
			OnCustomInfoChanged = setCustomInfo,
			OnAddToOrder = onAddToOrder,
			OnCancel = cancelItemConfig,
		})
		elseif page == "PlayerSelect"
		then c(PlayerSelectPage, {
			NearbyPlayers = nearbyPlayers,
			OnPlayerSelected = onPlayerSelected,
		})
		else nil

	local function renderNotepad()
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
				Visible = false,
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
					Text = "Use this page to take notes on customer orders.",
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
					Text = "",
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
			Position = UDim2.fromScale(0.5, 0.875),
			Size = UDim2.fromScale(0.75, 0.75),
		},
	}, {
		UISizeConstraint = c("UISizeConstraint", {
			MaxSize = Vector2.new(610, math.huge),
			MinSize = Vector2.new(390, math.huge),
		}),

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
						OnSubmit = function()
							setPage("PlayerSelect")
						end,
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

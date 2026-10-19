--[[
    Component: OrderTicket
    Description: Prototype HUD overlay that shows the active order a staff member
                 has claimed. Renders nothing when the player has no active order.

    Intentionally unstyled — use plain colours only so this can be skinned later.
    Build onto this component: animations, asset images, scroll for large orders, etc.

    Listens to OrderController via GoodSignal connections wired in useEffect so
    connections are always cleaned up when the component unmounts.

    Shows the RecipeCard step list (M1.5b) when the order resolves to a spec.
--]]

--!nonstrict

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")
local Ordering = Shared:WaitForChild("Ordering")

local Knit = require(Packages.Knit)
local React = require(Packages.React)

local Styles = require(UI.Styles)
local OrderSpec = require(Ordering.OrderSpec)
local RecipeCard = require(script.Parent.RecipeCard)

---> Private

local c = React.createElement

-- Builds the display name for an order item, prepending any selected variant.
local function resolveItemName(item: { [string]: any }): string
	local name: string = item.DefaultInfo.ItemName
	if item.DefaultInfo.Select then
		for variantType in item.DefaultInfo.Select do
			local chosen = item.CustomInfo[variantType]
			if chosen then
				name = chosen .. " " .. name
			end
		end
	end
	return name
end

-- Returns a flat list of customisation strings for an item (e.g. "+ Boba", "- NO Ice").
local function resolveCustomisations(item: { [string]: any }): { string }
	local lines: { string } = {}

	if item.DefaultInfo.RequiredSelection then
		for selType in item.DefaultInfo.RequiredSelection do
			table.insert(lines, selType .. ": " .. (item.CustomInfo[selType] or "?"))
		end
	end

	if item.DefaultInfo.Options then
		for optType, defaultValue in item.DefaultInfo.Options do
			local chosen = item.CustomInfo[optType]
			if chosen ~= defaultValue then
				table.insert(lines, if chosen then ("+ " .. optType) else ("- NO " .. optType))
			end
		end
	end

	return lines
end

---> Spec resolution

-- Uses KitchenGuidance.ResolveSpec (never a second resolver). KitchenGuidance
-- lives under StarterPlayerScripts, so it is required lazily here at runtime
-- instead of at the top of the file. Any failure resolves to nil, which
-- renders no card (the ticket stays as today).
local function resolveOrderSpec(order)
	if typeof(order) ~= "table" then
		return nil
	end
	local player = Players.LocalPlayer
	if player == nil then
		return nil
	end
	local ok, guidance = pcall(function()
		local playerScripts = player:WaitForChild("PlayerScripts", 5)
		if playerScripts == nil then
			return nil
		end
		local client = playerScripts:WaitForChild("Client", 5)
		if client == nil then
			return nil
		end
		local modules = client:WaitForChild("Modules", 5)
		if modules == nil then
			return nil
		end
		return require(modules:WaitForChild("KitchenGuidance", 5))
	end)
	if not ok or guidance == nil then
		return nil
	end
	local okSpec, result = pcall(guidance.ResolveSpec, order, OrderSpec.FromOrderItem)
	if not okSpec then
		return nil
	end
	return result
end

---> Item Row

-- Renders a single order item: its name and any customisation lines beneath it.
local function ItemRow(props: { item: { [string]: any }, layoutOrder: number })
	local item = props.item
	local name = resolveItemName(item)
	local customisations = resolveCustomisations(item)

	local customisationElements = {}
	for i, line in customisations do
		customisationElements["Custom_" .. i] = c("TextLabel", {
			LayoutOrder = i,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.new(1, -8, 0, 14),
			Text = line,
			TextColor3 = Styles.GRAY,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	return c("Frame", {
		LayoutOrder = props.layoutOrder,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Styles.OFFWHITE,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
	}, {
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = c("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),

		ItemName = c("TextLabel", {
			LayoutOrder = 0,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.new(1, -8, 0, 18),
			Text = name,
			TextColor3 = Styles.GREEN_DEEP,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		Customisations = next(customisationElements) and c(
			"Frame",
			{
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
			},
			(function()
				-- table.unpack only works on integer-keyed tables; merge into a single
				-- dict so React receives all children regardless of key type.
				local children = table.clone(customisationElements)
				children.Layout = c("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 1),
					SortOrder = Enum.SortOrder.LayoutOrder,
				})
				return children
			end)()
		) or nil,
	})
end

---> OrderTicket

return function(props: { stacked: boolean?, slot: number?, layoutOrder: number? })
	-- slot 2 is the second NPC ticket (level 5+): label and patience only.
	local isSecond = props.slot == 2
	local order, setOrder = React.useState(nil :: { any }?)
	local readyNode, setReadyNode = React.useState(nil :: Instance?)
	local spec, setSpec = React.useState(nil)
	local toolAttrs, setToolAttrs = React.useState(nil :: { [string]: any }?)
	local toolInst, setToolInst = React.useState(nil :: Instance?)
	local patience, setPatience = React.useState(nil :: number?)
	local character, setCharacter =
		React.useState(if Players.LocalPlayer ~= nil then Players.LocalPlayer.Character else nil)
	-- Phones start collapsed to the header line; a tap on the header toggles.
	local canCollapse = UserInputService.TouchEnabled
	local collapsed, setCollapsed = React.useState(canCollapse)

	if RunService:IsRunning() then
		React.useEffect(function()
			local controller = Knit.GetController("OrderController")

			-- Snapshot current state on mount so the ticket is correct even if
			-- signals fired before this component rendered.
			if isSecond then
				setOrder(controller.Tickets[2])
			else
				setOrder(controller.CurrentOrder)
				setSpec(resolveOrderSpec(controller.CurrentOrder))
			end
			setReadyNode(controller.ReadyNode)
			if Players.LocalPlayer ~= nil then
				setCharacter(Players.LocalPlayer.Character)
			end

			local connOrder = if isSecond
				then controller.TicketsChanged:Connect(function(tickets)
					setOrder(tickets[2])
				end)
				else controller.OrderChanged:Connect(function(newOrder: { any }?)
					setOrder(newOrder)
					setSpec(resolveOrderSpec(newOrder))
				end)

			local connReady = controller.ReadyNodeChanged:Connect(function(node: Instance?)
				setReadyNode(node)
			end)

			local connChar = nil
			if Players.LocalPlayer ~= nil then
				connChar = Players.LocalPlayer.CharacterAdded:Connect(function(newCharacter: Model)
					setCharacter(newCharacter)
				end)
			end

			return function()
				connOrder:Disconnect()
				connReady:Disconnect()
				if connChar ~= nil then
					connChar:Disconnect()
				end
			end
		end, {})

		-- Live patience fraction of an NPC ticket (PatienceEnd is server time). Quantised
		-- so React only re-renders when the bar visibly moves; nil hides the bar.
		React.useEffect(function()
			local patienceEnd = if order ~= nil then order.PatienceEnd else nil
			local patienceTotal = if order ~= nil then order.PatienceTotal else nil
			if typeof(patienceEnd) ~= "number" or typeof(patienceTotal) ~= "number" or patienceTotal <= 0 then
				setPatience(nil)
				return
			end
			local conn = RunService.Heartbeat:Connect(function()
				local fraction = math.clamp((patienceEnd - workspace:GetServerTimeNow()) / patienceTotal, 0, 1)
				setPatience(math.floor(fraction * 200) / 200)
			end)
			return function()
				conn:Disconnect()
			end
		end, { order })

		-- Tracks the equipped tool: ChildAdded/ChildRemoved on the character
		-- plus AttributeChanged on the tool itself. Every change snapshots
		-- synchronously, so the card recomputes well within 0.2 s.
		React.useEffect(function()
			if character == nil then
				setToolInst(nil)
				setToolAttrs(nil)
				return
			end
			local attrConn = nil
			local function refresh()
				if attrConn ~= nil then
					attrConn:Disconnect()
					attrConn = nil
				end
				local tool = character:FindFirstChildWhichIsA("Tool")
				setToolInst(tool)
				if tool ~= nil then
					setToolAttrs(tool:GetAttributes())
					attrConn = tool.AttributeChanged:Connect(function()
						if character:FindFirstChildWhichIsA("Tool") == tool then
							setToolAttrs(tool:GetAttributes())
						end
					end)
				else
					setToolAttrs(nil)
				end
			end
			refresh()
			local connAdded = character.ChildAdded:Connect(refresh)
			local connRemoved = character.ChildRemoved:Connect(refresh)
			return function()
				connAdded:Disconnect()
				connRemoved:Disconnect()
				if attrConn ~= nil then
					attrConn:Disconnect()
				end
			end
		end, { character })
	end

	-- Nothing to show when the player has no active order
	if not order then
		return nil
	end

	-- Build one ItemRow per order item
	local itemRows = {}
	for i, item in ipairs(order) do
		if i > 1 then
			-- Thin divider between items
			itemRows["Divider_" .. i] = c("Frame", {
				LayoutOrder = (i - 1) * 2,
				BackgroundColor3 = Styles.GRAY,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 1),
			})
		end
		itemRows["Item_" .. i] = c(ItemRow, {
			LayoutOrder = (i - 1) * 2 + 1,
			item = item,
		})
	end

	-- NPC tickets are a table with a Label (not a list of items): show that label.
	if typeof(order.Label) == "string" then
		itemRows.TicketLabel = c("TextLabel", {
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Size = UDim2.new(1, 0, 0, 18),
			Text = order.Label,
			TextColor3 = Styles.GREEN_DEEP,
			TextSize = 15,
		})
	end

	-- Recipe card section: only when the order resolves to a spec with steps.
	local hasCard = not isSecond and spec ~= nil and #OrderSpec.Steps(spec) > 0
	local recipeDivider = hasCard
			and c("Frame", {
				LayoutOrder = 2,
				BackgroundColor3 = Styles.GRAY,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 1),
			})
		or nil
	local recipe = hasCard
			and c(RecipeCard, {
				layoutOrder = 3,
				spec = spec,
				attrs = toolAttrs,
				tool = toolInst,
				-- Shift text arrives with M2.
				patience = patience,
				shiftText = nil,
			})
		or nil

	-- The second ticket shows its patience bar (same colours as RecipeCard).
	local secondPatience = if isSecond and typeof(patience) == "number"
		then c("Frame", {
			LayoutOrder = 3,
			BackgroundColor3 = Styles.GRAY,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 6),
		}, {
			Fill = c("Frame", {
				BackgroundColor3 = if patience < 0.25
					then Styles.RED
					elseif patience < 0.5 then Styles.GOLD_MID
					else Styles.GREEN,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(math.clamp(patience, 0, 1), 1),
			}),
		})
		else nil

	-- "Ready for pick up" footer, shown once the order has been deposited
	local readyFooter = readyNode
			and c("Frame", {
				LayoutOrder = math.huge,
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Styles.GREEN,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
			}, {
				Padding = c("UIPadding", {
					PaddingTop = UDim.new(0, 6),
					PaddingBottom = UDim.new(0, 6),
				}),
				Label = c("TextLabel", {
					BackgroundTransparency = 1,
					FontFace = Styles.FONT_FREDOKA,
					Size = UDim2.new(1, 0, 0, 20),
					Text = "Ready for Pick Up!",
					TextColor3 = Styles.OFFWHITE,
					TextScaled = true,
				}),
			})
		or nil

	return c("Frame", {
		-- Anchored to the right side of the screen, grows upward from the bottom
		-- (stacked tickets sit in the Hud TicketStack instead).
		AnchorPoint = if props.stacked then nil else Vector2.new(1, 1),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		BorderSizePixel = 0,
		LayoutOrder = props.layoutOrder,
		Position = if props.stacked then nil else UDim2.new(0.99, 0, 0.92, 0),
		Size = if props.stacked then UDim2.fromScale(1, 0) else UDim2.new(0, 190, 0, 0),
		ZIndex = 10,
	}, {
		Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
		Stroke = c("UIStroke", {
			Color = Styles.GREEN_DIM,
			Thickness = 1,
		}),
		Layout = c("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		-- Header (a tap toggles the collapsed ticket on touch devices)
		Header = c("TextButton", {
			LayoutOrder = 0,
			Active = canCollapse,
			AutoButtonColor = canCollapse,
			BackgroundColor3 = Styles.GREEN,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 28),
			Text = "",
			[React.Event.Activated] = if canCollapse
				then function()
					setCollapsed(not collapsed)
				end
				else nil,
		}, {
			Corner = c("UICorner", { CornerRadius = UDim.new(0, 6) }),
			-- Square off the bottom corners so it blends into the body
			BottomBlocker = c("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Styles.GREEN,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 6),
			}),
			Label = c("TextLabel", {
				BackgroundTransparency = 1,
				FontFace = Styles.FONT_FREDOKA,
				Size = UDim2.fromScale(1, 1),
				Text = if isSecond then "Order Ticket 2" else "Order Ticket",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 15,
			}),
		}),

		-- Item list, recipe card and footer hide while collapsed to the header
		Items = if collapsed
			then nil
			else c(
				"Frame",
				{
					LayoutOrder = 1,
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
				},
				(function()
					local children = table.clone(itemRows)
					children.Layout = c("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					})
					return children
				end)()
			),

		Patience2 = if collapsed then nil else secondPatience,
		DividerRecipe = if collapsed then nil else recipeDivider,
		Recipe = if collapsed then nil else recipe,
		ReadyFooter = if collapsed then nil else readyFooter,
	})
end

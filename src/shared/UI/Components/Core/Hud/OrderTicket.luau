--[[
    Component: OrderTicket
    Description: Prototype HUD overlay that shows the active order a staff member
                 has claimed. Renders nothing when the player has no active order.

    Intentionally unstyled — use plain colours only so this can be skinned later.
    Build onto this component: animations, asset images, scroll for large orders, etc.

    Listens to OrderController via GoodSignal connections wired in useEffect so
    connections are always cleaned up when the component unmounts.
--]]

--!nonstrict

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local Knit = require(Packages.Knit)
local React = require(Packages.React)

local Styles = require(UI.Styles)

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

		Customisations = next(customisationElements) and c("Frame", {
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
		}, (function()
			-- table.unpack only works on integer-keyed tables; merge into a single
			-- dict so React receives all children regardless of key type.
			local children = table.clone(customisationElements)
			children.Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 1),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			return children
		end)()) or nil,
	})
end

---> OrderTicket

return function()
	local order, setOrder = React.useState(nil :: { any }?)
	local readyNode, setReadyNode = React.useState(nil :: Instance?)

	if RunService:IsRunning() then
		React.useEffect(function()
			local controller = Knit.GetController("OrderController")

			-- Snapshot current state on mount so the ticket is correct even if
			-- signals fired before this component rendered.
			setOrder(controller.CurrentOrder)
			setReadyNode(controller.ReadyNode)

			local connOrder = controller.OrderChanged:Connect(function(newOrder: { any }?)
				setOrder(newOrder)
			end)

			local connReady = controller.ReadyNodeChanged:Connect(function(node: Instance?)
				setReadyNode(node)
			end)

			return function()
				connOrder:Disconnect()
				connReady:Disconnect()
			end
		end, {})
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

	-- "Ready for pick up" footer, shown once the order has been deposited
	local readyFooter = readyNode and c("Frame", {
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
	}) or nil

	return c("Frame", {
		-- Anchored to the right side of the screen, grows upward from the bottom
		AnchorPoint = Vector2.new(1, 1),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(245, 245, 245),
		BorderSizePixel = 0,
		Position = UDim2.new(0.99, 0, 0.92, 0),
		Size = UDim2.new(0, 190, 0, 0),
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

		-- Header
		Header = c("Frame", {
			LayoutOrder = 0,
			BackgroundColor3 = Styles.GREEN,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 28),
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
				Text = "Order Ticket",
				TextColor3 = Styles.OFFWHITE,
				TextSize = 15,
			}),
		}),

		-- Item list
		Items = c("Frame", {
			LayoutOrder = 1,
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
		}, (function()
			local children = table.clone(itemRows)
			children.Layout = c("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			return children
		end)()),

		ReadyFooter = readyFooter,
	})
end

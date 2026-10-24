--[[
    Module: OrderService
    Description: Knit service managing the real-player order lifecycle — creation (Boba
                 Phone, or a barista at the counter), automatic dispatch to a clocked-in
                 barista with a free ticket slot, preparation, and customer pickup — for
                 the Ordering System. Staff Screens and Status Screens are display-only
                 boards (REVIVAL-001 ORDER-FLOW-REWORK, DEC-059).
--]]

---> Services

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

---> Dependencies

local Knit = require(Packages.Knit)
local GoodSignal = require(Packages.GoodSignal)
local OrderSpec = require(ReplicatedStorage:WaitForChild("Shared").Ordering.OrderSpec)

---> Types

type Spec = OrderSpec.OrderSpec
type Grade = OrderSpec.Grade

type Order = {
	seq: number?,
	orderNum: string,
	customer: number, -- UserId
	order: { any },
	specs: { Spec }, -- one per item in `order`, derived by the server (OrderSpec.FromOrderItem)
	grade: Grade?, -- set when the barista deposits the order
	numItems: number,
	status: string,
	preparedBy: number?, -- UserId
	statusColor: Color3,
	handoff: string?, -- "direct" (serve at the customer) or "counter" (deposit at a pick-up node)
	handoffPrompt: ProximityPrompt?, -- live while the customer is near, parked (Parent nil) otherwise
}

type CustomerOrder = {
	seq: number?,
	orderNum: string,
	customerName: string,
	numItems: number,
	status: string,
	statusColor: Color3,
	npcModel: Model?,
}

type ToolEntry = {
	Name: string,
	Tool: Tool,
}

export type CreateOrderResult = {
	Success: boolean,
	Message: string?,
}

---> Constants

local ORDERING_SYSTEM_NAME = "Ordering System"
local ORDERING_SYSTEM_TIMEOUT_SECONDS = 10
local ORDER_PICKUP_FOLDER = "OrderPickUp"
local MODEL_STORAGE_NAME = "ModelStorage"

-- Direct-handoff proximity: the ordering customer gets a serve prompt and a
-- beam while within this distance of the preparing barista; further away the
-- handoff goes through a counter pick-up node instead.
local HANDOFF_DIRECT_DISTANCE_STUDS = 25
-- Trigger range of the serve prompt on the customer (mirrors the NPC Serve check).
local HANDOFF_TRIGGER_DISTANCE_STUDS = 10
local HANDOFF_POLL_SECONDS = 0.5
local HANDOFF_PROMPT_NAME = "RealOrderHandoff"

local ORDER_DEBOUNCE_SECONDS = 5
local ORDER_MAX_ITEMS = 4
local ORDER_MIN_ITEMS = 1

local STATUS_PRIORITY = {
	["Pending Preparation"] = 0,
	["Being Prepared"] = -10_000,
	["Ready for Pick Up"] = -20_000,
}

local PICKUP_MODEL_OFFSETS = {
	CFrame.new(-0.5, -0.5, -0.5),
	CFrame.new(0.5, -0.5, 0.5),
	CFrame.new(0.5, -0.5, -0.5),
	CFrame.new(-0.5, -0.5, 0.5),
}

local COLOR_PENDING = Color3.fromRGB(140, 140, 140)
local COLOR_PREPARING = Color3.fromRGB(229, 198, 103)
local COLOR_READY = Color3.fromRGB(151, 190, 135)
local COLOR_ERROR = Color3.fromRGB(253, 102, 102)

-- Player-facing text for the reasons OrderSpec.Match / PickTools return. Display
-- only; an unknown reason is shown as is.
local REASON_TEXT = {
	Item = "Wrong item",
	Size = "Wrong size",
	Syrup = "Wrong syrup",
	Tapioca = "Wrong tapioca",
	Iced = "Wrong ice",
	Sugar = "Wrong sugar",
	Missing = "An item is missing",
}

---> Service

local OrderService = Knit.CreateService({
	Name = "OrderService",
	Client = {
		-- Fired to show or hide a pick-up node UI indicator for a specific player
		PickUpNodeVisibilityChanged = Knit.CreateSignal(),
		-- Fired to surface an error/announcement to a specific player's UI
		Announcement = Knit.CreateSignal(),
		-- Fired to the barista preparing a real order with the ordering
		-- customer's UserId (no argument clears it): the client draws a beam
		-- to them while they are in direct-handoff range.
		HandoffTargetChanged = Knit.CreateSignal(),
	},

	-- Server-only signals (RealOrderService listens)
	OrderCreated = GoodSignal.new(),
	OrderPickedUp = GoodSignal.new(), -- (customerId, baristaPlayer, grade, specs, tools, items)

	_currentOrderNum = 0 :: number,
	_orders = {} :: { Order },
	_customerOrders = {} :: { [string]: CustomerOrder },
	_statusScreens = {} :: { SurfaceGui },
	_staffScreens = {} :: { SurfaceGui },
	_pickUpAreas = {} :: { Model },
	_orderDebounces = {} :: { [number]: boolean },
	_freeSince = {} :: { [number]: number }, -- UserId -> os.clock() when last free (idle-longest dispatch)
	_handoffBeam = {} :: { [number]: number }, -- barista UserId -> customer UserId with an active direct handoff

	-- Resolved in KnitStart after all services are ready
	_statisticsService = nil :: any,
	_questService = nil :: any,
	_shiftService = nil :: any,
	-- CustomerService owns every ticket slot (NPC and real orders share them). Nil before
	-- KnitStart: then a barista holds one real order at a time.
	_customerService = nil :: any,
})

---> Private Helpers

-- ReplicatedStorage.ModelStorage holds pick-up display models. It is not authored
-- in the place, so create it on first use.
local function getModelStorage(): Instance
	local storage = ReplicatedStorage:FindFirstChild(MODEL_STORAGE_NAME)
	if not storage then
		storage = Instance.new("Folder")
		storage.Name = MODEL_STORAGE_NAME
		storage.Parent = ReplicatedStorage
	end
	return storage
end

-- Shared.Ordering.Menu is required on first order: it reads the authored
-- SelectorModels, and a problem there should stop ordering only, not KnitStart.
local foodTable: { [string]: any }? = nil
local isLaunchItem: ((category: any, item: any, customInfo: any?) -> boolean)? = nil
local menuFailed = false
local function getFoodTable(): { [string]: any }?
	if not foodTable and not menuFailed then
		local ok, menu = pcall(require, ReplicatedStorage:WaitForChild("Shared").Ordering.Menu)
		if ok and typeof(menu) == "table" and typeof(menu.FoodTable) == "table" then
			foodTable = menu.FoodTable
			if typeof(menu.IsLaunchItem) == "function" then
				isLaunchItem = menu.IsLaunchItem
			else
				-- Without the launch list nothing can be called makeable: fail closed.
				warn("[OrderService] Shared.Ordering.Menu has no IsLaunchItem; ordering is disabled.")
				foodTable = nil
				menuFailed = true
			end
		else
			menuFailed = true
			warn("[OrderService] Shared.Ordering.Menu failed to load; ordering is disabled:", menu)
		end
	end
	return foodTable
end

-- Rebuilds one client order item ({ Category, Item, CustomInfo }) from the server's
-- Menu. DefaultInfo is always the Menu definition. CustomInfo may hold only the
-- choices that item offers: each Select value is one of its listed strings, each
-- RequiredSelection value is one of its keys (both required), and each Option is
-- a boolean (missing = the Menu default). Returns the item to store with its
-- OrderSpec, or nil, nil and a reason.
local function buildOrderItem(menu: { [string]: any }, request: any): ({ [string]: any }?, Spec?, string?)
	if typeof(request) ~= "table" or typeof(request.Category) ~= "string" or typeof(request.Item) ~= "string" then
		return nil, nil, "item has no Category/Item"
	end
	local category = menu[request.Category]
	local def = category and category.Items[request.Item]
	if not def then
		return nil, nil, "unknown menu item"
	end
	local customInfo = request.CustomInfo or {}
	if typeof(customInfo) ~= "table" then
		return nil, nil, "CustomInfo is not a table"
	end

	local clean = {}
	for key, choices in def.Select or {} do
		local value = customInfo[key]
		if typeof(value) ~= "string" or not table.find(choices, value) then
			return nil, nil, "invalid " .. key
		end
		clean[key] = value
	end
	for key, choices in def.RequiredSelection or {} do
		local value = customInfo[key]
		if typeof(value) ~= "string" or choices[value] == nil then
			return nil, nil, "invalid " .. key
		end
		clean[key] = value
	end
	for key, default in def.Options or {} do
		local value = customInfo[key]
		if value == nil then
			value = default
		elseif typeof(value) ~= "boolean" then
			return nil, nil, "invalid " .. key
		end
		clean[key] = value
	end
	for key in customInfo do
		if clean[key] == nil then
			return nil, nil, "unexpected CustomInfo key"
		end
	end

	local item = { Category = request.Category, Item = request.Item, DefaultInfo = def, CustomInfo = clean }
	local spec, specReason = OrderSpec.FromOrderItem(item)
	if not spec then
		return nil, nil, "no order spec (" .. tostring(specReason) .. ")"
	end
	return item, spec, nil
end

-- Builds a display model from the non-Handle parts of a tool for placement at a
-- pick-up area. The model is auto-expired after 5 minutes via Debris.
local function createModelFromTool(tool: Tool): Model
	local model = Instance.new("Model")
	model.Parent = getModelStorage()
	Debris:AddItem(model, 300)

	for _, part in tool:GetChildren() do
		-- MeshPart is a subclass of BasePart; the single IsA check covers both.
		if part:IsA("BasePart") and part.Name ~= "Handle" then
			part:Clone().Parent = model
		end
	end

	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			desc.Anchored = true
		end
	end

	local orientation, size = model:GetBoundingBox()
	local primaryPart = Instance.new("Part")
	primaryPart.Transparency = 1
	primaryPart.CanCollide = false
	primaryPart.Anchored = true
	primaryPart.CFrame = orientation
	primaryPart.Size = size
	primaryPart.Parent = model
	model.PrimaryPart = primaryPart

	return model
end

-- Collects all Tool instances from a player's character and backpack.
local function collectTools(character: Model?, backpack: Instance?): { ToolEntry }
	local tools: { ToolEntry } = {}

	local function addFrom(container: Instance?)
		if not container then
			return
		end
		for _, item in container:GetChildren() do
			if item:IsA("Tool") then
				table.insert(tools, { Name = item.Name, Tool = item :: Tool })
			end
		end
	end

	addFrom(character)
	addFrom(backpack)
	return tools
end

-- "Wrong size, Wrong ice" for the reasons OrderSpec returns.
local function describeReasons(reasons: { string }): string
	local lines = table.create(#reasons)
	for i, reason in reasons do
		lines[i] = REASON_TEXT[reason] or reason
	end
	return table.concat(lines, ", ")
end

---> Private Methods

function OrderService:_getPlayerOrder(userId: number, status: string): Order?
	for _, order in self._orders do
		if order.status == status and order.preparedBy == userId then
			return order
		end
	end
	return nil
end

-- Baristas are players who are clocked in (ShiftService). Before KnitStart
-- resolves ShiftService, nobody counts as clocked in.
function OrderService:_isClockedIn(player: Player): boolean
	local shiftService = self._shiftService
	return shiftService ~= nil and shiftService:IsClockedIn(player) == true
end

-- Returns true while the customer has an order that has not been picked up.
function OrderService:_hasOpenOrder(customerId: number): boolean
	for _, order in self._orders do
		if order.customer == customerId then
			return true
		end
	end
	return false
end

local function isOlderOrder(a: any, b: any): boolean
	if a.seq ~= nil and b.seq ~= nil and a.seq ~= b.seq then
		return a.seq < b.seq
	end
	return a.orderNum < b.orderNum
end

-- Every order the player is preparing, oldest first.
function OrderService:_getPlayerOrders(userId: number, status: string): { Order }
	local found: { Order } = {}
	for _, order in self._orders do
		if order.status == status and order.preparedBy == userId then
			table.insert(found, order)
		end
	end
	table.sort(found, function(a, b)
		return isOlderOrder(a, b)
	end)
	return found
end

-- The ticket Id a real order uses in CustomerService's slots.
local function ticketIdOf(order: Order): string
	return "Real_" .. order.orderNum
end

-- True while the barista has a free ticket slot. CustomerService counts NPC and real
-- tickets together; before it is resolved a barista holds one real order at a time.
function OrderService:_hasFreeSlot(player: Player): boolean
	local customers = self._customerService
	if customers ~= nil then
		local ok, free = pcall(customers.HasFreeSlot, customers, player)
		return ok and free == true
	end
	return self:_getPlayerOrder(player.UserId, "Being Prepared") == nil
end

-- Shows a real order in the barista's ticket stack. Contained: a failure only warns.
function OrderService:_issueTicket(player: Player, order: Order)
	local customers = self._customerService
	if customers == nil then
		return
	end
	local customer = Players:GetPlayerByUserId(order.customer)
	local ok, err = pcall(customers.IssueRealTicket, customers, player, {
		Id = ticketIdOf(order),
		CustomerName = if customer then customer.DisplayName else "Customer",
		Items = order.order,
	})
	if not ok then
		warn("[OrderService] Real-order ticket failed:", err)
	end
end

-- Frees the slot a real order held (deposit, release, customer gone). Idempotent.
function OrderService:_clearTicket(order: Order)
	local customers = self._customerService
	local barista = if order.preparedBy then Players:GetPlayerByUserId(order.preparedBy) else nil
	if customers == nil or barista == nil then
		return
	end
	local ok, err = pcall(customers.ClearRealTicket, customers, barista, ticketIdOf(order))
	if not ok then
		warn("[OrderService] Clearing a real-order ticket failed:", err)
	end
end

-- Hands `order` to `staff`: Being Prepared, a ticket in their stack, free pick-up nodes shown.
function OrderService:_assignOrder(order: Order, staff: Player)
	order.status = "Being Prepared"
	order.preparedBy = staff.UserId
	order.statusColor = COLOR_PREPARING
	self:_issueTicket(staff, order)
	for _, node in self._pickUpAreas do
		if node.OrderOwner.Value == 0 then
			self.Client.PickUpNodeVisibilityChanged:Fire(staff, node, true)
		end
	end
	self:_updateHandoff(order)
end

-- Returns every order the player is preparing to Pending Preparation (the state
-- _updateOrders gives an order whose barista left), frees their slots and hides their
-- deposit prompts, then dispatches the orders to someone else. `leaving` is the
-- player when they are leaving the game, so they are not picked again.
function OrderService:_releaseClaimedOrder(player: Player, leaving: Player?)
	local orders = self:_getPlayerOrders(player.UserId, "Being Prepared")
	if #orders == 0 then
		return
	end

	for _, order in orders do
		self:_clearTicket(order)
		order.status = "Pending Preparation"
		order.statusColor = COLOR_PENDING
		order.preparedBy = nil
		self:_clearHandoff(order)
	end
	self:_refreshHandoffBeam(player.UserId)

	for _, node in self._pickUpAreas do
		if node.OrderOwner.Value == 0 then
			self.Client.PickUpNodeVisibilityChanged:Fire(player, node, false)
		end
	end

	self:_dispatchPending(leaving)
	self:_broadcastUpdate()
end

-- ShiftService.ClockedInChanged handler.
function OrderService:_onClockedInChanged(player: Player, clockedIn: boolean)
	if not clockedIn then
		self:_releaseClaimedOrder(player)
	else
		self._freeSince[player.UserId] = os.clock()
		if self:_dispatchPending() > 0 then
			self:_broadcastUpdate()
		end
	end
end

-- A barista can take another real order while clocked in with a free ticket slot.
function OrderService:_canClaimOrder(player: Player): boolean
	return self:_isClockedIn(player) and self:_hasFreeSlot(player)
end

-- Returns the oldest pending order, or nil if none exist. When excludeCustomerId is
-- given, that player's own orders are skipped (nobody prepares their own order).
function OrderService:_getNextOrder(excludeCustomerId: number?): Order?
	local next: Order? = nil
	for _, order in self._orders do
		if order.status == "Pending Preparation" and order.customer ~= excludeCustomerId then
			if next == nil or isOlderOrder(order, next) then
				next = order
			end
		end
	end
	return next
end

-- Prunes stale orders and clears abandoned pick-up areas.
-- Iterates in reverse so table.remove does not skip entries.
function OrderService:_updateOrders()
	for i = #self._orders, 1, -1 do
		local order = self._orders[i]
		local customer = Players:GetPlayerByUserId(order.customer)

		if order.status == "Pending Preparation" or order.status == "Ready for Pick Up" then
			if not customer then
				table.remove(self._orders, i)
				self:_clearHandoff(order)
			end
		elseif order.status == "Being Prepared" then
			if not customer then
				self:_clearTicket(order)
				table.remove(self._orders, i)
				self:_clearHandoff(order)
			elseif not Players:GetPlayerByUserId(order.preparedBy) then
				-- Staff left — put the order back in the queue
				local staffId = order.preparedBy
				order.status = "Pending Preparation"
				order.statusColor = COLOR_PENDING
				order.preparedBy = nil
				self:_clearHandoff(order)
				if staffId ~= nil then
					self:_refreshHandoffBeam(staffId)
				end
			end
		end
	end

	-- Remove pick-up area contents if the customer has left
	for _, node in self._pickUpAreas do
		local ownerValue: IntValue = node.OrderOwner
		if ownerValue.Value ~= 0 and not Players:GetPlayerByUserId(ownerValue.Value) then
			local orderFolder = ServerStorage[ORDER_PICKUP_FOLDER]:FindFirstChild("Order_" .. ownerValue.Value)
			if orderFolder then
				orderFolder:Destroy()
			end
			for _, child in node:GetChildren() do
				if child:IsA("Model") then
					child:Destroy()
				end
			end
			ownerValue.Value = 0
			node.ProximityPrompt.ObjectText = "Pick Up Area"
			node.ProximityPrompt.ActionText = "Deposit Order"
		end
	end
	for id, order in self._customerOrders do
		if order.npcModel and order.npcModel.Parent == nil then
			self._customerOrders[id] = nil
		end
	end
end

-- The oldest open order to show on the Staff Screens: a pending real order first,
-- else the oldest order being prepared (real or NPC). Returns the real order (with
-- items) or the NPC board entry, plus the count of open orders.
function OrderService:_staffScreenOrder(): (Order?, CustomerOrder?, number)
	local open = 0
	local real: Order? = self:_getNextOrder()
	local preparing: Order? = nil
	for _, order in self._orders do
		if order.status ~= "Ready for Pick Up" then
			open += 1
			if order.status == "Being Prepared" and (preparing == nil or isOlderOrder(order, preparing)) then
				preparing = order
			end
		end
	end
	local npc: CustomerOrder? = nil
	for _, order in self._customerOrders do
		if order.status ~= "Ready for Pick Up" and not (order.npcModel and order.npcModel.Parent == nil) then
			open += 1
			if npc == nil or isOlderOrder(order, npc) then
				npc = order
			end
		end
	end
	if real ~= nil then
		return real, nil, open
	end
	if preparing ~= nil and (npc == nil or not isOlderOrder(npc, preparing)) then
		return preparing, nil, open
	end
	return nil, npc, open
end

-- Staff Screens are display-only boards (no claim prompt, DEC-059): the oldest open
-- order, its items when it is a real order, and how many orders are open.
function OrderService:_updateStaffScreens()
	local realOrder, npcOrder, openCount = self:_staffScreenOrder()

	for _, screen in self._staffScreens do
		for _, frame in screen.Frame.Frame:GetChildren() do
			if frame:IsA("Frame") and frame.Visible then
				frame:Destroy()
			end
		end

		screen.Frame.NumPending.Text = openCount .. (openCount == 1 and " Open Order" or " Open Orders")
		if npcOrder then
			screen.Frame.Customer.Text = npcOrder.customerName
			screen.Frame.OrderNum.Text = "Order " .. npcOrder.orderNum
		elseif realOrder then
			local customer = Players:GetPlayerByUserId(realOrder.customer)
			screen.Frame.Customer.Text = customer and customer.Name or "Unknown"
			screen.Frame.OrderNum.Text = "Order " .. realOrder.orderNum

			for _, item in realOrder.order do
				local itemFrame = screen.Frame.Frame.Template:Clone()
				itemFrame.Parent = screen.Frame.Frame

				local itemName: string = item["DefaultInfo"]["ItemName"]
				if item["DefaultInfo"]["Select"] then
					for itemType in item["DefaultInfo"]["Select"] do
						itemName = item["CustomInfo"][itemType] .. " " .. itemName
					end
				end
				itemFrame.TopFrame.ItemName.Text = itemName

				if item["DefaultInfo"]["RequiredSelection"] then
					for selectionType in item["DefaultInfo"]["RequiredSelection"] do
						local infoFrame = itemFrame.InfoFrameTemplate:Clone()
						infoFrame.TextLabel.Text = selectionType .. ": " .. item["CustomInfo"][selectionType]
						infoFrame.Visible = true
						infoFrame.Parent = itemFrame
					end
				end

				if item["DefaultInfo"]["Options"] then
					for optionType, defaultValue in item["DefaultInfo"]["Options"] do
						if defaultValue ~= item["CustomInfo"][optionType] then
							local infoFrame = itemFrame.InfoFrameTemplate:Clone()
							infoFrame.TextLabel.Text = if item["CustomInfo"][optionType]
								then "+ " .. optionType
								else "- NO " .. optionType
							infoFrame.Visible = true
							infoFrame.Parent = itemFrame
						end
					end
				end

				-- AutomaticSize lets the client calculate height based on child content.
				-- The original used AbsoluteContentSize which is client-only and always 0 server-side.
				itemFrame.AutomaticSize = Enum.AutomaticSize.Y
				itemFrame.Visible = true
			end
		else
			screen.Frame.Customer.Text = ""
			screen.Frame.OrderNum.Text = ""
		end

		-- AutomaticCanvasSize handles scrolling without server-side AbsoluteContentSize reads.
		screen.Frame.Frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		screen.Frame.Frame.CanvasSize = UDim2.new(0, 0, 0, 0)
	end
end

function OrderService:_updateStatusScreens()
	local allOrders = {}

	for _, order in self._orders do
		local customer = Players:GetPlayerByUserId(order.customer)
		table.insert(allOrders, {
			seq = order.seq,
			orderNum = order.orderNum,
			customerName = customer and customer.Name or "Unknown",
			status = order.status,
			statusColor = order.statusColor,
			numItems = order.numItems,
		})
	end

	for id, order in self._customerOrders do
		if order.npcModel and order.npcModel.Parent == nil then
			self._customerOrders[id] = nil
		else
			table.insert(allOrders, {
				seq = order.seq,
				orderNum = order.orderNum,
				customerName = order.customerName,
				status = order.status,
				statusColor = order.statusColor,
				numItems = order.numItems,
			})
		end
	end

	table.sort(allOrders, function(a, b)
		local prioA = STATUS_PRIORITY[a.status] or 0
		local prioB = STATUS_PRIORITY[b.status] or 0
		if prioA ~= prioB then
			return prioA < prioB
		end
		return isOlderOrder(a, b)
	end)

	for _, screen in self._statusScreens do
		local listFrame = screen:FindFirstChild("Frame") and screen.Frame:FindFirstChild("Frame")
		if not listFrame then
			continue
		end
		local template = listFrame:FindFirstChild("Template")
		if not template then
			continue
		end

		for _, frame in listFrame:GetChildren() do
			if frame:IsA("ImageLabel") and frame.Visible then
				frame:Destroy()
			end
		end

		local maxDisplay = math.min(#allOrders, 10)
		for i = 1, maxDisplay do
			local order = allOrders[i]
			local entry = template:Clone()
			entry.Name = order.orderNum
			if entry:FindFirstChild("Order") then
				entry.Order.Text = "Order " .. order.orderNum
			end
			if entry:FindFirstChild("Customer") then
				entry.Customer.Text = order.customerName
			end
			if entry:FindFirstChild("Status") then
				entry.Status.Text = "Status: " .. order.status
			end
			if entry:FindFirstChild("Items") then
				entry.Items.Text = order.numItems .. (order.numItems == 1 and " Item" or " Items")
			end
			entry.ImageColor3 = order.statusColor
			entry.LayoutOrder = (STATUS_PRIORITY[order.status] or 0) + (tonumber(order.orderNum) or 0)
			entry.Visible = true
			entry.Parent = listFrame
		end
	end
end

-- Runs all three update passes in one call.
function OrderService:_broadcastUpdate()
	self:_updateOrders()
	self:_updateStaffScreens()
	self:_updateStatusScreens()
end

-- Adds a real order. `assignTo` is the barista who took it at the counter: the order
-- goes straight onto their ticket stack. Without it (Boba Phone) it is dispatched.
function OrderService:_addOrder(customerId: number, orderItems: { any }, specs: { Spec }, assignTo: Player?)
	self._currentOrderNum += 1
	local currentSeq = self._currentOrderNum
	local order: Order = {
		seq = currentSeq,
		orderNum = string.format("%04i", currentSeq % 1000),
		customer = customerId,
		order = orderItems,
		specs = specs,
		numItems = #orderItems,
		status = "Pending Preparation",
		preparedBy = nil,
		statusColor = COLOR_PENDING,
	}
	table.insert(self._orders, order)
	if assignTo then
		self:_assignOrder(order, assignTo)
	else
		self:_dispatchPending()
	end
	self:_broadcastUpdate()
	pcall(function()
		self.OrderCreated:Fire(customerId)
	end)
end

-- Gives the player the oldest pending order they did not place, if they can take one.
function OrderService:_claimNextOrder(player: Player)
	if not self:_canClaimOrder(player) then
		return
	end
	local nextOrder = self:_getNextOrder(player.UserId)
	if not nextOrder then
		return
	end
	self:_assignOrder(nextOrder, player)
	self:_broadcastUpdate()
end

-- Automatic dispatch (DEC-059, no claim or queue): while orders are pending, the
-- oldest one goes to the clocked-in barista with a free ticket slot who has been idle
-- longest. `exclude` is a player who is leaving. Never yields. Returns how many
-- orders were assigned; the caller refreshes the boards.
function OrderService:_dispatchPending(exclude: Player?): number
	local assigned = 0
	for _ = 1, #self._orders do
		if not self:_getNextOrder() then
			break
		end
		local best: Player? = nil
		local bestSince = math.huge
		for _, staff in Players:GetPlayers() do
			if staff ~= exclude and self:_canClaimOrder(staff) and self:_getNextOrder(staff.UserId) then
				local since = self._freeSince[staff.UserId] or 0
				if since < bestSince then
					best, bestSince = staff, since
				end
			end
		end
		if best == nil then
			break
		end
		local order = self:_getNextOrder(best.UserId)
		if order == nil then
			break
		end
		self:_assignOrder(order, best)
		self._freeSince[best.UserId] = os.clock()
		assigned += 1
	end
	return assigned
end

function OrderService:_collectOrder(customerId: number, area: Model)
	local ownerValue = area:FindFirstChild("OrderOwner") :: IntValue?
	if not ownerValue or ownerValue.Value ~= customerId then
		return
	end

	local customer = Players:GetPlayerByUserId(customerId)
	if customer then
		self.Client.PickUpNodeVisibilityChanged:Fire(customer, area, false)
	end

	local pickedTools: { Instance } = {}
	local orderFolder = ServerStorage[ORDER_PICKUP_FOLDER]:FindFirstChild("Order_" .. customerId)
	if orderFolder then
		pickedTools = orderFolder:GetChildren()
		if customer then
			self:_grantToolsToCustomer(customer, pickedTools)
		end
		orderFolder:Destroy()
	end

	for _, child in area:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end

	ownerValue.Value = 0
	local prompt = area:FindFirstChild("ProximityPrompt") :: ProximityPrompt?
	if prompt then
		prompt.ObjectText = "Pick Up Area"
		prompt.ActionText = "Deposit Order"
	end

	for i = #self._orders, 1, -1 do
		local order = self._orders[i]
		if order.customer == customerId and order.status == "Ready for Pick Up" then
			table.remove(self._orders, i)
			local barista = order.preparedBy and Players:GetPlayerByUserId(order.preparedBy) or nil
			local handed = pickedTools
			pcall(function()
				self.OrderPickedUp:Fire(customerId, barista, order.grade, order.specs, handed, order.order)
			end)
			if order.preparedBy then
				self._freeSince[order.preparedBy] = os.clock()
			end
		end
	end

	self:_dispatchPending()
	self:_updateStaffScreens()
	self:_updateStatusScreens()
end

-- Handles both paths of a pick-up area interaction:
--   • If the area belongs to the triggering player → they pick up their order.
--   • Otherwise → the player is a staff member depositing a prepared order.
function OrderService:_handlePickUp(player: Player, area: Model)
	local ownerValue: IntValue = area.OrderOwner

	if ownerValue.Value == player.UserId then
		-- ── Customer path: collect their completed order ──────────────────────
		self:_collectOrder(player.UserId, area)
	else
		-- ── Staff path: deposit a prepared order ──────────────────────────────
		-- A barista with two tickets may be preparing two real orders; the held tools
		-- pick which one is deposited (oldest first).
		local preparing = self:_getPlayerOrders(player.UserId, "Being Prepared")
		if #preparing == 0 then
			return
		end

		-- A node another barista has already filled keeps its owner: refuse, and hide
		-- the stale prompt on this barista's client.
		if ownerValue.Value ~= 0 then
			self.Client.PickUpNodeVisibilityChanged:Fire(player, area, false)
			self.Client.Announcement:Fire(
				player,
				"Cannot Deposit Order!",
				"This spot is taken. Use a free one.",
				COLOR_ERROR
			)
			return
		end

		-- The tools are matched against the order's specs here, in one synchronous
		-- block with the move below, so nothing can change them in between. A miss
		-- tells the barista why and changes nothing.
		local playerOrder: Order = preparing[1]
		local tools, grade, reasons = nil, "Wrong" :: Grade, {} :: { string }
		local directOrder: Order? = nil
		for index, candidate in preparing do
			local found, foundGrade, foundReasons = self:FindServeTools(player, candidate.specs)
			if candidate.handoff == "direct" then
				-- A nearby customer is served in person, never via the counter.
				if found and directOrder == nil then
					directOrder = candidate
				end
			elseif found then
				playerOrder, tools, grade = candidate, found, foundGrade
				break
			end
			if index == 1 and not found then
				reasons = foundReasons
			end
		end
		if not tools then
			if directOrder ~= nil then
				local customer = Players:GetPlayerByUserId(directOrder.customer)
				local name = if customer ~= nil then customer.DisplayName else "Your customer"
				self.Client.Announcement:Fire(
					player,
					"Serve Them Directly!",
					`{name} is nearby. Use the Serve prompt on them to hand the order over.`,
					COLOR_ERROR
				)
				return
			end
			self.Client.Announcement:Fire(
				player,
				"Cannot Deposit Order!",
				describeReasons(reasons) .. ". Check your order notepad and return when ready.",
				COLOR_ERROR
			)
			return
		end

		ownerValue.Value = playerOrder.customer

		-- Hide free pick-up nodes for this player once they have nothing left to deposit
		if #preparing <= 1 then
			for _, node in self._pickUpAreas do
				if node.OrderOwner.Value == 0 then
					self.Client.PickUpNodeVisibilityChanged:Fire(player, node, false)
				end
			end
		end

		-- The deposited order frees its ticket slot.
		self:_clearTicket(playerOrder)

		if self._statisticsService then
			self._statisticsService:IncrementStat(player, "OrdersPrepared", 1)
		end

		playerOrder.status = "Ready for Pick Up"
		playerOrder.statusColor = COLOR_READY
		playerOrder.grade = grade
		self:_clearHandoff(playerOrder)
		self._freeSince[player.UserId] = os.clock()
		self:_dispatchPending()
		self:_updateStaffScreens()
		self:_updateStatusScreens()

		local orderFolder = Instance.new("Folder")
		orderFolder.Name = "Order_" .. playerOrder.customer
		orderFolder.Parent = ServerStorage[ORDER_PICKUP_FOLDER]

		for i, tool in tools do
			-- A served tool keeps its marks when picked up, so mark it spent: it can no
			-- longer satisfy another order (FindServeTools skips it).
			tool:SetAttribute("Served", true)
			if PICKUP_MODEL_OFFSETS[i] then
				-- The display must never strand a deposited order: a node that
				-- cannot be pivoted to still hands the tools over.
				local okModel, displayModel = pcall(createModelFromTool, tool)
				if okModel and typeof(displayModel) == "Instance" then
					displayModel.Parent = area
					local okPivot = pcall(function()
						displayModel:PivotTo(
							area.CFrame
								* PICKUP_MODEL_OFFSETS[i]
								* CFrame.new(0, displayModel.PrimaryPart.Size.Y / 2, 0)
						)
					end)
					if not okPivot then
						displayModel:Destroy()
						warn("[OrderService] Pick-up display skipped; node has no CFrame.")
					end
				else
					warn("[OrderService] Pick-up display failed:", displayModel)
				end
			end
			tool.Parent = orderFolder
		end

		local customer = Players:GetPlayerByUserId(playerOrder.customer)
		if customer then
			area.ProximityPrompt.ObjectText = customer.Name .. "'s Order"
			area.ProximityPrompt.ActionText = "Pick Up Order"
			self.Client.PickUpNodeVisibilityChanged:Fire(customer, area, true, true)
		end

		local targetCustomerId = playerOrder.customer
		task.delay(30, function()
			pcall(function()
				self:_collectOrder(targetCustomerId, area)
			end)
		end)
	end
end

---> Real-order handoff (direct serve vs counter deposit)

-- "direct" while the ordering customer is close enough to serve in person;
-- otherwise the worker deposits at a counter pick-up node as before.
function OrderService.HandoffMode(distanceStuds: number?): string
	if distanceStuds ~= nil and distanceStuds <= HANDOFF_DIRECT_DISTANCE_STUDS then
		return "direct"
	end
	return "counter"
end

local function rootPartOf(player: Player): BasePart?
	local character = player.Character
	if character == nil then
		return nil
	end
	local primary = character.PrimaryPart
	if primary ~= nil then
		return primary
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Distance in studs between the barista preparing `order` and its customer,
-- or nil when either side is gone or has no live character.
function OrderService:_handoffDistance(order: Order): number?
	if order.preparedBy == nil then
		return nil
	end
	local barista = Players:GetPlayerByUserId(order.preparedBy)
	local customer = Players:GetPlayerByUserId(order.customer)
	if barista == nil or customer == nil then
		return nil
	end
	local baristaRoot = rootPartOf(barista)
	local customerRoot = rootPartOf(customer)
	if baristaRoot == nil or customerRoot == nil then
		return nil
	end
	return (baristaRoot.Position - customerRoot.Position).Magnitude
end

-- Sends the barista their current direct-handoff target (no argument clears
-- it), firing only on change. The client beam ignores the station-hints
-- setting, so it shows even with hints disabled.
function OrderService:_setHandoffBeam(baristaUserId: number, customerId: number?)
	local barista = Players:GetPlayerByUserId(baristaUserId)
	if customerId == nil then
		if self._handoffBeam[baristaUserId] ~= nil then
			self._handoffBeam[baristaUserId] = nil
			if barista ~= nil then
				self.Client.HandoffTargetChanged:Fire(barista)
			end
		end
		return
	end
	if barista == nil or self._handoffBeam[baristaUserId] == customerId then
		return
	end
	self._handoffBeam[baristaUserId] = customerId
	self.Client.HandoffTargetChanged:Fire(barista, customerId)
end

-- The barista's beam target is the customer of their first direct-mode order,
-- or nil when none is in direct range.
function OrderService:_refreshHandoffBeam(baristaUserId: number)
	local target: Order? = nil
	for _, order in self._orders do
		if order.status == "Being Prepared" and order.preparedBy == baristaUserId and order.handoff == "direct" then
			if target == nil or isOlderOrder(order, target) then
				target = order
			end
		end
	end
	self:_setHandoffBeam(baristaUserId, if target ~= nil then target.customer else nil)
end

-- Drops an order's handoff state (prompt destroyed, beam refreshed). The
-- caller mutates the order (status, preparedBy, table membership) first. Safe
-- to call for orders that never had any.
function OrderService:_clearHandoff(order: Order)
	local baristaId = order.preparedBy
	order.handoff = nil
	local prompt = order.handoffPrompt
	order.handoffPrompt = nil
	if prompt ~= nil then
		prompt:Destroy()
	end
	if baristaId ~= nil then
		self:_refreshHandoffBeam(baristaId)
	end
end

-- Parks the order's handoff prompt (kept, disabled, unparented) while the
-- customer is out of direct range.
function OrderService:_parkHandoffPrompt(order: Order)
	order.handoff = "counter"
	local prompt = order.handoffPrompt
	if prompt ~= nil and prompt.Parent ~= nil then
		prompt.Enabled = false
		prompt.Parent = nil
	end
end

-- Serves the order's handoff prompt from the customer's root part while they
-- are in direct range. The prompt mirrors the NPC Serve prompt
-- (CustomerService:_ensureNpcPrompt): no hold, no line of sight, short range.
function OrderService:_ensureHandoffPrompt(order: Order, customer: Player, customerRoot: BasePart)
	order.handoff = "direct"
	local prompt = order.handoffPrompt
	if prompt ~= nil and prompt.Parent ~= customerRoot then
		prompt:Destroy()
		order.handoffPrompt = nil
		prompt = nil
	end
	if prompt == nil then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = HANDOFF_PROMPT_NAME
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = HANDOFF_TRIGGER_DISTANCE_STUDS
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(triggerPlayer: Player)
			self:_handleHandoff(triggerPlayer, order)
		end)
		order.handoffPrompt = prompt
	end
	prompt.ActionText = "Serve"
	prompt.ObjectText = customer.DisplayName .. "'s Order"
	prompt.Enabled = true
	if prompt.Parent ~= customerRoot then
		prompt.Parent = customerRoot
	end
end

-- Recomputes one order's handoff mode from live distance: a near customer gets
-- the direct-serve prompt and beam, a far (or gone) one keeps the counter
-- deposit path.
function OrderService:_updateHandoff(order: Order)
	if order.status ~= "Being Prepared" or order.preparedBy == nil then
		self:_clearHandoff(order)
		return
	end
	local distance = self:_handoffDistance(order)
	if OrderService.HandoffMode(distance) == "direct" then
		local customer = Players:GetPlayerByUserId(order.customer)
		local customerRoot = if customer ~= nil then rootPartOf(customer) else nil
		if customer ~= nil and customerRoot ~= nil then
			self:_ensureHandoffPrompt(order, customer, customerRoot)
		else
			self:_parkHandoffPrompt(order)
		end
	else
		self:_parkHandoffPrompt(order)
	end
	self:_refreshHandoffBeam(order.preparedBy)
end

-- Re-evaluates every order being prepared. Runs on a poll loop so the prompt
-- and beam track both players as they move.
function OrderService:_updateAllHandoffs()
	for _, order in self._orders do
		if order.status == "Being Prepared" then
			self:_updateHandoff(order)
		end
	end
end

-- Moves prepared tools straight into a customer's Backpack, recording the
-- customer-side stats and quests the counter pick-up path records. Backpack
-- tools have no established capacity cap (the pick-up path already parents
-- unconditionally), so there is no overflow fallback.
function OrderService:_grantToolsToCustomer(customer: Player, tools: { Instance })
	if self._statisticsService then
		self._statisticsService:IncrementStat(customer, "ItemsOrdered", #tools)
	end
	for _, item in tools do
		if self._questService then
			local currentItem: string = (item:FindFirstChild("CurrentItem") and item.CurrentItem.Value) or item.Name
			-- Boba tools are named "[Flavor] Boba" (see Recipes Tapioca step).
			if string.find(currentItem, " Boba", 1, true) then
				if self._statisticsService then
					self._statisticsService:IncrementStat(customer, "BobasOrdered", 1)
				end
				self._questService:AdvanceQuest(customer, "BobaOrdered", 1)
			elseif string.find(currentItem, "Macaron") then
				self._questService:AdvanceQuest(customer, "MacaronOrdered", 1)
			elseif string.find(currentItem, "Hot Chocolate") then
				self._questService:AdvanceQuest(customer, "HotChocolateOrdered", 1)
			end
		end
		item.Parent = customer.Backpack
	end
end

-- Direct serve: the barista hands a prepared real order to its customer in
-- person. The tools move straight into the customer's Backpack and the order
-- completes exactly as a counter pick-up would (same OrderPickedUp payload,
-- so pay, XP and quests are unchanged).
function OrderService:_handleHandoff(player: Player, order: Order)
	local live = false
	for _, candidate in self._orders do
		if candidate == order and candidate.status == "Being Prepared" and candidate.preparedBy == player.UserId then
			live = true
			break
		end
	end
	if not live then
		return
	end
	local customer = Players:GetPlayerByUserId(order.customer)
	if customer == nil then
		return
	end
	local baristaRoot = rootPartOf(player)
	local customerRoot = rootPartOf(customer)
	if baristaRoot == nil or customerRoot == nil then
		return
	end
	if (baristaRoot.Position - customerRoot.Position).Magnitude > HANDOFF_TRIGGER_DISTANCE_STUDS then
		return
	end

	-- The tools are matched against this order's specs here, in one
	-- synchronous block with the move below, so nothing can change them in
	-- between. A miss tells the barista why and changes nothing.
	local tools, grade, reasons = self:FindServeTools(player, order.specs)
	if tools == nil then
		self.Client.Announcement:Fire(
			player,
			"Cannot Serve Order!",
			describeReasons(reasons) .. ". Check your order notepad and return when ready.",
			COLOR_ERROR
		)
		return
	end
	if grade ~= "Perfect" and grade ~= "Close" then
		return
	end

	for _, tool in tools do
		-- A served tool keeps its marks when picked up, so mark it spent: it can no
		-- longer satisfy another order (FindServeTools skips it).
		tool:SetAttribute("Served", true)
	end
	self:_grantToolsToCustomer(customer, tools)

	if self._statisticsService then
		self._statisticsService:IncrementStat(player, "OrdersPrepared", 1)
	end

	order.grade = grade
	for i = #self._orders, 1, -1 do
		if self._orders[i] == order then
			table.remove(self._orders, i)
			break
		end
	end
	self:_clearTicket(order)
	self:_clearHandoff(order)
	self._freeSince[player.UserId] = os.clock()
	pcall(function()
		self.OrderPickedUp:Fire(customer.UserId, player, order.grade, order.specs, tools, order.order)
	end)
	self:_dispatchPending()
	self:_updateStaffScreens()
	self:_updateStatusScreens()
end

---> Public Methods

-- Registers an NPC customer order to display on the in-world Status Screens.
function OrderService:RegisterCustomerOrder(
	orderId: string,
	customerName: string,
	numItems: number,
	status: string?,
	npcModel: Model?
): string
	self._currentOrderNum += 1
	local currentSeq = self._currentOrderNum
	local orderNum = string.format("%04i", currentSeq % 1000)
	local orderStatus = status or "Being Prepared"
	local color = if orderStatus == "Ready for Pick Up"
		then COLOR_READY
		elseif orderStatus == "Being Prepared" then COLOR_PREPARING
		else COLOR_PENDING

	self._customerOrders[orderId] = {
		seq = currentSeq,
		orderNum = orderNum,
		customerName = customerName,
		numItems = numItems,
		status = orderStatus,
		statusColor = color,
		npcModel = npcModel,
	}

	self:_updateStatusScreens()
	return orderNum
end

-- Updates the status of an active customer order ("Being Prepared", "Ready for Pick Up").
function OrderService:UpdateCustomerOrderStatus(orderId: string, status: string)
	local order = self._customerOrders[orderId]
	if not order then
		return
	end
	if order.status == status then
		return
	end
	order.status = status
	order.statusColor = if status == "Ready for Pick Up"
		then COLOR_READY
		elseif status == "Being Prepared" then COLOR_PREPARING
		else COLOR_PENDING

	self:_updateStatusScreens()
end

-- Removes a customer order from Status Screens (e.g. customer served or walked out).
function OrderService:RemoveCustomerOrder(orderId: string)
	if self._customerOrders[orderId] then
		self._customerOrders[orderId] = nil
		self:_updateStatusScreens()
	end
end

-- Number of real orders waiting for a free barista.
function OrderService:GetPendingCount(): number
	local count = 0
	for _, order in self._orders do
		if order.status == "Pending Preparation" then
			count += 1
		end
	end
	return count
end

-- True while the customer has a real order that has not been picked up.
function OrderService:HasOpenOrder(customerId: number): boolean
	return self:_hasOpenOrder(customerId)
end

-- Retries dispatch after a ticket slot frees elsewhere (an NPC served or gone).
-- Never yields; CustomerService calls it deferred.
function OrderService:DispatchPending()
	if self:_dispatchPending() > 0 then
		self:_broadcastUpdate()
	end
end

-- True while the player is preparing a player-placed order (assigned, not yet
-- deposited).
function OrderService:HasActiveOrder(player: Player): boolean
	return self:_getPlayerOrder(player.UserId, "Being Prepared") ~= nil
end

-- Picks one of the player's tools (the held tool first, then the backpack) for each
-- spec, graded by OrderSpec.PickTools from the tools' attributes. Returns the tools
-- in spec order and the overall grade, or nil, "Wrong" and the reasons. It only
-- reads: the caller moves or destroys the tools, in the same synchronous block.
-- Never yields.
function OrderService:FindServeTools(player: Player, specs: { Spec }): ({ Tool }?, Grade, { string })
	local entries: { ToolEntry } = {}
	local candidates: { { [string]: any } } = {}
	for _, entry in collectTools(player.Character, player.Backpack) do
		-- A tool that was already served (and picked up again) cannot serve another order.
		if entry.Tool:GetAttribute("Served") ~= true then
			table.insert(entries, entry)
			table.insert(candidates, entry.Tool:GetAttributes())
		end
	end

	local picks, grade, reasons = OrderSpec.PickTools(specs, candidates)
	if not picks then
		return nil, grade, reasons
	end

	local tools = table.create(#picks)
	for i, candidateIndex in picks do
		tools[i] = entries[candidateIndex].Tool
	end
	return tools, grade, reasons
end

-- Rebuilds a client order (an array of { Category, Item, CustomInfo }) from the
-- server Menu, launch items only. Returns the items and specs, or nil and the reply
-- message. Only the array part is read; every value is untrusted.
function OrderService:_buildOrder(player: Player, orderItems: any): ({ any }?, { Spec } | string)
	if typeof(orderItems) ~= "table" then
		return nil, "Invalid order."
	end
	local itemCount = #orderItems
	if itemCount < ORDER_MIN_ITEMS or itemCount > ORDER_MAX_ITEMS then
		return nil, string.format("Orders need %d to %d items.", ORDER_MIN_ITEMS, ORDER_MAX_ITEMS)
	end

	local menu = getFoodTable()
	if not menu then
		return nil, "Ordering is unavailable right now."
	end

	-- The specs the deposit is graded against come from the rebuilt items.
	local items = table.create(itemCount)
	local specs = table.create(itemCount)
	for i = 1, itemCount do
		-- Only launch-menu items can be made at a station today. An order for anything
		-- else could never be deposited and would lock the barista and the customer.
		local request = orderItems[i]
		if
			isLaunchItem == nil
			or typeof(request) ~= "table"
			or not isLaunchItem(request.Category, request.Item, request.CustomInfo)
		then
			return nil, "That item isn't available right now."
		end

		local item, spec, reason = buildOrderItem(menu, request)
		if not item or not spec then
			warn(string.format("[OrderService] Rejected order from %s: %s", player.Name, tostring(reason)))
			return nil, "Invalid order."
		end
		items[i] = item
		specs[i] = spec
	end
	return items, specs
end

-- Any player may place an order for themselves (the Boba Phone). `customerId` must be
-- the caller's UserId; every argument is untrusted client input.
function OrderService.Client:CreateOrder(player: Player, customerId: any, orderItems: any): CreateOrderResult
	local server = self.Server

	if typeof(customerId) ~= "number" or typeof(orderItems) ~= "table" then
		return { Success = false, Message = "Invalid order." }
	end
	if customerId ~= player.UserId then
		return { Success = false, Message = "You can only place orders for yourself." }
	end
	-- R3 (REVIVAL-001 BOBA-PHONE): the phone and ClockedIn are mutually exclusive.
	if server:_isClockedIn(player) then
		return { Success = false, Message = "Clock out to order with the phone." }
	end
	if server._orderDebounces[player.UserId] then
		return { Success = false, Message = "Please wait before placing another order." }
	end

	local items, specs = server:_buildOrder(player, orderItems)
	if not items then
		return { Success = false, Message = specs :: string }
	end

	if server:_hasOpenOrder(player.UserId) then
		return { Success = false, Message = "You already have an order in progress." }
	end

	server._orderDebounces[player.UserId] = true
	task.delay(ORDER_DEBOUNCE_SECONDS, function()
		server._orderDebounces[player.UserId] = nil
	end)

	server:_addOrder(player.UserId, items, specs :: { Spec })

	if server._statisticsService then
		server._statisticsService:IncrementStat(player, "OrdersCreated", 1)
	end

	return { Success = true, Message = "Order placed." }
end

-- A barista entered a real customer's order at the counter (CustomerService checks the
-- counter lock, range and register first). The items are rebuilt exactly as for
-- CreateOrder, and the order goes straight onto the taker's ticket stack. Server-only.
function OrderService:CreateCounterOrder(taker: Player, customer: Player, orderItems: any): CreateOrderResult
	if taker == customer then
		return { Success = false, Message = "You can't take your own order." }
	end
	if not self:_isClockedIn(taker) then
		return { Success = false, Message = "You must be clocked in." }
	end
	if self:_isClockedIn(customer) then
		return { Success = false, Message = "That customer is clocked in." }
	end

	local items, specs = self:_buildOrder(taker, orderItems)
	if not items then
		return { Success = false, Message = specs :: string }
	end

	-- Re-checked with no yield before the add, so two submits cannot both pass.
	if self:_hasOpenOrder(customer.UserId) then
		return { Success = false, Message = "That customer already has an order in progress." }
	end
	if not self:_hasFreeSlot(taker) then
		return { Success = false, Message = "Your order slots are full. Finish an order first!" }
	end

	self:_addOrder(customer.UserId, items, specs :: { Spec }, taker)

	if self._statisticsService then
		self._statisticsService:IncrementStat(customer, "OrdersCreated", 1)
	end

	return { Success = true, Message = "Order placed." }
end

---> Lifecycle

-- Indexes the authored "Ordering System" folder and attaches prompts. Each part
-- (status screens, staff screens, pick-up areas) is optional: a missing one is
-- warned about and only that feature is disabled.
function OrderService:_setupOrderingSystem(orderingSystem: Instance)
	-- Index status screens (customer-facing order boards)
	local statusScreens = orderingSystem:FindFirstChild("Status Screens")
	if statusScreens then
		for _, desc in statusScreens:GetDescendants() do
			if desc:IsA("SurfaceGui") and desc.Name == "Screen" then
				table.insert(self._statusScreens, desc)
			end
		end
	else
		warn('[OrderService] "Ordering System.Status Screens" missing; order status boards disabled.')
	end

	-- Index staff screens (display-only boards; orders are dispatched automatically)
	local staffScreens = orderingSystem:FindFirstChild("Staff Screens")
	if staffScreens then
		for _, desc in staffScreens:GetDescendants() do
			if desc:IsA("SurfaceGui") and desc.Name == "Screen" then
				table.insert(self._staffScreens, desc)
			end
		end
	else
		warn('[OrderService] "Ordering System.Staff Screens" missing; staff order boards disabled.')
	end

	-- Index pick-up areas and attach deposit/pickup ProximityPrompts
	local pickUp = orderingSystem:FindFirstChild("Pick Up")
	if pickUp then
		for _, node in pickUp:GetChildren() do
			table.insert(self._pickUpAreas, node)
			if not node:IsA("BasePart") then
				warn(
					"[OrderService] Pick Up node is not a BasePart; deposit display is skipped for it: "
						.. node:GetFullName()
				)
			end

			local ownerValue = Instance.new("IntValue")
			ownerValue.Name = "OrderOwner"
			ownerValue.Parent = node

			local prompt = Instance.new("ProximityPrompt")
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt.HoldDuration = 0
			prompt.UIOffset = Vector2.new(0, 25)
			prompt.ObjectText = "Pick Up Area"
			prompt.ActionText = "Deposit Order"
			prompt.RequiresLineOfSight = false
			prompt.Enabled = false
			prompt.Parent = node

			prompt.Triggered:Connect(function(player: Player)
				self:_handlePickUp(player, node)
			end)
		end
	else
		warn('[OrderService] "Ordering System.Pick Up" missing; order pick-up disabled.')
	end

	self:_updateStaffScreens()
	self:_updateStatusScreens()
end

function OrderService:KnitInit()
	-- Ensure the server-side order pickup storage folder exists
	if not ServerStorage:FindFirstChild(ORDER_PICKUP_FOLDER) then
		local folder = Instance.new("Folder")
		folder.Name = ORDER_PICKUP_FOLDER
		folder.Parent = ServerStorage
	end

	getModelStorage()
end

function OrderService:KnitStart()
	-- Resolve cross-service references after all services have initialised
	self._statisticsService = Knit.GetService("StatisticsService")
	self._shiftService = Knit.GetService("ShiftService")
	self._customerService = Knit.GetService("CustomerService")

	local questOk, questService = pcall(Knit.GetService, "QuestService")
	if questOk then
		self._questService = questService
	end

	-- Clocking out returns the barista's orders for dispatch, so a barista who cannot
	-- make an order is never stuck with it; clocking in dispatches waiting orders.
	self._shiftService.ClockedInChanged:Connect(function(player: Player, clockedIn: boolean)
		self:_onClockedInChanged(player, clockedIn)
	end)

	-- Direct-handoff proximity (25-studs rule): re-evaluated continuously so the
	-- serve prompt and beam track the ordering customer as both players move.
	task.spawn(function()
		while true do
			task.wait(HANDOFF_POLL_SECONDS)
			local ok, err = pcall(self._updateAllHandoffs, self)
			if not ok then
				warn("[OrderService] Handoff update failed:", err)
			end
		end
	end)

	-- The world is resolved last because it may yield.
	local orderingSystem = workspace:WaitForChild(ORDERING_SYSTEM_NAME, ORDERING_SYSTEM_TIMEOUT_SECONDS)
	if not orderingSystem then
		warn(
			string.format(
				'[OrderService] workspace["%s"] not found after %ds; ordering screens and pick-up are disabled.',
				ORDERING_SYSTEM_NAME,
				ORDERING_SYSTEM_TIMEOUT_SECONDS
			)
		)
		return
	end
	self:_setupOrderingSystem(orderingSystem)
end

function OrderService:PlayerRemoving(player: Player)
	self._orderDebounces[player.UserId] = nil
	self._freeSince[player.UserId] = nil
	self._handoffBeam[player.UserId] = nil
	-- The player is still in Players here: release their orders explicitly, without
	-- handing any back to them, and drop the orders they placed.
	self:_releaseClaimedOrder(player, player)
	for i = #self._orders, 1, -1 do
		local order = self._orders[i]
		if order.customer == player.UserId and order.status ~= "Ready for Pick Up" then
			self:_clearTicket(order)
			table.remove(self._orders, i)
			self:_clearHandoff(order)
		end
	end
	self:_broadcastUpdate()
	-- Once they are gone, _updateOrders also clears pick-up areas they owned.
	task.defer(function()
		self:_broadcastUpdate()
	end)
end

return OrderService

--[[
    Module: OrderService
    Description: Knit service managing the full order lifecycle — creation, claiming,
                 preparation, and customer pickup — for the Ordering System.
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
	orderNum: string,
	customer: number, -- UserId
	order: { any },
	specs: { Spec }, -- one per item in `order`, derived by the server (OrderSpec.FromOrderItem)
	grade: Grade?, -- set when the barista deposits the order
	numItems: number,
	status: string,
	preparedBy: number?, -- UserId
	statusColor: Color3,
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
		-- Fired when a staff member's order notepad should update (SetNewOrder / ResetOrder)
		NotepadUpdated = Knit.CreateSignal(),
		-- Fired to show or hide a pick-up node UI indicator for a specific player
		PickUpNodeVisibilityChanged = Knit.CreateSignal(),
		-- Fired to surface an error/announcement to a specific player's UI
		Announcement = Knit.CreateSignal(),
		-- Fired when a player's queue position changes; position = nil means dequeued
		QueueUpdated = Knit.CreateSignal(),
	},

	-- Server-only signals (RealOrderService listens)
	OrderCreated = GoodSignal.new(),
	OrderPickedUp = GoodSignal.new(), -- (customerId, baristaPlayer, grade, specs, tools, items)

	_currentOrderNum = 0 :: number,
	_orders = {} :: { Order },
	_queue = {} :: { number }, -- ordered list of waiting barista UserIds
	_statusScreens = {} :: { SurfaceGui },
	_staffScreens = {} :: { SurfaceGui },
	_pickUpAreas = {} :: { Model },
	_orderDebounces = {} :: { [number]: boolean },
	_freeSince = {} :: { [number]: number }, -- UserId -> os.clock() when last free (idle-longest dispatch)

	-- Resolved in KnitStart after all services are ready
	_statisticsService = nil :: any,
	_questService = nil :: any,
	_shiftService = nil :: any,
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

-- Creates an invisible bounding-box PrimaryPart for a model that lacks one,
-- required before attaching a ProximityPrompt.
local function createPrimaryPart(model: Model)
	local orientation, size = model:GetBoundingBox()
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.CFrame = orientation
	part.Size = size
	part.Parent = model
	model.PrimaryPart = part
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

-- Returns the player's claimed ("Being Prepared") order to the queue, the same state
-- _updateOrders gives an order whose barista left, and resets their notepad and node
-- prompts. This is the way out of an order that cannot be made. A waiting barista
-- is handed the order straight away.
function OrderService:_releaseClaimedOrder(player: Player)
	local order = self:_getPlayerOrder(player.UserId, "Being Prepared")
	if not order then
		return
	end

	order.status = "Pending Preparation"
	order.statusColor = COLOR_PENDING
	order.preparedBy = nil

	self.Client.NotepadUpdated:Fire(player, "ResetOrder")
	for _, node in self._pickUpAreas do
		if node.OrderOwner.Value == 0 then
			self.Client.PickUpNodeVisibilityChanged:Fire(player, node, false)
		end
	end

	self:_tryDispatchFromQueue()
	self:_broadcastUpdate()
end

-- ShiftService.ClockedInChanged handler.
function OrderService:_onClockedInChanged(player: Player, clockedIn: boolean)
	if not clockedIn then
		self:_leaveQueue(player)
		self:_releaseClaimedOrder(player)
	else
		self._freeSince[player.UserId] = os.clock()
		self:_tryDispatchFromQueue()
		self:_broadcastUpdate()
	end
end

function OrderService:_canClaimOrder(player: Player): boolean
	return self:_isClockedIn(player) and self:_getPlayerOrder(player.UserId, "Being Prepared") == nil
end

-- Returns the oldest pending order, or nil if none exist.
function OrderService:_getNextOrder(): Order?
	local next: Order? = nil
	for _, order in self._orders do
		if order.status == "Pending Preparation" then
			if next == nil or order.orderNum < next.orderNum then
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
			end
		elseif order.status == "Being Prepared" then
			if not customer then
				table.remove(self._orders, i)
			elseif not Players:GetPlayerByUserId(order.preparedBy) then
				-- Staff left — put the order back in the queue
				order.status = "Pending Preparation"
				order.statusColor = COLOR_PENDING
				order.preparedBy = nil
			end
		end
	end

	-- Prune baristas who have left the game from the queue
	local queueChanged = false
	for i = #self._queue, 1, -1 do
		if not Players:GetPlayerByUserId(self._queue[i]) then
			table.remove(self._queue, i)
			queueChanged = true
		end
	end
	if queueChanged then
		self:_broadcastQueuePositions()
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
end

function OrderService:_updateStaffScreens()
	local nextOrder = self:_getNextOrder()
	local pendingCount = self:GetPendingCount()

	for _, screen in self._staffScreens do
		for _, frame in screen.Frame.Frame:GetChildren() do
			if frame:IsA("Frame") and frame.Visible then
				frame:Destroy()
			end
		end

		if nextOrder then
			screen.Parent.Parent.ProximityPrompt.Enabled = true

			local customer = Players:GetPlayerByUserId(nextOrder.customer)
			screen.Frame.Customer.Text = customer and customer.Name or "Unknown"
			screen.Frame.OrderNum.Text = "Order " .. nextOrder.orderNum
			screen.Frame.NumPending.Text = pendingCount .. (pendingCount == 1 and " Pending Order" or " Pending Orders")

			for _, item in nextOrder.order do
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
			screen.Parent.Parent.ProximityPrompt.Enabled = false
			screen.Frame.Customer.Text = ""
			screen.Frame.OrderNum.Text = ""
			screen.Frame.NumPending.Text = "0 Pending Orders"
		end

		-- AutomaticCanvasSize handles scrolling without server-side AbsoluteContentSize reads.
		screen.Frame.Frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
		screen.Frame.Frame.CanvasSize = UDim2.new(0, 0, 0, 0)
	end
end

function OrderService:_updateStatusScreens()
	for _, screen in self._statusScreens do
		for _, frame in screen.Frame.Frame:GetChildren() do
			if frame:IsA("ImageLabel") and frame.Visible then
				frame:Destroy()
			end
		end

		for _, order in self._orders do
			local customer = Players:GetPlayerByUserId(order.customer)
			local entry = screen.Frame.Frame.Template:Clone()
			entry.Name = order.orderNum
			entry.Order.Text = "Order " .. order.orderNum
			entry.Customer.Text = customer and customer.Name or "Unknown"
			entry.Status.Text = "Status: " .. order.status
			entry.Items.Text = order.numItems .. (order.numItems == 1 and " Item" or " Items")
			entry.ImageColor3 = order.statusColor
			entry.LayoutOrder = STATUS_PRIORITY[order.status] + (tonumber(order.orderNum) :: number)
			entry.Visible = true
			entry.Parent = screen.Frame.Frame
		end
	end
end

-- Runs all three update passes in one call.
function OrderService:_broadcastUpdate()
	self:_updateOrders()
	self:_updateStaffScreens()
	self:_updateStatusScreens()
end

function OrderService:_addOrder(customerId: number, orderItems: { any }, specs: { Spec })
	self._currentOrderNum += 1
	table.insert(self._orders, {
		orderNum = string.format("%04i", self._currentOrderNum % 1000),
		customer = customerId,
		order = orderItems,
		specs = specs,
		numItems = #orderItems,
		status = "Pending Preparation",
		preparedBy = nil,
		statusColor = COLOR_PENDING,
	})
	-- Immediately hand the order to the first barista in the queue, if any.
	self:_tryDispatchFromQueue()
	self:_broadcastUpdate()
	pcall(function()
		self.OrderCreated:Fire(customerId)
	end)
end

function OrderService:_claimNextOrder(player: Player)
	if not self:_canClaimOrder(player) then
		return
	end
	local nextOrder = self:_getNextOrder()
	if not nextOrder then
		return
	end

	nextOrder.status = "Being Prepared"
	nextOrder.preparedBy = player.UserId
	nextOrder.statusColor = COLOR_PREPARING

	self.Client.NotepadUpdated:Fire(player, "SetNewOrder", nextOrder.order)

	for _, node in self._pickUpAreas do
		if node.OrderOwner.Value == 0 then
			self.Client.PickUpNodeVisibilityChanged:Fire(player, node, true)
		end
	end

	self:_broadcastUpdate()
end

-- ── Queue helpers ─────────────────────────────────────────────────────────

function OrderService:_isInQueue(userId: number): boolean
	for _, id in self._queue do
		if id == userId then
			return true
		end
	end
	return false
end

-- Fires each queued player their current 1-based position.
function OrderService:_broadcastQueuePositions()
	for i, userId in self._queue do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			self.Client.QueueUpdated:Fire(player, i)
		end
	end
end

-- Appends a barista to the end of the waiting queue and notifies them.
function OrderService:_joinQueue(player: Player)
	if not self:_isClockedIn(player) then
		return
	end
	if self:_getPlayerOrder(player.UserId, "Being Prepared") then
		return
	end
	if self:_isInQueue(player.UserId) then
		return
	end
	table.insert(self._queue, player.UserId)
	self.Client.QueueUpdated:Fire(player, #self._queue)
end

-- Removes a barista from the queue and updates remaining positions.
function OrderService:_leaveQueue(player: Player)
	for i, userId in self._queue do
		if userId == player.UserId then
			table.remove(self._queue, i)
			self.Client.QueueUpdated:Fire(player, nil) -- nil = no longer queued
			self:_broadcastQueuePositions()
			return
		end
	end
end

-- Dequeues the first waiting barista and assigns the next pending order to them.
-- Called whenever a new order is placed and the queue is non-empty.
function OrderService:_tryDispatchFromQueue()
	local nextOrder = self:_getNextOrder()
	if not nextOrder then
		return
	end

	-- Walk the queue front-to-back, skipping any baristas who have since left
	while #self._queue > 0 do
		local staffId = table.remove(self._queue, 1)
		local staff = Players:GetPlayerByUserId(staffId)

		if staff and self:_isClockedIn(staff) and self:_getPlayerOrder(staffId, "Being Prepared") == nil then
			-- Assign the order
			nextOrder.status = "Being Prepared"
			nextOrder.preparedBy = staffId
			nextOrder.statusColor = COLOR_PREPARING

			self.Client.NotepadUpdated:Fire(staff, "SetNewOrder", nextOrder.order)
			self.Client.QueueUpdated:Fire(staff, nil) -- they've been dispatched, no longer queued

			for _, node in self._pickUpAreas do
				if node.OrderOwner.Value == 0 then
					self.Client.PickUpNodeVisibilityChanged:Fire(staff, node, true)
				end
			end

			self:_broadcastQueuePositions()
			return
		end
	end

	-- M2-REALORDER: nobody waiting in the queue. Auto-assign to the clocked-in
	-- barista with no active order who has been idle longest (no claim needed).
	local best: Player? = nil
	local bestSince = math.huge
	for _, staff in Players:GetPlayers() do
		if self:_canClaimOrder(staff) then
			local since = self._freeSince[staff.UserId] or 0
			if since < bestSince then
				best, bestSince = staff, since
			end
		end
	end
	if best then
		self:_claimNextOrder(best)
	end
end

-- Decides whether to claim immediately or join the queue when a barista
-- activates a staff screen prompt.
-- Rules:
--   • Pending orders exist AND queue is empty → claim directly (no wait).
--   • No pending orders OR queue already has waiters → join queue.
function OrderService:_handleClaimOrQueue(player: Player)
	if not self:_isClockedIn(player) then
		return
	end
	if self:_getPlayerOrder(player.UserId, "Being Prepared") then
		return -- already preparing an order
	end
	if self:_isInQueue(player.UserId) then
		return -- already waiting
	end

	local nextOrder = self:_getNextOrder()
	if nextOrder and #self._queue == 0 then
		self:_claimNextOrder(player)
	else
		self:_joinQueue(player)
	end
end

-- ──────────────────────────────────────────────────────────────────────────

-- Handles both paths of a pick-up area interaction:
--   • If the area belongs to the triggering player → they pick up their order.
--   • Otherwise → the player is a staff member depositing a prepared order.
function OrderService:_handlePickUp(player: Player, area: Model)
	local ownerValue: IntValue = area.OrderOwner

	if ownerValue.Value == player.UserId then
		-- ── Customer path: collect their completed order ──────────────────────
		self.Client.PickUpNodeVisibilityChanged:Fire(player, area, false)

		local pickedTools: { Instance } = {}
		local orderFolder = ServerStorage[ORDER_PICKUP_FOLDER]:FindFirstChild("Order_" .. player.UserId)
		if orderFolder then
			local tools = orderFolder:GetChildren()
			pickedTools = tools

			if self._statisticsService then
				self._statisticsService:IncrementStat(player, "ItemsOrdered", #tools)
			end

			for _, item in tools do
				if self._questService then
					local currentItem: string = (item:FindFirstChild("CurrentItem") and item.CurrentItem.Value)
						or item.Name
					-- Boba tools are named "[Flavor] Boba" (see Recipes Tapioca step).
					if string.find(currentItem, " Boba", 1, true) then
						if self._statisticsService then
							self._statisticsService:IncrementStat(player, "BobasOrdered", 1)
						end
						self._questService:AdvanceQuest(player, "BobaOrdered", 1)
					elseif string.find(currentItem, "Macaron") then
						self._questService:AdvanceQuest(player, "MacaronOrdered", 1)
					elseif string.find(currentItem, "Hot Chocolate") then
						self._questService:AdvanceQuest(player, "HotChocolateOrdered", 1)
					end
				end
				item.Parent = player.Backpack
			end

			orderFolder:Destroy()
		end

		for _, child in area:GetChildren() do
			if child:IsA("Model") then
				child:Destroy()
			end
		end

		ownerValue.Value = 0
		area.ProximityPrompt.ObjectText = "Pick Up Area"
		area.ProximityPrompt.ActionText = "Deposit Order"

		for i = #self._orders, 1, -1 do
			local order = self._orders[i]
			if order.customer == player.UserId and order.status == "Ready for Pick Up" then
				table.remove(self._orders, i)
				local barista = order.preparedBy and Players:GetPlayerByUserId(order.preparedBy) or nil
				local handed = pickedTools
				pcall(function()
					self.OrderPickedUp:Fire(player.UserId, barista, order.grade, order.specs, handed, order.order)
				end)
				if order.preparedBy then
					self._freeSince[order.preparedBy] = os.clock()
				end
			end
		end

		self:_updateStatusScreens()
		self:_tryDispatchFromQueue()
	else
		-- ── Staff path: deposit a prepared order ──────────────────────────────
		local playerOrder = self:_getPlayerOrder(player.UserId, "Being Prepared")
		if not playerOrder then
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
		local tools, grade, reasons = self:FindServeTools(player, playerOrder.specs)
		if not tools then
			self.Client.Announcement:Fire(
				player,
				"Cannot Deposit Order!",
				describeReasons(reasons) .. ". Check your order notepad and return when ready.",
				COLOR_ERROR
			)
			return
		end

		ownerValue.Value = playerOrder.customer

		-- Hide free pick-up nodes for this player now that the order is down
		for _, node in self._pickUpAreas do
			if node.OrderOwner.Value == 0 then
				self.Client.PickUpNodeVisibilityChanged:Fire(player, node, false)
			end
		end

		self.Client.NotepadUpdated:Fire(player, "ResetOrder")

		if self._statisticsService then
			self._statisticsService:IncrementStat(player, "OrdersPrepared", 1)
		end

		playerOrder.status = "Ready for Pick Up"
		playerOrder.statusColor = COLOR_READY
		playerOrder.grade = grade
		self._freeSince[player.UserId] = os.clock()
		self:_updateStatusScreens()
		self:_tryDispatchFromQueue()

		local orderFolder = Instance.new("Folder")
		orderFolder.Name = "Order_" .. playerOrder.customer
		orderFolder.Parent = ServerStorage[ORDER_PICKUP_FOLDER]

		for i, tool in tools do
			-- A served tool keeps its marks when picked up, so mark it spent: it can no
			-- longer satisfy another order (FindServeTools skips it).
			tool:SetAttribute("Served", true)
			if PICKUP_MODEL_OFFSETS[i] then
				local displayModel = createModelFromTool(tool)
				displayModel.Parent = area
				displayModel:PivotTo(
					area.CFrame * PICKUP_MODEL_OFFSETS[i] * CFrame.new(0, displayModel.PrimaryPart.Size.Y / 2, 0)
				)
			end
			tool.Parent = orderFolder
		end

		local customer = Players:GetPlayerByUserId(playerOrder.customer)
		if customer then
			area.ProximityPrompt.ObjectText = customer.Name .. "'s Order"
			area.ProximityPrompt.ActionText = "Pick Up Order"
			self.Client.PickUpNodeVisibilityChanged:Fire(customer, area, true, true)
		end
	end
end

---> Public Methods

-- Number of orders waiting for a barista to claim.
function OrderService:GetPendingCount(): number
	local count = 0
	for _, order in self._orders do
		if order.status == "Pending Preparation" then
			count += 1
		end
	end
	return count
end

-- True while the player is preparing a player-placed order (claimed, not yet
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

-- Any player may place an order for themselves. `customerId` must be the
-- caller's UserId; every argument is untrusted client input.
function OrderService.Client:CreateOrder(player: Player, customerId: any, orderItems: any): CreateOrderResult
	local server = self.Server

	if typeof(customerId) ~= "number" or typeof(orderItems) ~= "table" then
		return { Success = false, Message = "Invalid order." }
	end
	if customerId ~= player.UserId then
		return { Success = false, Message = "You can only place orders for yourself." }
	end
	if server._orderDebounces[player.UserId] then
		return { Success = false, Message = "Please wait before placing another order." }
	end

	local itemCount = #orderItems
	if itemCount < ORDER_MIN_ITEMS or itemCount > ORDER_MAX_ITEMS then
		return {
			Success = false,
			Message = string.format("Orders need %d to %d items.", ORDER_MIN_ITEMS, ORDER_MAX_ITEMS),
		}
	end

	local menu = getFoodTable()
	if not menu then
		return { Success = false, Message = "Ordering is unavailable right now." }
	end

	-- Only the array part is read, and each item is rebuilt from the server's Menu.
	-- The specs the deposit is graded against come from those rebuilt items.
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
			return { Success = false, Message = "That item isn't available right now." }
		end

		local item, spec, reason = buildOrderItem(menu, orderItems[i])
		if not item or not spec then
			warn(string.format("[OrderService] Rejected order from %s: %s", player.Name, tostring(reason)))
			return { Success = false, Message = "Invalid order." }
		end
		items[i] = item
		specs[i] = spec
	end

	if server:_hasOpenOrder(player.UserId) then
		return { Success = false, Message = "You already have an order in progress." }
	end

	server._orderDebounces[player.UserId] = true
	task.delay(ORDER_DEBOUNCE_SECONDS, function()
		server._orderDebounces[player.UserId] = nil
	end)

	server:_addOrder(player.UserId, items, specs)

	if server._statisticsService then
		server._statisticsService:IncrementStat(player, "OrdersCreated", 1)
	end

	return { Success = true, Message = "Order placed." }
end

-- Removes the calling player from the barista queue.
function OrderService.Client:LeaveQueue(player: Player)
	self.Server:_leaveQueue(player)
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

	-- Index staff screens and attach order-claim ProximityPrompts
	local staffScreens = orderingSystem:FindFirstChild("Staff Screens")
	if staffScreens then
		for _, desc in staffScreens:GetDescendants() do
			if desc:IsA("SurfaceGui") and desc.Name == "Screen" then
				table.insert(self._staffScreens, desc)

				local screenModel = desc.Parent.Parent
				createPrimaryPart(screenModel)

				local prompt = Instance.new("ProximityPrompt")
				prompt.HoldDuration = 0
				prompt.UIOffset = Vector2.new(0, -100)
				prompt.ObjectText = "Pending Orders Screen"
				prompt.ActionText = "Claim Order"
				prompt.RequiresLineOfSight = false
				prompt.Enabled = true
				prompt.Parent = screenModel

				prompt.Triggered:Connect(function(player: Player)
					self:_handleClaimOrQueue(player)
				end)
			end
		end
	else
		warn('[OrderService] "Ordering System.Staff Screens" missing; claiming orders disabled.')
	end

	-- Index pick-up areas and attach deposit/pickup ProximityPrompts
	local pickUp = orderingSystem:FindFirstChild("Pick Up")
	if pickUp then
		for _, node in pickUp:GetChildren() do
			table.insert(self._pickUpAreas, node)

			local ownerValue = Instance.new("IntValue")
			ownerValue.Name = "OrderOwner"
			ownerValue.Parent = node

			local prompt = Instance.new("ProximityPrompt")
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

	local questOk, questService = pcall(Knit.GetService, "QuestService")
	if questOk then
		self._questService = questService
	end

	-- Clocking out leaves the barista queue and returns a claimed order to it, so a
	-- barista who cannot make their order is never stuck with it.
	self._shiftService.ClockedInChanged:Connect(function(player: Player, clockedIn: boolean)
		self:_onClockedInChanged(player, clockedIn)
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
	-- _updateOrders (called inside _broadcastUpdate) handles queue pruning
	self:_broadcastUpdate()
end

return OrderService

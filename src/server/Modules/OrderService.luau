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
local Promise = require(Packages.Promise)
local RankUtil = require(ReplicatedStorage.Shared.Utility.RankUtil)

---> Types

type Order = {
	orderNum: string,
	customer: number, -- UserId
	order: { any },
	numItems: number,
	status: string,
	preparedBy: number?, -- UserId
	statusColor: Color3,
}

type ToolEntry = {
	Name: string,
	Tool: Tool,
}

---> Constants

local ORDERING_SYSTEM = workspace["Ordering System"]
local ORDER_PICKUP_FOLDER = "OrderPickUp"

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

	_currentOrderNum = 0 :: number,
	_orders = {} :: { Order },
	_queue = {} :: { number }, -- ordered list of waiting barista UserIds
	_statusScreens = {} :: { SurfaceGui },
	_staffScreens = {} :: { SurfaceGui },
	_pickUpAreas = {} :: { Model },
	_areaDebounces = {} :: { [Model]: boolean },
	_orderDebounces = {} :: { [number]: boolean },

	-- Resolved in KnitStart after all services are ready
	_dialogService = nil :: any,
	_statisticsService = nil :: any,
	_questService = nil :: any,
})

---> Private Helpers

-- Builds a display model from the non-Handle parts of a tool for placement at a
-- pick-up area. The model is auto-expired after 5 minutes via Debris.
local function createModelFromTool(tool: Tool): Model
	local model = Instance.new("Model")
	model.Parent = ReplicatedStorage.ModelStorage
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

---> Private Methods

function OrderService:_getPlayerOrder(userId: number, status: string): Order?
	for _, order in self._orders do
		if order.status == status and order.preparedBy == userId then
			return order
		end
	end
	return nil
end

function OrderService:_canClaimOrder(player: Player): boolean
	return RankUtil:CanEnterKitchen(player)
		and self:_getPlayerOrder(player.UserId, "Being Prepared") == nil
end

function OrderService:_getPendingCount(): number
	local count = 0
	for _, order in self._orders do
		if order.status == "Pending Preparation" then
			count += 1
		end
	end
	return count
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
	local pendingCount = self:_getPendingCount()

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
			screen.Frame.NumPending.Text = pendingCount
				.. (pendingCount == 1 and " Pending Order" or " Pending Orders")

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

function OrderService:_addOrder(customerId: number, orderItems: { any })
	self._currentOrderNum += 1
	table.insert(self._orders, {
		orderNum = string.format("%04i", self._currentOrderNum % 1000),
		customer = customerId,
		order = orderItems,
		numItems = #orderItems,
		status = "Pending Preparation",
		preparedBy = nil,
		statusColor = COLOR_PENDING,
	})
	-- Immediately hand the order to the first barista in the queue, if any.
	self:_tryDispatchFromQueue()
	self:_broadcastUpdate()
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
	if not RankUtil:CanEnterKitchen(player) then
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
	if #self._queue == 0 then
		return
	end
	local nextOrder = self:_getNextOrder()
	if not nextOrder then
		return
	end

	-- Walk the queue front-to-back, skipping any baristas who have since left
	while #self._queue > 0 do
		local staffId = table.remove(self._queue, 1)
		local staff = Players:GetPlayerByUserId(staffId)

		if staff and self:_getPlayerOrder(staffId, "Being Prepared") == nil then
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
end

-- Decides whether to claim immediately or join the queue when a barista
-- activates a staff screen prompt.
-- Rules:
--   • Pending orders exist AND queue is empty → claim directly (no wait).
--   • No pending orders OR queue already has waiters → join queue.
function OrderService:_handleClaimOrQueue(player: Player)
	if not RankUtil:CanEnterKitchen(player) then
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

-- Presents sequential ActionPrompt dialogs so the staff member can choose
-- which tools from their inventory to include in the deposited order.
-- Resolves with the selected ToolEntry array, or nil if the player cancelled.
function OrderService:_promptToolSelection(player: Player, toolList: { ToolEntry }, count: number)
	return Promise.new(function(resolve)
		local selected: { ToolEntry } = {}
		local remaining = { table.unpack(toolList) }

		local function selectNext()
			if #selected >= count then
				resolve(selected)
				return
			end

			local buttons = {}
			for _, entry in remaining do
				table.insert(buttons, { Text = entry.Name })
			end

			self._dialogService
				:CreateDialog(player, "ActionPrompt", {
					Title = string.format("Select Item %d of %d", #selected + 1, count),
					Text = "Choose an item from your inventory to deposit for this order.",
					Buttons = buttons,
					CloseText = "Cancel",
				})
				:andThen(function(choice: string?)
					if not choice or choice == "Cancel" then
						resolve(nil)
						return
					end
					for i, entry in remaining do
						if entry.Name == choice then
							table.insert(selected, entry)
							table.remove(remaining, i)
							break
						end
					end
					selectNext()
				end)
				:catch(function()
					resolve(nil)
				end)
		end

		selectNext()
	end)
end

-- Handles both paths of a pick-up area interaction:
--   • If the area belongs to the triggering player → they pick up their order.
--   • Otherwise → the player is a staff member depositing a prepared order.
function OrderService:_handlePickUp(player: Player, area: Model)
	if self._areaDebounces[area] then
		return
	end

	local ownerValue: IntValue = area.OrderOwner

	if ownerValue.Value == player.UserId then
		-- ── Customer path: collect their completed order ──────────────────────
		self.Client.PickUpNodeVisibilityChanged:Fire(player, area, false)

		local orderFolder = ServerStorage[ORDER_PICKUP_FOLDER]:FindFirstChild("Order_" .. player.UserId)
		if orderFolder then
			local tools = orderFolder:GetChildren()

			if self._statisticsService then
				self._statisticsService:AddToStatistic(player, "Items Ordered", #tools)
			end

			for _, item in tools do
				if self._questService then
					local currentItem: string = (item:FindFirstChild("CurrentItem") and item.CurrentItem.Value) or ""
					if currentItem == "[Syrup] Boba" then
						if self._statisticsService then
							self._statisticsService:AddToStatistic(player, "Bobas Ordered", 1)
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
			end
		end

		self:_updateStatusScreens()
	else
		-- ── Staff path: deposit a prepared order ──────────────────────────────
		local playerOrder = self:_getPlayerOrder(player.UserId, "Being Prepared")
		if not playerOrder then
			return
		end

		local toolList = collectTools(player.Character, player.Backpack)

		if #toolList < #playerOrder.order then
			self.Client.Announcement:Fire(
				player,
				"Cannot Deposit Order!",
				string.format(
					"The order requires %d item(s), but you only have %d. "
						.. "Check your order notepad and return when ready.",
					#playerOrder.order,
					#toolList
				),
				COLOR_ERROR
			)
			return
		end

		-- Lock this area against concurrent deposit attempts
		self._areaDebounces[area] = true
		ownerValue.Value = playerOrder.customer

		-- Hide free pick-up nodes for this player while they pick tools
		for _, node in self._pickUpAreas do
			if node.OrderOwner.Value == 0 then
				self.Client.PickUpNodeVisibilityChanged:Fire(player, node, false)
			end
		end

		self:_promptToolSelection(player, toolList, #playerOrder.order):andThen(function(selected: { ToolEntry }?)
			self._areaDebounces[area] = nil

			if not selected then
				-- Cancelled — release the area and restore node indicators
				ownerValue.Value = 0
				for _, node in self._pickUpAreas do
					if node.OrderOwner.Value == 0 then
						self.Client.PickUpNodeVisibilityChanged:Fire(player, node, true)
					end
				end
				return
			end

			self.Client.NotepadUpdated:Fire(player, "ResetOrder")

			if self._statisticsService then
				self._statisticsService:AddToStatistic(player, "Orders Prepared", 1)
			end

			playerOrder.status = "Ready for Pick Up"
			playerOrder.statusColor = COLOR_READY
			self:_updateStatusScreens()

			local orderFolder = Instance.new("Folder")
			orderFolder.Name = "Order_" .. playerOrder.customer
			orderFolder.Parent = ServerStorage[ORDER_PICKUP_FOLDER]

			for i, entry in selected do
				if PICKUP_MODEL_OFFSETS[i] then
					local displayModel = createModelFromTool(entry.Tool)
					displayModel.Parent = area
					displayModel:PivotTo(
						area.CFrame
							* PICKUP_MODEL_OFFSETS[i]
							* CFrame.new(0, displayModel.PrimaryPart.Size.Y / 2, 0)
					)
				end
				entry.Tool.Parent = orderFolder
			end

			local customer = Players:GetPlayerByUserId(playerOrder.customer)
			if customer then
				area.ProximityPrompt.ObjectText = customer.Name .. "'s Order"
				area.ProximityPrompt.ActionText = "Pick Up Order"
				self.Client.PickUpNodeVisibilityChanged:Fire(customer, area, true, true)
			end
		end)
	end
end

---> Public Methods

-- Called by a staff member (rank ≥ CanUseOrderingSystem) to submit a customer's order.
-- `customerId` is the UserId of the customer being served.
function OrderService.Client:CreateOrder(player: Player, customerId: number, orderItems: { any })
	if not customerId or not orderItems then
		return
	end
	if self.Server._orderDebounces[player.UserId] then
		return
	end
	if not RankUtil:CanUseOrderingSystem(player) then
		return
	end
	if #orderItems < ORDER_MIN_ITEMS or #orderItems > ORDER_MAX_ITEMS then
		return
	end

	self.Server._orderDebounces[player.UserId] = true
	self.Server:_addOrder(customerId, orderItems)

	if self.Server._statisticsService then
		self.Server._statisticsService:AddToStatistic(player, "Orders Created", 1)
	end

	task.delay(ORDER_DEBOUNCE_SECONDS, function()
		self.Server._orderDebounces[player.UserId] = nil
	end)
end

-- Removes the calling player from the barista queue.
function OrderService.Client:LeaveQueue(player: Player)
	self.Server:_leaveQueue(player)
end

---> Lifecycle

function OrderService:KnitInit()
	-- Ensure the server-side order pickup storage folder exists
	if not ServerStorage:FindFirstChild(ORDER_PICKUP_FOLDER) then
		local folder = Instance.new("Folder")
		folder.Name = ORDER_PICKUP_FOLDER
		folder.Parent = ServerStorage
	end

	-- Index status screens (customer-facing order boards)
	for _, desc in ORDERING_SYSTEM["Status Screens"]:GetDescendants() do
		if desc:IsA("SurfaceGui") and desc.Name == "Screen" then
			table.insert(self._statusScreens, desc)
		end
	end

	-- Index staff screens and attach order-claim ProximityPrompts
	for _, desc in ORDERING_SYSTEM["Staff Screens"]:GetDescendants() do
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

	-- Index pick-up areas and attach deposit/pickup ProximityPrompts
	for _, node in ORDERING_SYSTEM["Pick Up"]:GetChildren() do
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
end

function OrderService:KnitStart()
	-- Resolve cross-service references after all services have initialised
	self._dialogService = Knit.GetService("DialogService")

	local statsOk, statsService = pcall(Knit.GetService, Knit, "StatisticsService")
	if statsOk then
		self._statisticsService = statsService
	end

	local questOk, questService = pcall(Knit.GetService, Knit, "QuestService")
	if questOk then
		self._questService = questService
	end
end

function OrderService:PlayerRemoving(player: Player)
	self._orderDebounces[player.UserId] = nil
	-- _updateOrders (called inside _broadcastUpdate) handles queue pruning
	self:_broadcastUpdate()
end

return OrderService

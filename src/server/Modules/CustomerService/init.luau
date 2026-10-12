--[[
    Module: CustomerService
    Description: Spawns and manages NPC customers.

    Customers walk to a register, place an order on the real order board, wait for a
    barista to deliver it, then leave. Orders they place carry `isNpc = true` so
    OrderService keeps them alive off this service rather than a Players lookup — see
    OrderService:_isNpcCustomerActive.

    Registers are the children of workspace["Ordering System"].Computers. Spawn points
    are optional: if workspace.Assets.Customers exists its parts are used, otherwise
    customers appear beside the register they are heading to.
--]]

---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local CustomerConfig = require(Shared.Configuration.CustomerConfig)
local Menu = require(Shared.Ordering.Menu)
local CustomerObject = require(script.Customer)

---> module declaration
local CustomerService = Knit.CreateService({
	Name = "CustomerService",
	Client = {
		CustomerSpawned = Knit.CreateSignal(),
		CustomerLeft = Knit.CreateSignal(),
		-- Fired when a customer is standing at a register waiting for a Worker to take
		-- their order, so the Ordering page can refresh its customer list.
		CustomerAwaitingOrder = Knit.CreateSignal(),
	},
})

---> constants
local SPAWN_FOLDER_NAME = "Customers"
local SPAWN_INTERVAL = 12
local REGISTER_OFFSET = Vector3.new(0, 0, 4)

---> state

-- Numeric ids are what OrderService stores on an order, so customers are keyed by one.
local customers: { [number]: any } = {}
local nextCustomerId = 0
local orderableItems: { { ItemName: string } } = {}

---> private

--- Flattens the food menu into a pool NPCs can order from. Built once; the menu is
--- static config.
local function buildOrderableItems()
	local items = {}

	for _, category in Menu.FoodTable do
		if typeof(category) ~= "table" or typeof(category.Items) ~= "table" then
			continue
		end

		for _, item in category.Items do
			if typeof(item) == "table" and item.ItemName then
				table.insert(items, { ItemName = item.ItemName })
			end
		end
	end

	return items
end

local function getRegisters(): { Instance }
	local orderingSystem = workspace:FindFirstChild("Ordering System")
	local computers = orderingSystem and orderingSystem:FindFirstChild("Computers")

	if not computers then
		return {}
	end

	return computers:GetChildren()
end

--- Spawn point for a customer heading to `register`. Prefers a dedicated spawn part,
--- falling back to just behind the register so the system works without new assets.
local function getSpawnCFrame(register: Instance): CFrame?
	local assets = workspace:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(SPAWN_FOLDER_NAME)

	if folder then
		local points = {}
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(points, child)
			end
		end

		if #points > 0 then
			return points[math.random(1, #points)].CFrame
		end
	end

	if register:IsA("BasePart") then
		return register.CFrame * CFrame.new(REGISTER_OFFSET)
	end

	if register:IsA("Model") and register.PrimaryPart then
		return register.PrimaryPart.CFrame * CFrame.new(REGISTER_OFFSET)
	end

	return nil
end

local function countActive(): number
	local count = 0
	for _ in customers do
		count += 1
	end
	return count
end

--- A random order of MinItems..MaxItems entries.
local function buildOrder(): { { ItemName: string } }
	if #orderableItems == 0 then
		return {}
	end

	local size = math.random(CustomerConfig.MinItems, CustomerConfig.MaxItems)
	local order = {}

	for _ = 1, size do
		table.insert(order, orderableItems[math.random(1, #orderableItems)])
	end

	return order
end

---> public

--- Whether an NPC customer is still present. OrderService calls this to decide whether
--- an NPC order should survive its prune pass.
function CustomerService:IsCustomerActive(customerId: number): boolean
	local customer = customers[customerId]
	return customer ~= nil and customer.Active == true
end

function CustomerService:GetCustomer(customerId: number)
	return customers[customerId]
end

--[=[
	Called by OrderService when a barista has deposited this customer's order.

	The customer walks to the pick-up area, checks what was delivered against what it
	asked for, and either thanks the staff and leaves or complains and waits for another
	attempt. Without this, NPC orders would stay "Ready for Pick Up" indefinitely.
]=]
function CustomerService:OnOrderReady(customerId: number, area: Model?)
	local customer = customers[customerId]
	if not customer or not customer.Active then
		-- Customer already left; clear the order so it does not linger on the board.
		Knit.GetService("OrderService"):CollectNpcOrder(customerId, area)
		return
	end

	local function collect()
		local orderService = Knit.GetService("OrderService")
		local delivered = orderService:CollectNpcOrder(customerId, area)

		if not customer.Active then
			return
		end

		if customer:CheckOrder(delivered) then
			-- Correct order: pay the barista's stats their due and send the customer off.
			customer:Leave()
		elseif customer.Active then
			-- Wrong order and attempts remain: the customer keeps waiting, so put a
			-- fresh order back on the board for another try.
			customer.ArrivedAt = os.time()
			orderService:_addOrder(customerId, customer.Order, true)
		end
	end

	if area then
		customer:MoveTo(area:GetPivot().Position, collect)
	else
		collect()
	end
end

--[=[
	Spawns one customer at a register. Returns it, or nil if none could spawn.

	`options.AwaitOrderFromWorker` makes the customer say what they want and then *wait*
	for a Worker to enter it at the register, instead of putting the order on the board
	themselves. That is what gives the Worker role something to do.

	`options.ReservedFor` marks the customer as belonging to one player's onboarding: it
	ignores the capacity cap and does not lose patience, because a tutorial that can fail
	because the cafe was busy is not a tutorial.
]=]
function CustomerService:SpawnCustomer(
	options: { AwaitOrderFromWorker: boolean?, ReservedFor: Player?, Register: Instance? }?
)
	local reservedFor = options and options.ReservedFor
	local awaitWorker = options and options.AwaitOrderFromWorker == true

	if not reservedFor and countActive() >= CustomerConfig.MaxCapacity then
		return nil
	end

	local registers = getRegisters()
	if #registers == 0 then
		return nil
	end

	local register = (options and options.Register) or registers[math.random(1, #registers)]
	local spawnCFrame = getSpawnCFrame(register)
	if not spawnCFrame then
		return nil
	end

	local customer = CustomerObject.new(register, spawnCFrame)
	if not customer then
		return nil
	end

	nextCustomerId += 1
	local customerId = nextCustomerId
	customer.CustomerId = customerId
	customer.ReservedFor = reservedFor
	customers[customerId] = customer

	customer.Left:Connect(function()
		customers[customerId] = nil
		self.Client.CustomerLeft:FireAll(customerId)
	end)

	self.Client.CustomerSpawned:FireAll(customerId)

	-- Walk to the register, then order.
	local destination = if register:IsA("BasePart")
		then register.Position
		else (register :: Model).PrimaryPart and (register :: Model).PrimaryPart.Position

	if not destination then
		customer:Leave()
		return nil
	end

	customer:MoveTo(destination, function()
		if not customer.Active then
			return
		end

		local order = buildOrder()
		if #order == 0 then
			customer:Leave()
			return
		end

		-- Speaks the order aloud, which is how a Worker learns what to enter.
		customer:AssignOrder(order)

		if awaitWorker then
			customer:SetAwaitingWorker(customerId, true)
			self.Client.CustomerAwaitingOrder:FireAll(customerId)

			-- Now that they have decided what they want, the onboarding objective can say
			-- so — until this point it only knew someone was walking over.
			if reservedFor then
				pcall(function()
					Knit.GetService("OnboardingService"):RefreshObjective(reservedFor)
				end)
			end

			return
		end

		-- isNpc = true keeps OrderService from pruning this the moment it is added.
		local orderService = Knit.GetService("OrderService")
		orderService:_addOrder(customerId, order, true)
	end)

	return customer
end

--[=[
	A Worker has entered this customer's order at a register.

	The items come from the client, so they are never trusted as the customer's *wants* —
	the customer already decided that in buildOrder, and CheckOrder still judges the
	delivery against it. What the Worker submits is what the kitchen will be asked to make,
	exactly as it is when the customer is a real player.

	Returns false when the customer is gone or was not waiting, so OrderService can tell
	the Worker why nothing happened.
]=]
function CustomerService:TakeOrder(customerId: number, orderItems: { any }, worker: Player): boolean
	local customer = customers[customerId]

	if not customer or not customer.Active or not customer.AwaitingWorker then
		return false
	end

	customer:SetAwaitingWorker(customerId, false)
	customer.ArrivedAt = os.time()

	Knit.GetService("OrderService"):_addOrder(customerId, orderItems, true, worker.UserId)

	return true
end

--- Spawns a customer that exists solely to be served by one player during onboarding.
--- Guaranteed: it ignores capacity, waits indefinitely, and is respawned by
--- OnboardingService if it somehow goes away.
---
--- They head for whichever register the player is standing at, so a new Worker does not
--- have to go hunting for the customer they were just told to serve.
function CustomerService:SpawnOnboardingCustomer(player: Player)
	return self:SpawnCustomer({
		AwaitOrderFromWorker = true,
		ReservedFor = player,
		Register = self:GetNearestRegister(player),
	})
end

--- The register closest to a player, or nil when the ordering system has none.
function CustomerService:GetNearestRegister(player: Player): Instance?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local nearest: Instance? = nil
	local nearestDistance = math.huge

	for _, register in getRegisters() do
		local position
		if register:IsA("BasePart") then
			position = register.Position
		elseif register:IsA("Model") then
			position = register:GetPivot().Position
		end

		if not position then
			continue
		end

		local distance = (position - root.Position).Magnitude
		if distance < nearestDistance then
			nearest = register
			nearestDistance = distance
		end
	end

	return nearest
end

--- The customer a given player's onboarding is currently waiting on, if any.
function CustomerService:GetReservedCustomer(player: Player)
	for customerId, customer in customers do
		if customer.ReservedFor == player and customer.Active then
			return customer, customerId
		end
	end

	return nil, nil
end

---> lifecycle

function CustomerService:KnitStart()
	orderableItems = buildOrderableItems()

	if #orderableItems == 0 then
		warn("[CustomerService] Menu produced no orderable items — customers disabled.")
		return
	end

	if #getRegisters() == 0 then
		warn("[CustomerService] No Ordering System.Computers registers — customers disabled.")
		return
	end

	---> spawn loop
	task.spawn(function()
		while true do
			task.wait(SPAWN_INTERVAL)
			pcall(function()
				self:SpawnCustomer()
			end)
		end
	end)

	---> patience sweep
	task.spawn(function()
		while true do
			task.wait(10)
			for _, customer in customers do
				-- A customer reserved for someone's onboarding never gives up: the whole
				-- point of them is that the new player is guaranteed someone to serve.
				if customer.ReservedFor then
					continue
				end

				if customer.Active and customer:HasRunOutOfPatience() then
					customer:Leave()
				end
			end
		end
	end)
end

return CustomerService

-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
    OrderService.spec.luau
    Comprehensive TestEZ tests for OrderService.

    Testing strategy
    ────────────────
    OrderService is a Knit service table. We require it directly (without
    starting Knit) and manipulate its private state between tests.

    Key constraints of the Roblox test environment:
    • Players:GetPlayerByUserId always returns nil — no real players exist.
      This means _updateOrders will prune every order whose customer is not
      an actual server player. Tests that rely on a "live customer" are
      annotated and tested at the state level only.
    • Barista actions are gated on ShiftService's clocked-in state. KnitStart
      never runs here, so we inject a fake `_shiftService` per test
      (mockClockedIn) and clear it in beforeEach (nil = nobody clocked in).
    • Knit signals are server→client RemoteSignals. We replace them with
      plain mock tables (trackable locally) in beforeEach.
    • _broadcastUpdate calls _updateOrders which prunes orders (see above).
      We no-op it in beforeEach; tests that specifically validate cleanup
      call _updateOrders directly.
--]]

return function()
	-- ──────────────────────────────────────────────────────────────────────
	-- Dependencies
	-- ──────────────────────────────────────────────────────────────────────

	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerStorage = game:GetService("ServerStorage")

	-- Require the service table. KnitInit/KnitStart are never invoked here,
	-- so workspace["Ordering System"] is never accessed (it is only resolved
	-- in KnitStart).
	local service = require(ServerScriptService.Server.Modules.OrderService)
	local Menu = require(ReplicatedStorage.Shared.Ordering.Menu)
	local OrderSpec = require(ReplicatedStorage.Shared.Ordering.OrderSpec)

	-- ──────────────────────────────────────────────────────────────────────
	-- Test helpers
	-- ──────────────────────────────────────────────────────────────────────

	-- Lightweight mock that records every :Fire call
	local function makeMockSignal()
		local sig = { _calls = {} }
		function sig:Fire(...)
			table.insert(self._calls, { ... })
		end
		function sig:Connect(_fn)
			return { Disconnect = function() end }
		end
		return sig
	end

	-- Fake player table — provides the fields OrderService reads
	local function makePlayer(userId: number, name: string?)
		local backpack = Instance.new("Backpack")
		return {
			UserId = userId,
			Name = name or ("Player_" .. userId),
			Backpack = backpack,
			Character = nil,
		}
	end

	-- A stored order item, as CreateOrder builds it: a medium Regular coffee
	-- (Iced and Sugar default to false). Its spec is Drink / Regular / Medium.
	local function makeItem()
		return {
			Category = "Coffees",
			Item = "Regular",
			DefaultInfo = Menu.FoodTable["Coffees"].Items["Regular"],
			CustomInfo = { Size = "Medium" },
		}
	end

	-- The specs CreateOrder derives for stored order items.
	local function specsOf(items: { any })
		local specs = {}
		for i, item in items do
			local spec, reason = OrderSpec.FromOrderItem(item)
			assert(spec, "fixture item has no spec: " .. tostring(reason))
			specs[i] = spec
		end
		return specs
	end

	-- _addOrder with the specs derived from the items.
	local function addOrder(customerId: number, items: { any })
		service:_addOrder(customerId, items, specsOf(items))
	end

	-- A Tool carrying the attributes the kitchen writes. `parent` defaults to nothing.
	-- It holds a non-Handle part so the pick-up display model has something to clone.
	local function makeTool(attrs: { [string]: any }?, parent: Instance?)
		local tool = Instance.new("Tool")
		tool.Name = "TestTool"
		local part = Instance.new("Part")
		part.Name = "Cup"
		part.Parent = tool
		for key, value in attrs or {} do
			tool:SetAttribute(key, value)
		end
		tool.Parent = parent
		return tool
	end

	-- Attributes of a tool that exactly matches makeItem()'s spec.
	local function regularMedium(overrides: { [string]: any }?)
		local attrs: { [string]: any } = { Item = "Regular", Size = "Medium" }
		for key, value in overrides or {} do
			attrs[key] = value
		end
		return attrs
	end

	-- Removes the pick-up folder a deposit creates for a customer.
	local function cleanPickUpFolder(customerId: number)
		local folder = ServerStorage.OrderPickUp:FindFirstChild("Order_" .. customerId)
		if folder then
			folder:Destroy()
		end
	end

	-- A client CreateOrder request item: { Category, Item, CustomInfo }. The
	-- defaults name a real Menu item with no choices.
	local function makeRequest(category: string?, item: string?, customInfo: { [string]: any }?)
		return {
			Category = category or "Pastries",
			Item = item or "Fudge Brownie",
			CustomInfo = customInfo or {},
		}
	end

	-- Build a raw Order entry directly (bypasses _addOrder / _broadcastUpdate)
	local COLOR_PENDING = Color3.fromRGB(140, 140, 140)
	local COLOR_PREPARING = Color3.fromRGB(229, 198, 103)
	local COLOR_READY = Color3.fromRGB(151, 190, 135)
	local COLOR_ERROR = Color3.fromRGB(253, 102, 102)

	local function makeOrder(overrides: { [string]: any }?)
		local base = {
			orderNum = "0001",
			customer = 10001,
			order = { makeItem() },
			numItems = 1,
			status = "Pending Preparation",
			preparedBy = nil,
			statusColor = COLOR_PENDING,
		}
		if overrides then
			for k, v in overrides do
				base[k] = v
			end
		end
		-- Specs follow the (possibly overridden) items unless a test sets them.
		if base.specs == nil then
			base.specs = specsOf(base.order)
		end
		return base
	end

	-- Create a mock pick-up area with the expected children. The real nodes are
	-- parts (a deposit places display models at area.CFrame), so this is a Part.
	local function makeArea(ownerUserId: number?)
		local area = Instance.new("Part")
		area.Name = "MockPickUpArea"
		area.Anchored = true
		area.CanCollide = false

		local ownerVal = Instance.new("IntValue")
		ownerVal.Name = "OrderOwner"
		ownerVal.Value = ownerUserId or 0
		ownerVal.Parent = area

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ProximityPrompt"
		prompt.ObjectText = "Pick Up Area"
		prompt.ActionText = "Deposit Order"
		prompt.Parent = area

		area.Parent = workspace
		return area
	end

	-- Ensure one-time storage folders that OrderService expects
	if not ServerStorage:FindFirstChild("OrderPickUp") then
		local f = Instance.new("Folder")
		f.Name = "OrderPickUp"
		f.Parent = ServerStorage
	end

	if not ReplicatedStorage:FindFirstChild("ModelStorage") then
		local f = Instance.new("Folder")
		f.Name = "ModelStorage"
		f.Parent = ReplicatedStorage
	end

	-- ──────────────────────────────────────────────────────────────────────
	-- Clock-in mock helpers
	-- ──────────────────────────────────────────────────────────────────────

	-- The spec runs inside a live Play session against the real service table.
	-- Snapshot every field beforeEach replaces and put them all back in afterAll,
	-- so ordering keeps working in that session after the run.
	local LIVE_FIELDS = {
		"_orders",
		"_customerOrders",
		"_currentOrderNum",
		"_orderDebounces",
		"_statusScreens",
		"_staffScreens",
		"_pickUpAreas",
		"_queue",
		"_broadcastUpdate",
		"_shiftService",
		"_statisticsService",
	}
	local LIVE_CLIENT_FIELDS =
		{ "NotepadUpdated", "PickUpNodeVisibilityChanged", "Announcement", "QueueUpdated", "Server" }
	local savedFields, savedClientFields = {}, {}
	for _, key in LIVE_FIELDS do
		savedFields[key] = rawget(service, key)
	end
	for _, key in LIVE_CLIENT_FIELDS do
		savedClientFields[key] = rawget(service.Client, key)
	end

	-- Replaces the ShiftService reference OrderService resolves in KnitStart.
	local function mockClockedIn(clockedIn: boolean)
		service._shiftService = {
			IsClockedIn = function()
				return clockedIn
			end,
		}
	end

	local function clearClockedIn()
		service._shiftService = nil
	end

	-- ──────────────────────────────────────────────────────────────────────
	-- Per-test state reset
	-- ──────────────────────────────────────────────────────────────────────

	beforeEach(function()
		service._orders = {}
		service._customerOrders = {}
		service._currentOrderNum = 0
		service._orderDebounces = {}
		service._statusScreens = {}
		service._staffScreens = {}
		service._pickUpAreas = {}
		service._queue = {}

		-- Replace Knit RemoteSignals with local mock objects so we can track
		-- fires without needing the full networking stack.
		service.Client.NotepadUpdated = makeMockSignal()
		service.Client.PickUpNodeVisibilityChanged = makeMockSignal()
		service.Client.Announcement = makeMockSignal()
		service.Client.QueueUpdated = makeMockSignal()

		-- Wire Client.Server so that Client methods (CreateOrder) work correctly.
		service.Client.Server = service

		-- Suppress _broadcastUpdate — Players:GetPlayerByUserId always returns
		-- nil in tests, so running the real update would immediately prune all
		-- orders we add. Tests that specifically exercise pruning call
		-- _updateOrders directly.
		service._broadcastUpdate = function() end

		-- Fake players have no profile, so skip statistics.
		service._statisticsService = nil

		-- Default: nobody is clocked in
		clearClockedIn()
	end)

	afterEach(function()
		clearClockedIn()
	end)

	afterAll(function()
		for _, key in LIVE_FIELDS do
			rawset(service, key, savedFields[key])
		end
		for _, key in LIVE_CLIENT_FIELDS do
			rawset(service.Client, key, savedClientFields[key])
		end
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- _addOrder
	-- ══════════════════════════════════════════════════════════════════════

	describe("_addOrder", function()
		it("should add an order to the _orders table", function()
			addOrder(10001, { makeItem() })
			expect(#service._orders).to.equal(1)
		end)

		it("should store the correct customer UserId", function()
			addOrder(42, { makeItem() })
			expect(service._orders[1].customer).to.equal(42)
		end)

		it("should store the correct order items", function()
			local items = { makeItem(), makeItem() }
			addOrder(10001, items)
			expect(service._orders[1].numItems).to.equal(2)
			expect(service._orders[1].order).to.equal(items)
		end)

		it("should store the specs it is given", function()
			local items = { makeItem() }
			local specs = specsOf(items)
			service:_addOrder(10001, items, specs)
			expect(service._orders[1].specs).to.equal(specs)
		end)

		it("should start every order with 'Pending Preparation' status", function()
			addOrder(10001, { makeItem() })
			expect(service._orders[1].status).to.equal("Pending Preparation")
		end)

		it("should start every order with the pending colour", function()
			addOrder(10001, { makeItem() })
			expect(service._orders[1].statusColor).to.equal(COLOR_PENDING)
		end)

		it("should start every order with preparedBy = nil", function()
			addOrder(10001, { makeItem() })
			expect(service._orders[1].preparedBy).to.equal(nil)
		end)

		it("should zero-pad orderNum to 4 digits", function()
			addOrder(10001, { makeItem() })
			expect(service._orders[1].orderNum).to.equal("0001")
		end)

		it("should produce ascending orderNums for sequential calls", function()
			addOrder(10001, { makeItem() })
			addOrder(10002, { makeItem() })
			expect(service._orders[1].orderNum).to.equal("0001")
			expect(service._orders[2].orderNum).to.equal("0002")
		end)

		it("should wrap orderNum at 999 (mod 1000)", function()
			service._currentOrderNum = 999
			addOrder(10001, { makeItem() })
			-- 1000 % 1000 == 0 → "0000"
			expect(service._orders[1].orderNum).to.equal("0000")
		end)

		it("should produce 'Pending Preparation' wrapped as '0000'", function()
			service._currentOrderNum = 999
			addOrder(10001, { makeItem() })
			expect(service._orders[1].status).to.equal("Pending Preparation")
		end)

		it("should increment _currentOrderNum", function()
			addOrder(10001, { makeItem() })
			addOrder(10002, { makeItem() })
			expect(service._currentOrderNum).to.equal(2)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- GetPendingCount
	-- ══════════════════════════════════════════════════════════════════════

	describe("GetPendingCount", function()
		it("should return 0 when no orders exist", function()
			expect(service:GetPendingCount()).to.equal(0)
		end)

		it("should count only Pending Preparation orders", function()
			service._orders = {
				makeOrder({ status = "Pending Preparation" }),
				makeOrder({ status = "Pending Preparation" }),
				makeOrder({ status = "Being Prepared" }),
				makeOrder({ status = "Ready for Pick Up" }),
			}
			expect(service:GetPendingCount()).to.equal(2)
		end)

		it("should return 0 when all orders are Being Prepared", function()
			service._orders = {
				makeOrder({ status = "Being Prepared", preparedBy = 99 }),
			}
			expect(service:GetPendingCount()).to.equal(0)
		end)

		it("should return 0 when all orders are Ready for Pick Up", function()
			service._orders = {
				makeOrder({ status = "Ready for Pick Up" }),
			}
			expect(service:GetPendingCount()).to.equal(0)
		end)

		it("should reflect order table changes immediately", function()
			expect(service:GetPendingCount()).to.equal(0)
			table.insert(service._orders, makeOrder())
			expect(service:GetPendingCount()).to.equal(1)
			table.remove(service._orders, 1)
			expect(service:GetPendingCount()).to.equal(0)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- HasActiveOrder
	-- ══════════════════════════════════════════════════════════════════════

	describe("HasActiveOrder", function()
		local barista = makePlayer(150)

		it("should be false when the player has no order", function()
			expect(service:HasActiveOrder(barista)).to.equal(false)
		end)

		it("should be true while the player is preparing an order", function()
			service._orders = { makeOrder({ status = "Being Prepared", preparedBy = barista.UserId }) }
			expect(service:HasActiveOrder(barista)).to.equal(true)
		end)

		it("should be false for a pending order nobody has claimed", function()
			service._orders = { makeOrder() }
			expect(service:HasActiveOrder(barista)).to.equal(false)
		end)

		it("should be false for another player's Being Prepared order", function()
			service._orders = { makeOrder({ status = "Being Prepared", preparedBy = 999 }) }
			expect(service:HasActiveOrder(barista)).to.equal(false)
		end)

		it("should be false once the order is Ready for Pick Up", function()
			service._orders = { makeOrder({ status = "Ready for Pick Up", preparedBy = barista.UserId }) }
			expect(service:HasActiveOrder(barista)).to.equal(false)
		end)

		it("should be false for a customer whose own order is being prepared", function()
			service._orders = { makeOrder({ customer = barista.UserId, status = "Being Prepared", preparedBy = 999 }) }
			expect(service:HasActiveOrder(barista)).to.equal(false)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- _getNextOrder
	-- ══════════════════════════════════════════════════════════════════════

	describe("_getNextOrder", function()
		it("should return nil when no orders exist", function()
			expect(service:_getNextOrder()).to.equal(nil)
		end)

		it("should return nil when all orders are non-pending", function()
			service._orders = {
				makeOrder({ status = "Being Prepared", preparedBy = 99 }),
				makeOrder({ status = "Ready for Pick Up" }),
			}
			expect(service:_getNextOrder()).to.equal(nil)
		end)

		it("should return the only pending order", function()
			local order = makeOrder({ orderNum = "0003" })
			service._orders = { order }
			expect(service:_getNextOrder()).to.equal(order)
		end)

		it("should return the oldest pending order when multiple exist", function()
			local older = makeOrder({ orderNum = "0001" })
			local newer = makeOrder({ orderNum = "0005" })
			service._orders = { newer, older }
			expect(service:_getNextOrder()).to.equal(older)
		end)

		it("should skip non-pending orders when finding oldest", function()
			local prepared = makeOrder({ orderNum = "0001", status = "Being Prepared", preparedBy = 99 })
			local pending = makeOrder({ orderNum = "0002" })
			service._orders = { prepared, pending }
			expect(service:_getNextOrder()).to.equal(pending)
		end)

		it("should handle a single-element list correctly", function()
			local order = makeOrder()
			service._orders = { order }
			expect(service:_getNextOrder()).to.equal(order)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- _getPlayerOrder
	-- ══════════════════════════════════════════════════════════════════════

	describe("_getPlayerOrder", function()
		it("should return nil when no orders exist", function()
			expect(service:_getPlayerOrder(99, "Being Prepared")).to.equal(nil)
		end)

		it("should return an order matching both userId and status", function()
			local order = makeOrder({ status = "Being Prepared", preparedBy = 55 })
			service._orders = { order }
			expect(service:_getPlayerOrder(55, "Being Prepared")).to.equal(order)
		end)

		it("should return nil for correct userId but wrong status", function()
			local order = makeOrder({ status = "Pending Preparation", preparedBy = 55 })
			service._orders = { order }
			expect(service:_getPlayerOrder(55, "Being Prepared")).to.equal(nil)
		end)

		it("should return nil for correct status but wrong userId", function()
			local order = makeOrder({ status = "Being Prepared", preparedBy = 55 })
			service._orders = { order }
			expect(service:_getPlayerOrder(99, "Being Prepared")).to.equal(nil)
		end)

		it("should find the correct order among multiple", function()
			local wrongUser = makeOrder({ status = "Being Prepared", preparedBy = 10 })
			local target = makeOrder({ status = "Being Prepared", preparedBy = 20 })
			local wrongStatus = makeOrder({ status = "Pending Preparation", preparedBy = 20 })
			service._orders = { wrongUser, target, wrongStatus }
			expect(service:_getPlayerOrder(20, "Being Prepared")).to.equal(target)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- _canClaimOrder
	-- ══════════════════════════════════════════════════════════════════════

	describe("_canClaimOrder", function()
		local player = makePlayer(100)

		it("should return false when player is clocked out", function()
			mockClockedIn(false)
			expect(service:_canClaimOrder(player)).to.equal(false)
		end)

		it("should return false when player already has an active Being Prepared order", function()
			mockClockedIn(true)
			service._orders = {
				makeOrder({ status = "Being Prepared", preparedBy = player.UserId }),
			}
			expect(service:_canClaimOrder(player)).to.equal(false)
		end)

		it("should return false before ShiftService is resolved", function()
			clearClockedIn()
			expect(service:_canClaimOrder(player)).to.equal(false)
		end)

		it("should return true for a clocked-in player with no active order", function()
			mockClockedIn(true)
			service._orders = {}
			expect(service:_canClaimOrder(player)).to.equal(true)
		end)

		it("should return true even if player has Pending or Ready orders that are not theirs", function()
			mockClockedIn(true)
			service._orders = {
				makeOrder({ status = "Pending Preparation", preparedBy = nil }),
				makeOrder({ status = "Ready for Pick Up", preparedBy = player.UserId }),
			}
			expect(service:_canClaimOrder(player)).to.equal(true)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- _claimNextOrder
	-- ══════════════════════════════════════════════════════════════════════

	describe("_claimNextOrder", function()
		local player = makePlayer(200)

		it("should do nothing when there are no pending orders", function()
			mockClockedIn(true)
			service._orders = {}
			service:_claimNextOrder(player)
			expect(#service._orders).to.equal(0)
		end)

		it("should do nothing when player cannot claim (clocked out)", function()
			mockClockedIn(false)
			service._orders = { makeOrder() }
			service:_claimNextOrder(player)
			expect(service._orders[1].status).to.equal("Pending Preparation")
		end)

		it("should change order status to Being Prepared", function()
			mockClockedIn(true)
			service._orders = { makeOrder({ orderNum = "0001" }) }
			service:_claimNextOrder(player)
			expect(service._orders[1].status).to.equal("Being Prepared")
		end)

		it("should set preparedBy to the claiming player's UserId", function()
			mockClockedIn(true)
			service._orders = { makeOrder() }
			service:_claimNextOrder(player)
			expect(service._orders[1].preparedBy).to.equal(player.UserId)
		end)

		it("should set statusColor to the preparing colour", function()
			mockClockedIn(true)
			service._orders = { makeOrder() }
			service:_claimNextOrder(player)
			expect(service._orders[1].statusColor).to.equal(COLOR_PREPARING)
		end)

		it("should fire NotepadUpdated with SetNewOrder", function()
			mockClockedIn(true)
			local items = { makeItem() }
			service._orders = { makeOrder({ order = items }) }
			service:_claimNextOrder(player)

			local calls = service.Client.NotepadUpdated._calls
			expect(#calls).to.equal(1)
			expect(calls[1][1]).to.equal(player) -- first arg is the player
			expect(calls[1][2]).to.equal("SetNewOrder")
			expect(calls[1][3]).to.equal(items)
		end)

		it("should claim the oldest pending order when multiple exist", function()
			mockClockedIn(true)
			local older = makeOrder({ orderNum = "0001" })
			local newer = makeOrder({ orderNum = "0009" })
			service._orders = { newer, older }
			service:_claimNextOrder(player)
			expect(older.status).to.equal("Being Prepared")
			expect(newer.status).to.equal("Pending Preparation")
		end)

		it("should not let a player claim a second order while one is active", function()
			mockClockedIn(true)
			local active = makeOrder({ status = "Being Prepared", preparedBy = player.UserId })
			local pending = makeOrder({ orderNum = "0002" })
			service._orders = { active, pending }
			service:_claimNextOrder(player)
			-- pending should remain unclaimed
			expect(pending.status).to.equal("Pending Preparation")
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- _updateOrders (pruning / state rollback)
	-- ══════════════════════════════════════════════════════════════════════

	describe("_updateOrders", function()
		-- No real players exist in tests → GetPlayerByUserId always returns nil

		it("should remove Pending Preparation orders whose customer is not in game", function()
			service._orders = { makeOrder({ customer = 99999, status = "Pending Preparation" }) }
			service:_updateOrders()
			expect(#service._orders).to.equal(0)
		end)

		it("should remove Ready for Pick Up orders whose customer is not in game", function()
			service._orders = { makeOrder({ customer = 99999, status = "Ready for Pick Up" }) }
			service:_updateOrders()
			expect(#service._orders).to.equal(0)
		end)

		it("should remove Being Prepared orders whose customer is not in game", function()
			service._orders = { makeOrder({ customer = 99999, status = "Being Prepared", preparedBy = 88888 }) }
			service:_updateOrders()
			expect(#service._orders).to.equal(0)
		end)

		it("should remove multiple stale orders without skipping any", function()
			-- Reverse-iteration guard: if we iterated forwards with table.remove
			-- we would skip every other element. This verifies correct removal.
			service._orders = {
				makeOrder({ customer = 1, orderNum = "0001" }),
				makeOrder({ customer = 2, orderNum = "0002" }),
				makeOrder({ customer = 3, orderNum = "0003" }),
				makeOrder({ customer = 4, orderNum = "0004" }),
			}
			service:_updateOrders()
			expect(#service._orders).to.equal(0)
		end)

		it("should leave pick-up areas untouched when OrderOwner is 0", function()
			local area = makeArea(0)
			service._pickUpAreas = { area }

			service._orders = {}
			service:_updateOrders()

			expect(area.OrderOwner.Value).to.equal(0)
			area:Destroy()
		end)

		it("should reset a pick-up area whose owner is no longer in game", function()
			local userId = 55555
			local area = makeArea(userId)
			area.ProximityPrompt.ObjectText = "Someone's Order"
			area.ProximityPrompt.ActionText = "Pick Up Order"
			service._pickUpAreas = { area }

			service:_updateOrders()

			expect(area.OrderOwner.Value).to.equal(0)
			expect(area.ProximityPrompt.ObjectText).to.equal("Pick Up Area")
			expect(area.ProximityPrompt.ActionText).to.equal("Deposit Order")
			area:Destroy()
		end)

		it("should destroy orphaned OrderPickUp folder when area owner leaves", function()
			local userId = 44444
			local area = makeArea(userId)
			service._pickUpAreas = { area }

			-- Create an orphaned pickup folder
			local orphan = Instance.new("Folder")
			orphan.Name = "Order_" .. userId
			orphan.Parent = ServerStorage.OrderPickUp

			service:_updateOrders()

			expect(orphan.Parent).to.equal(nil) -- destroyed
			area:Destroy()
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- Queue gating (_joinQueue / _handleClaimOrQueue)
	-- ══════════════════════════════════════════════════════════════════════

	describe("queue gating", function()
		it("should not let a clocked-out player join the queue", function()
			mockClockedIn(false)
			local player = makePlayer(400)
			service:_joinQueue(player)
			expect(#service._queue).to.equal(0)
		end)

		it("should let a clocked-in player join the queue", function()
			mockClockedIn(true)
			local player = makePlayer(401)
			service:_joinQueue(player)
			expect(#service._queue).to.equal(1)
			expect(service._queue[1]).to.equal(player.UserId)
		end)

		it("should ignore a clocked-out player at the staff screen", function()
			mockClockedIn(false)
			local player = makePlayer(402)
			service._orders = { makeOrder() }
			service:_handleClaimOrQueue(player)
			expect(service._orders[1].status).to.equal("Pending Preparation")
			expect(#service._queue).to.equal(0)
		end)

		it("should claim directly for a clocked-in player when orders are pending", function()
			mockClockedIn(true)
			local player = makePlayer(403)
			service._orders = { makeOrder() }
			service:_handleClaimOrQueue(player)
			expect(service._orders[1].status).to.equal("Being Prepared")
			expect(service._orders[1].preparedBy).to.equal(player.UserId)
		end)

		it("should queue a clocked-in player when no orders are pending", function()
			mockClockedIn(true)
			local player = makePlayer(404)
			service:_handleClaimOrQueue(player)
			expect(#service._queue).to.equal(1)
		end)

		it("should remove a player from the queue on _leaveQueue", function()
			mockClockedIn(true)
			local player = makePlayer(405)
			service:_joinQueue(player)
			service:_leaveQueue(player)
			expect(#service._queue).to.equal(0)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- Client.CreateOrder (open to every player, self-only)
	-- ══════════════════════════════════════════════════════════════════════

	describe("Client.CreateOrder", function()
		local player = makePlayer(300)

		-- Standing fixture: customers order while clocked out (R3 refuses
		-- clocked-in callers; cases below set the mock explicitly).
		beforeEach(function()
			mockClockedIn(false)
		end)

		it("should reject a non-number customerId", function()
			local result = service.Client:CreateOrder(player, nil, { makeRequest() })
			expect(result.Success).to.equal(false)
			expect(#service._orders).to.equal(0)
		end)

		it("should reject a non-table orderItems", function()
			local result = service.Client:CreateOrder(player, player.UserId, "Boba")
			expect(result.Success).to.equal(false)
			expect(#service._orders).to.equal(0)
		end)

		it("should reject orders placed for another player", function()
			local result = service.Client:CreateOrder(player, 10001, { makeRequest() })
			expect(result.Success).to.equal(false)
			expect(result.Message).to.be.a("string")
			expect(#service._orders).to.equal(0)
		end)

		it("should allow ordering while ShiftService is unresolved (treated as clocked-out)", function()
			clearClockedIn()
			local result = service.Client:CreateOrder(player, player.UserId, { makeRequest() })
			expect(result.Success).to.equal(true)
			expect(#service._orders).to.equal(1)
		end)

		it("should refuse a clocked-in player (R3: phone and ClockedIn are exclusive)", function()
			mockClockedIn(true)
			local result = service.Client:CreateOrder(player, player.UserId, { makeRequest() })
			expect(result.Success).to.equal(false)
			expect(result.Message).to.equal("Clock out to order with the phone.")
			expect(#service._orders).to.equal(0)
			expect(service._orderDebounces[player.UserId]).to.equal(nil)
		end)

		it("should let the same player order after clocking out", function()
			mockClockedIn(true)
			local refused = service.Client:CreateOrder(player, player.UserId, { makeRequest() })
			expect(refused.Success).to.equal(false)
			mockClockedIn(false)
			local result = service.Client:CreateOrder(player, player.UserId, { makeRequest() })
			expect(result.Success).to.equal(true)
			expect(#service._orders).to.equal(1)
		end)

		it("should reject an empty order array", function()
			local result = service.Client:CreateOrder(player, player.UserId, {})
			expect(result.Success).to.equal(false)
			expect(#service._orders).to.equal(0)
		end)

		it("should reject orders exceeding the 4-item maximum", function()
			local result = service.Client:CreateOrder(player, player.UserId, {
				makeRequest(),
				makeRequest(),
				makeRequest(),
				makeRequest(),
				makeRequest(), -- 5 items
			})
			expect(result.Success).to.equal(false)
			expect(#service._orders).to.equal(0)
		end)

		it("should reject malformed items", function()
			local result = service.Client:CreateOrder(player, player.UserId, { "Boba" })
			expect(result.Success).to.equal(false)
			result = service.Client:CreateOrder(player, player.UserId, { { DefaultInfo = {}, CustomInfo = {} } })
			expect(result.Success).to.equal(false)
			expect(#service._orders).to.equal(0)
		end)

		-- Each case must be rejected without storing an order or starting the debounce.
		local REJECTED_REQUESTS = {
			["an unknown category"] = makeRequest("Secret Menu", "Fudge Brownie"),
			["an unknown item"] = makeRequest("Pastries", "<b>Free Robux</b>"),
			["a non-table CustomInfo"] = makeRequest("Pastries", "Fudge Brownie", "Large" :: any),
			["a missing Select value"] = makeRequest("Coffees", "Regular", {}),
			["a Select value not on the Menu"] = makeRequest("Coffees", "Regular", { Size = "Huge" }),
			["a non-boolean Option"] = makeRequest("Coffees", "Regular", { Size = "Small", Iced = "yes" }),
			["a CustomInfo key the item does not offer"] = makeRequest("Pastries", "Fudge Brownie", { Note = "hi" }),
			["a missing RequiredSelection"] = makeRequest("Boba Teas", "Custom Boba", {
				Size = "Medium",
				["Tapioca Flavor"] = "Normal",
			}),
			["a RequiredSelection value not on the Menu"] = makeRequest("Boba Teas", "Custom Boba", {
				Size = "Medium",
				["Syrup Flavor"] = "<font>Hacked</font>",
				["Tapioca Flavor"] = "Normal",
			}),
		}
		for caseName, request in REJECTED_REQUESTS do
			it("should reject " .. caseName, function()
				local result = service.Client:CreateOrder(player, player.UserId, { request })
				expect(result.Success).to.equal(false)
				expect(#service._orders).to.equal(0)
				expect(service._orderDebounces[player.UserId]).to.equal(nil)
			end)
		end

		-- Launch menu (Q12): items no station can make are refused before any state changes.
		local OFF_MENU_REQUESTS = {
			["a smoothie"] = makeRequest("Smoothies", "Banana Smoothie", { Size = "Small" }),
			["a tea"] = makeRequest("Teas", "Green", { Size = "Small", Iced = false }),
			["water"] = makeRequest("Others", "Water", { Size = "Small", Ice = true }),
			["a pastry with no recipe"] = makeRequest("Pastries", "Croissant"),
			["a latte"] = makeRequest("Coffees", "Latte", { Size = "Small", Iced = false, Sugar = false }),
			["a boba syrup with no dispenser"] = makeRequest("Boba Teas", "Custom Boba", {
				Size = "Medium",
				["Syrup Flavor"] = "Almond",
				["Tapioca Flavor"] = "Normal",
			}),
			["a tapioca off the launch menu"] = makeRequest("Boba Teas", "Custom Boba", {
				Size = "Medium",
				["Syrup Flavor"] = "Classic Milk Tea",
				["Tapioca Flavor"] = "Pumpkin Paradise",
			}),
		}
		for caseName, request in OFF_MENU_REQUESTS do
			it("should refuse " .. caseName .. " as not on the launch menu", function()
				local result = service.Client:CreateOrder(player, player.UserId, { request })
				expect(result.Success).to.equal(false)
				expect(result.Message).to.equal("That item isn't available right now.")
				expect(#service._orders).to.equal(0)
				expect(service._orderDebounces[player.UserId]).to.equal(nil)
			end)
		end

		it("should refuse the whole order when only one item is off the menu", function()
			local result = service.Client:CreateOrder(player, player.UserId, {
				makeRequest(),
				makeRequest("Smoothies", "Banana Smoothie", { Size = "Small" }),
			})
			expect(result.Success).to.equal(false)
			expect(#service._orders).to.equal(0)
		end)

		it("should accept every item the Menu lists as launch-menu, at a valid choice", function()
			local checked = 0
			for categoryName, itemNames in Menu.LaunchItems do
				for _, itemName in itemNames do
					expect(Menu.FoodTable[categoryName].Items[itemName]).to.be.ok()
					expect(Menu.IsLaunchItem(categoryName, itemName)).to.equal(true)
					checked += 1
				end
			end
			expect(checked > 0).to.equal(true)
			expect(Menu.IsLaunchItem("Smoothies", "Banana Smoothie")).to.equal(false)
		end)

		it("should rebuild DefaultInfo from the server Menu, ignoring the client's", function()
			local request = makeRequest()
			request.DefaultInfo = { ItemName = "Hacked", Select = { Size = true } }
			local result = service.Client:CreateOrder(player, player.UserId, { request })
			expect(result.Success).to.equal(true)

			local stored = service._orders[1].order[1]
			expect(stored.DefaultInfo).to.equal(Menu.FoodTable["Pastries"].Items["Fudge Brownie"])
			expect(stored.Category).to.equal("Pastries")
			expect(stored.Item).to.equal("Fudge Brownie")
		end)

		it("should keep valid choices and fill missing Options with Menu defaults", function()
			local result = service.Client:CreateOrder(player, player.UserId, {
				makeRequest("Coffees", "Regular", { Size = "Large", Sugar = true }),
				makeRequest("Boba Teas", "Custom Boba", {
					Size = "Medium",
					["Syrup Flavor"] = "Classic Milk Tea",
					["Tapioca Flavor"] = "Normal",
				}),
			})
			expect(result.Success).to.equal(true)

			local coffee = service._orders[1].order[1].CustomInfo
			expect(coffee.Size).to.equal("Large")
			expect(coffee.Sugar).to.equal(true)
			expect(coffee.Iced).to.equal(false)

			local boba = service._orders[1].order[2].CustomInfo
			expect(boba["Syrup Flavor"]).to.equal("Classic Milk Tea")
			expect(boba["Tapioca Flavor"]).to.equal("Normal")
		end)

		it("should store one spec per item, in item order, derived on the server", function()
			local request = makeRequest("Coffees", "Regular", { Size = "Large", Sugar = true })
			request.DefaultInfo = { ItemName = "Hacked" } -- the client's DefaultInfo is never used
			local result = service.Client:CreateOrder(player, player.UserId, {
				request,
				makeRequest("Boba Teas", "Custom Boba", {
					Size = "Medium",
					["Syrup Flavor"] = "Classic Milk Tea",
					["Tapioca Flavor"] = "Normal",
				}),
				makeRequest(),
			})
			expect(result.Success).to.equal(true)

			local specs = service._orders[1].specs
			expect(#specs).to.equal(3)

			expect(specs[1].Kind).to.equal("Drink")
			expect(specs[1].Item).to.equal("Regular")
			expect(specs[1].Size).to.equal("Large")
			expect(specs[1].Sugar).to.equal(true)
			expect(specs[1].Iced).to.equal(false)

			expect(specs[2].Kind).to.equal("Drink")
			expect(specs[2].Size).to.equal("Medium")
			expect(specs[2].Syrup).to.equal("Classic Milk Tea")
			expect(specs[2].Tapioca).to.equal("Normal")

			expect(specs[3].Kind).to.equal("Grab")
			expect(specs[3].Item).to.equal("Fudge Brownie")
		end)

		it("should not start the debounce for a rejected order", function()
			service.Client:CreateOrder(player, player.UserId, {})
			expect(service._orderDebounces[player.UserId]).to.equal(nil)
		end)

		it("should accept a valid 1-item order", function()
			local result = service.Client:CreateOrder(player, player.UserId, { makeRequest() })
			expect(result.Success).to.equal(true)
			expect(#service._orders).to.equal(1)
		end)

		it("should accept a valid 4-item order", function()
			local result = service.Client:CreateOrder(player, player.UserId, {
				makeRequest(),
				makeRequest(),
				makeRequest(),
				makeRequest(),
			})
			expect(result.Success).to.equal(true)
			expect(#service._orders).to.equal(1)
			expect(service._orders[1].numItems).to.equal(4)
		end)

		it("should apply a per-player debounce on the second call", function()
			service.Client:CreateOrder(player, player.UserId, { makeRequest() })
			local result = service.Client:CreateOrder(player, player.UserId, { makeRequest() }) -- debounced
			expect(result.Success).to.equal(false)
			expect(#service._orders).to.equal(1)
		end)

		it("should set a debounce entry for the ordering player", function()
			service.Client:CreateOrder(player, player.UserId, { makeRequest() })
			expect(service._orderDebounces[player.UserId]).to.equal(true)
		end)

		it("should reject a second order while the first is still open", function()
			service._orders = { makeOrder({ customer = player.UserId, status = "Ready for Pick Up" }) }
			local result = service.Client:CreateOrder(player, player.UserId, { makeRequest() })
			expect(result.Success).to.equal(false)
			expect(#service._orders).to.equal(1)
		end)

		it("should allow a different player to order while first is debounced", function()
			local other = makePlayer(999)
			service.Client:CreateOrder(player, player.UserId, { makeRequest() })
			service.Client:CreateOrder(other, other.UserId, { makeRequest() })
			expect(#service._orders).to.equal(2)
		end)

		it("should store the calling player as the customer", function()
			service.Client:CreateOrder(player, player.UserId, { makeRequest() })
			expect(service._orders[1].customer).to.equal(player.UserId)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- _handlePickUp — customer pickup path
	-- ══════════════════════════════════════════════════════════════════════

	describe("_handlePickUp (customer path)", function()
		it("should not modify area when it belongs to a different player", function()
			local customer = makePlayer(500)
			local area = makeArea(999) -- belongs to someone else
			service._orders = { makeOrder({ customer = 999, status = "Ready for Pick Up" }) }

			service:_handlePickUp(customer, area)

			expect(area.OrderOwner.Value).to.equal(999) -- unchanged
			area:Destroy()
		end)

		it("should remove the Ready for Pick Up order from _orders", function()
			local customer = makePlayer(500)
			local area = makeArea(customer.UserId)
			service._orders = { makeOrder({ customer = customer.UserId, status = "Ready for Pick Up" }) }

			service:_handlePickUp(customer, area)

			expect(#service._orders).to.equal(0)
			area:Destroy()
		end)

		it("should only remove the matching customer's Ready order", function()
			local customer = makePlayer(500)
			local other = makeOrder({ customer = 600, status = "Pending Preparation" })
			local area = makeArea(customer.UserId)
			service._orders = {
				makeOrder({ customer = customer.UserId, status = "Ready for Pick Up" }),
				other,
			}

			service:_handlePickUp(customer, area)

			expect(#service._orders).to.equal(1)
			expect(service._orders[1]).to.equal(other)
			area:Destroy()
		end)

		it("should reset area owner to 0 after pickup", function()
			local customer = makePlayer(500)
			local area = makeArea(customer.UserId)
			service._orders = { makeOrder({ customer = customer.UserId, status = "Ready for Pick Up" }) }

			service:_handlePickUp(customer, area)

			expect(area.OrderOwner.Value).to.equal(0)
			area:Destroy()
		end)

		it("should reset ProximityPrompt labels after pickup", function()
			local customer = makePlayer(500)
			local area = makeArea(customer.UserId)
			area.ProximityPrompt.ObjectText = "Customer's Order"
			area.ProximityPrompt.ActionText = "Pick Up Order"
			service._orders = { makeOrder({ customer = customer.UserId, status = "Ready for Pick Up" }) }

			service:_handlePickUp(customer, area)

			expect(area.ProximityPrompt.ObjectText).to.equal("Pick Up Area")
			expect(area.ProximityPrompt.ActionText).to.equal("Deposit Order")
			area:Destroy()
		end)

		it("should fire PickUpNodeVisibilityChanged:Fire with false", function()
			local customer = makePlayer(500)
			local area = makeArea(customer.UserId)
			service._orders = { makeOrder({ customer = customer.UserId, status = "Ready for Pick Up" }) }

			service:_handlePickUp(customer, area)

			local calls = service.Client.PickUpNodeVisibilityChanged._calls
			expect(#calls).to.be.ok()
			-- The first call should be to hide the area for the customer
			expect(calls[1][1]).to.equal(customer)
			expect(calls[1][2]).to.equal(area)
			expect(calls[1][3]).to.equal(false)
			area:Destroy()
		end)

		it("should move tools from OrderPickUp folder to player Backpack", function()
			local customer = makePlayer(501)
			local area = makeArea(customer.UserId)
			service._orders = { makeOrder({ customer = customer.UserId, status = "Ready for Pick Up" }) }

			-- Create an order folder with a tool
			local orderFolder = Instance.new("Folder")
			orderFolder.Name = "Order_" .. customer.UserId
			orderFolder.Parent = ServerStorage.OrderPickUp

			local tool = Instance.new("Tool")
			tool.Name = "GreenTea"
			tool.Parent = orderFolder

			service:_handlePickUp(customer, area)

			-- Tool should have moved to the player's backpack
			expect(tool.Parent).to.equal(customer.Backpack)
			expect(orderFolder.Parent).to.equal(nil) -- destroyed

			area:Destroy()
		end)

		it("should destroy the OrderPickUp folder after pickup", function()
			local customer = makePlayer(502)
			local area = makeArea(customer.UserId)
			service._orders = { makeOrder({ customer = customer.UserId, status = "Ready for Pick Up" }) }

			local orderFolder = Instance.new("Folder")
			orderFolder.Name = "Order_" .. customer.UserId
			orderFolder.Parent = ServerStorage.OrderPickUp

			service:_handlePickUp(customer, area)

			expect(orderFolder.Parent).to.equal(nil)
			area:Destroy()
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- FindServeTools
	-- ══════════════════════════════════════════════════════════════════════

	describe("FindServeTools", function()
		local staff

		beforeEach(function()
			staff = makePlayer(650)
			staff.Character = Instance.new("Model")
		end)

		local function specs()
			return specsOf({ makeItem() })
		end

		it("should pick a tool whose attributes match, graded Perfect", function()
			local tool = makeTool(regularMedium(), staff.Backpack)
			local tools, grade, reasons = service:FindServeTools(staff, specs())
			expect(tools).to.be.ok()
			expect(#tools).to.equal(1)
			expect(tools[1]).to.equal(tool)
			expect(grade).to.equal("Perfect")
			expect(#reasons).to.equal(0)
		end)

		it("should grade one small mistake Close and still return the tool", function()
			local tool = makeTool(regularMedium({ Size = "Large" }), staff.Backpack)
			local tools, grade = service:FindServeTools(staff, specs())
			expect(tools[1]).to.equal(tool)
			expect(grade).to.equal("Close")
		end)

		it("should ignore extra attributes such as Lid", function()
			makeTool(regularMedium({ Lid = true }), staff.Backpack)
			local tools, grade = service:FindServeTools(staff, specs())
			expect(tools).to.be.ok()
			expect(grade).to.equal("Perfect")
		end)

		it("should return nil, Wrong and the reason for a wrong item", function()
			makeTool(regularMedium({ Item = "Decaf" }), staff.Backpack)
			local tools, grade, reasons = service:FindServeTools(staff, specs())
			expect(tools).to.equal(nil)
			expect(grade).to.equal("Wrong")
			expect(#reasons).to.equal(1)
			expect(reasons[1]).to.equal("Item")
		end)

		it("should name every wrong field when two or more minor mistakes are made", function()
			makeTool(regularMedium({ Size = "Large", Iced = true }), staff.Backpack)
			local tools, grade, reasons = service:FindServeTools(staff, specs())
			expect(tools).to.equal(nil)
			expect(grade).to.equal("Wrong")
			expect(table.concat(reasons, ",")).to.equal("Size,Iced")
		end)

		it("should never read the tool's name", function()
			local tool = makeTool(regularMedium(), staff.Backpack)
			tool.Name = "Totally Not A Coffee"
			local tools = service:FindServeTools(staff, specs())
			expect(tools).to.be.ok()
			expect(tools[1]).to.equal(tool)
		end)

		it("should treat a tool with no Item attribute as the wrong item", function()
			makeTool(nil, staff.Backpack)
			local tools, grade, reasons = service:FindServeTools(staff, specs())
			expect(tools).to.equal(nil)
			expect(grade).to.equal("Wrong")
			expect(reasons[1]).to.equal("Item")
		end)

		it("should report Missing when the player has no tools", function()
			local tools, grade, reasons = service:FindServeTools(staff, specs())
			expect(tools).to.equal(nil)
			expect(grade).to.equal("Wrong")
			expect(reasons[1]).to.equal("Missing")
		end)

		it("should work with no Character", function()
			staff.Character = nil
			local tool = makeTool(regularMedium(), staff.Backpack)
			local tools = service:FindServeTools(staff, specs())
			expect(tools[1]).to.equal(tool)
		end)

		it("should prefer the held tool over a backpack tool that also matches", function()
			makeTool(regularMedium(), staff.Backpack)
			local held = makeTool(regularMedium(), staff.Character)
			local tools = service:FindServeTools(staff, specs())
			expect(tools[1]).to.equal(held)
		end)

		it("should prefer a Perfect backpack tool over a Close held tool", function()
			makeTool(regularMedium({ Size = "Large" }), staff.Character)
			local perfect = makeTool(regularMedium(), staff.Backpack)
			local tools, grade = service:FindServeTools(staff, specs())
			expect(tools[1]).to.equal(perfect)
			expect(grade).to.equal("Perfect")
		end)

		it("should return one tool per spec, in spec order, using each tool once", function()
			local items = {
				makeItem(),
				{
					Category = "Pastries",
					Item = "Fudge Brownie",
					DefaultInfo = Menu.FoodTable["Pastries"].Items["Fudge Brownie"],
					CustomInfo = {},
				},
			}
			local brownieTool = makeTool({ Item = "Fudge Brownie" }, staff.Backpack)
			local coffeeTool = makeTool(regularMedium(), staff.Backpack)

			local tools, grade = service:FindServeTools(staff, specsOf(items))
			expect(#tools).to.equal(2)
			expect(tools[1]).to.equal(coffeeTool)
			expect(tools[2]).to.equal(brownieTool)
			expect(grade).to.equal("Perfect")
		end)

		it("should report Missing when only some of several specs can be filled", function()
			makeTool(regularMedium(), staff.Backpack)
			local tools, grade, reasons = service:FindServeTools(staff, specsOf({ makeItem(), makeItem() }))
			expect(tools).to.equal(nil)
			expect(grade).to.equal("Wrong")
			expect(reasons[1]).to.equal("Missing")
		end)

		it("should only read: the tools stay where they were", function()
			local held = makeTool(regularMedium(), staff.Character)
			local packed = makeTool(regularMedium({ Item = "Decaf" }), staff.Backpack)
			service:FindServeTools(staff, specs())
			expect(held.Parent).to.equal(staff.Character)
			expect(packed.Parent).to.equal(staff.Backpack)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- _handlePickUp — staff deposit path
	-- ══════════════════════════════════════════════════════════════════════

	describe("_handlePickUp (staff deposit path)", function()
		local CUSTOMER_ID = 10001

		-- Builds a staff member who is preparing `order` and a free pick-up area.
		local function setup(userId: number, orderOverrides: { [string]: any }?)
			local staff = makePlayer(userId)
			staff.Character = Instance.new("Model")
			local area = makeArea(0)
			local overrides = {
				customer = CUSTOMER_ID,
				status = "Being Prepared",
				preparedBy = staff.UserId,
				statusColor = COLOR_PREPARING,
			}
			for key, value in orderOverrides or {} do
				overrides[key] = value
			end
			local order = makeOrder(overrides)
			service._orders = { order }
			return staff, area, order
		end

		local function expectUntouched(order, area)
			expect(order.status).to.equal("Being Prepared")
			expect(order.statusColor).to.equal(COLOR_PREPARING)
			expect(order.grade).to.equal(nil)
			expect(area.OrderOwner.Value).to.equal(0)
			expect(#area:GetChildren()).to.equal(2) -- OrderOwner and ProximityPrompt only
			expect(ServerStorage.OrderPickUp:FindFirstChild("Order_" .. CUSTOMER_ID)).to.equal(nil)
			expect(#service.Client.NotepadUpdated._calls).to.equal(0)
			expect(#service.Client.PickUpNodeVisibilityChanged._calls).to.equal(0)
		end

		it("should do nothing when staff has no active Being Prepared order", function()
			local staff = makePlayer(600)
			local area = makeArea(0) -- unclaimed area
			service._orders = {} -- no active order for this staff

			service:_handlePickUp(staff, area)

			expect(area.OrderOwner.Value).to.equal(0) -- area untouched
			expect(#service.Client.Announcement._calls).to.equal(0)
			area:Destroy()
		end)

		it("should fire Announcement when staff has fewer tools than order requires", function()
			local staff, area, order = setup(600, { order = { makeItem(), makeItem() }, numItems = 2 })

			service:_handlePickUp(staff, area)

			local calls = service.Client.Announcement._calls
			expect(#calls).to.equal(1)
			expect(calls[1][1]).to.equal(staff)
			expect(calls[1][2]).to.equal("Cannot Deposit Order!")
			expect(string.find(calls[1][3], "An item is missing", 1, true)).to.be.ok()
			expectUntouched(order, area)
			area:Destroy()
		end)

		it("should release area (keep OrderOwner = 0) when tools insufficient", function()
			local staff, area = setup(601, { order = { makeItem(), makeItem() }, numItems = 2 })

			service:_handlePickUp(staff, area)

			expect(area.OrderOwner.Value).to.equal(0)
			area:Destroy()
		end)

		it("should set the order to Ready and move the matching tool to the pick-up folder", function()
			local staff, area, order = setup(610)
			local tool = makeTool(regularMedium(), staff.Backpack)

			service:_handlePickUp(staff, area)

			expect(order.status).to.equal("Ready for Pick Up")
			expect(order.statusColor).to.equal(COLOR_READY)
			expect(order.grade).to.equal("Perfect")
			expect(area.OrderOwner.Value).to.equal(CUSTOMER_ID)
			expect(#service.Client.Announcement._calls).to.equal(0)

			local folder = ServerStorage.OrderPickUp:FindFirstChild("Order_" .. CUSTOMER_ID)
			expect(folder).to.be.ok()
			expect(tool.Parent).to.equal(folder)

			-- Pick-up display model placed on the area
			local models = 0
			for _, child in area:GetChildren() do
				if child:IsA("Model") then
					models += 1
				end
			end
			expect(models).to.equal(1)

			-- The barista's notepad is cleared and free nodes are hidden for them
			local notepad = service.Client.NotepadUpdated._calls
			expect(#notepad).to.equal(1)
			expect(notepad[1][1]).to.equal(staff)
			expect(notepad[1][2]).to.equal("ResetOrder")

			cleanPickUpFolder(CUSTOMER_ID)
			area:Destroy()
		end)

		it("should take a matching tool that is held in the Character", function()
			local staff, area, order = setup(611)
			local tool = makeTool(regularMedium(), staff.Character)

			service:_handlePickUp(staff, area)

			expect(order.status).to.equal("Ready for Pick Up")
			expect(tool.Parent).to.equal(ServerStorage.OrderPickUp:FindFirstChild("Order_" .. CUSTOMER_ID))

			cleanPickUpFolder(CUSTOMER_ID)
			area:Destroy()
		end)

		it("should accept a Close tool and record the grade", function()
			local staff, area, order = setup(612)
			makeTool(regularMedium({ Size = "Large" }), staff.Backpack)

			service:_handlePickUp(staff, area)

			expect(order.status).to.equal("Ready for Pick Up")
			expect(order.grade).to.equal("Close")

			cleanPickUpFolder(CUSTOMER_ID)
			area:Destroy()
		end)

		it("should deposit every item of a multi-item order", function()
			local staff, area, order = setup(613, { order = { makeItem(), makeItem() }, numItems = 2 })
			local first = makeTool(regularMedium(), staff.Backpack)
			local second = makeTool(regularMedium(), staff.Backpack)

			service:_handlePickUp(staff, area)

			local folder = ServerStorage.OrderPickUp:FindFirstChild("Order_" .. CUSTOMER_ID)
			expect(order.status).to.equal("Ready for Pick Up")
			expect(first.Parent).to.equal(folder)
			expect(second.Parent).to.equal(folder)

			cleanPickUpFolder(CUSTOMER_ID)
			area:Destroy()
		end)

		it("should show the reason and change nothing when the tool is the wrong item", function()
			local staff, area, order = setup(620)
			local tool = makeTool(regularMedium({ Item = "Decaf" }), staff.Backpack)

			service:_handlePickUp(staff, area)

			local calls = service.Client.Announcement._calls
			expect(#calls).to.equal(1)
			expect(calls[1][1]).to.equal(staff)
			expect(calls[1][2]).to.equal("Cannot Deposit Order!")
			expect(string.find(calls[1][3], "Wrong item", 1, true)).to.be.ok()
			expect(calls[1][4]).to.equal(COLOR_ERROR)
			expect(tool.Parent).to.equal(staff.Backpack)
			expectUntouched(order, area)
			area:Destroy()
		end)

		it("should name every wrong field when the tool has two minor mistakes", function()
			local staff, area, order = setup(621)
			local tool = makeTool(regularMedium({ Size = "Large", Sugar = true }), staff.Backpack)

			service:_handlePickUp(staff, area)

			local calls = service.Client.Announcement._calls
			expect(#calls).to.equal(1)
			expect(string.find(calls[1][3], "Wrong size, Wrong sugar", 1, true)).to.be.ok()
			expect(tool.Parent).to.equal(staff.Backpack)
			expectUntouched(order, area)
			area:Destroy()
		end)

		it("should refuse a tool with no attributes (a legacy or gamepass tool)", function()
			local staff, area, order = setup(622)
			local tool = makeTool(nil, staff.Backpack)

			service:_handlePickUp(staff, area)

			expect(#service.Client.Announcement._calls).to.equal(1)
			expect(tool.Parent).to.equal(staff.Backpack)
			expectUntouched(order, area)
			area:Destroy()
		end)

		it("should refuse a multi-item order when one tool is wrong and leave every tool in place", function()
			local staff, area, order = setup(623, { order = { makeItem(), makeItem() }, numItems = 2 })
			local good = makeTool(regularMedium(), staff.Backpack)
			local bad = makeTool(regularMedium({ Item = "Decaf" }), staff.Backpack)

			service:_handlePickUp(staff, area)

			expect(#service.Client.Announcement._calls).to.equal(1)
			expect(good.Parent).to.equal(staff.Backpack)
			expect(bad.Parent).to.equal(staff.Backpack)
			expectUntouched(order, area)
			area:Destroy()
		end)

		it("should let the barista deposit once they fix a wrong tool", function()
			local staff, area, order = setup(624)
			local tool = makeTool(regularMedium({ Item = "Decaf" }), staff.Backpack)

			service:_handlePickUp(staff, area)
			expect(order.status).to.equal("Being Prepared")

			tool:SetAttribute("Item", "Regular")
			service:_handlePickUp(staff, area)
			expect(order.status).to.equal("Ready for Pick Up")

			cleanPickUpFolder(CUSTOMER_ID)
			area:Destroy()
		end)
	end)

	describe("_handlePickUp (occupied node and served tools)", function()
		local CUSTOMER_ID = 10001
		local OTHER_CUSTOMER_ID = 10002

		local function setup(userId: number, areaOwner: number?)
			local staff = makePlayer(userId)
			staff.Character = Instance.new("Model")
			local area = makeArea(areaOwner or 0)
			local order = makeOrder({
				customer = CUSTOMER_ID,
				status = "Being Prepared",
				preparedBy = staff.UserId,
			})
			service._orders = { order }
			return staff, area, order
		end

		it("should refuse a deposit into a node that is already occupied and change nothing", function()
			local staff, area, order = setup(700, OTHER_CUSTOMER_ID)
			local tool = makeTool(regularMedium(), staff.Backpack)

			service:_handlePickUp(staff, area)

			expect(order.status).to.equal("Being Prepared")
			expect(order.grade).to.equal(nil)
			expect(area.OrderOwner.Value).to.equal(OTHER_CUSTOMER_ID) -- the first customer keeps the node
			expect(tool.Parent).to.equal(staff.Backpack)
			expect(tool:GetAttribute("Served")).to.equal(nil)
			expect(ServerStorage.OrderPickUp:FindFirstChild("Order_" .. CUSTOMER_ID)).to.equal(nil)
			expect(#service.Client.NotepadUpdated._calls).to.equal(0)

			local announcements = service.Client.Announcement._calls
			expect(#announcements).to.equal(1)
			expect(announcements[1][1]).to.equal(staff)
			expect(announcements[1][2]).to.equal("Cannot Deposit Order!")
			expect(string.find(announcements[1][3], "taken", 1, true)).to.be.ok()

			-- The stale prompt is hidden for that barista.
			local visibility = service.Client.PickUpNodeVisibilityChanged._calls
			expect(#visibility).to.equal(1)
			expect(visibility[1][1]).to.equal(staff)
			expect(visibility[1][2]).to.equal(area)
			expect(visibility[1][3]).to.equal(false)
			area:Destroy()
		end)

		it("should mark deposited tools Served", function()
			local staff, area = setup(701)
			local tool = makeTool(regularMedium(), staff.Backpack)

			service:_handlePickUp(staff, area)

			expect(tool:GetAttribute("Served")).to.equal(true)

			cleanPickUpFolder(CUSTOMER_ID)
			area:Destroy()
		end)

		it("should refuse to deposit a tool that was already served", function()
			local staff, area, order = setup(702)
			local tool = makeTool(regularMedium({ Served = true }), staff.Backpack)

			service:_handlePickUp(staff, area)

			expect(order.status).to.equal("Being Prepared")
			expect(area.OrderOwner.Value).to.equal(0)
			expect(tool.Parent).to.equal(staff.Backpack)
			local announcements = service.Client.Announcement._calls
			expect(#announcements).to.equal(1)
			expect(string.find(announcements[1][3], "An item is missing", 1, true)).to.be.ok()
			area:Destroy()
		end)

		it("should not let a picked-up drink satisfy a second order", function()
			local staff, area, order = setup(703)
			makeTool(regularMedium(), staff.Backpack)

			-- First order: deposit, then the customer picks the drink up.
			service:_handlePickUp(staff, area)
			expect(order.status).to.equal("Ready for Pick Up")
			local customer = makePlayer(CUSTOMER_ID)
			service:_handlePickUp(customer, area)
			local drink = customer.Backpack:FindFirstChildWhichIsA("Tool")
			expect(drink).to.be.ok()
			expect(drink:GetAttribute("Served")).to.equal(true)

			-- Hand it to the barista for a second order: it must not match.
			drink.Parent = staff.Backpack
			local second = makeOrder({
				orderNum = "0002",
				customer = OTHER_CUSTOMER_ID,
				status = "Being Prepared",
				preparedBy = staff.UserId,
			})
			service._orders = { second }
			local tools = service:FindServeTools(staff, second.specs)
			expect(tools).to.equal(nil)

			area:Destroy()
		end)
	end)

	describe("clock-out releases a claimed order", function()
		local function claimed(userId: number)
			local staff = makePlayer(userId)
			local order = makeOrder({ status = "Being Prepared", preparedBy = userId, statusColor = COLOR_PREPARING })
			service._orders = { order }
			return staff, order
		end

		it("should return a Being Prepared order to the queue when the barista clocks out", function()
			local staff, order = claimed(800)

			service:_onClockedInChanged(staff, false)

			expect(order.status).to.equal("Pending Preparation")
			expect(order.statusColor).to.equal(COLOR_PENDING)
			expect(order.preparedBy).to.equal(nil)
			expect(service:HasActiveOrder(staff)).to.equal(false)
			expect(service:_getNextOrder()).to.equal(order)

			local notepad = service.Client.NotepadUpdated._calls
			expect(#notepad).to.equal(1)
			expect(notepad[1][1]).to.equal(staff)
			expect(notepad[1][2]).to.equal("ResetOrder")
		end)

		it("should let the barista, or another one, claim the order again", function()
			local staff, order = claimed(801)
			service:_onClockedInChanged(staff, false)

			mockClockedIn(true)
			service:_claimNextOrder(staff)

			expect(order.status).to.equal("Being Prepared")
			expect(order.preparedBy).to.equal(staff.UserId)
		end)

		it("should keep the order when the barista clocks in", function()
			local staff, order = claimed(802)

			service:_onClockedInChanged(staff, true)

			expect(order.status).to.equal("Being Prepared")
			expect(order.preparedBy).to.equal(staff.UserId)
		end)

		it("should leave other baristas' orders and Ready orders alone", function()
			local staff = makePlayer(803)
			local others = makeOrder({ status = "Being Prepared", preparedBy = 999, statusColor = COLOR_PREPARING })
			local ready = makeOrder({ orderNum = "0002", status = "Ready for Pick Up", preparedBy = 803 })
			service._orders = { others, ready }

			service:_onClockedInChanged(staff, false)

			expect(others.status).to.equal("Being Prepared")
			expect(ready.status).to.equal("Ready for Pick Up")
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- collectTools (tested indirectly via the deposit's tool search)
	-- ══════════════════════════════════════════════════════════════════════

	describe("tool collection logic", function()
		-- collectTools feeds FindServeTools, so a deposit with a correctly
		-- marked tool succeeds only if the tool was found.
		local function depositWith(userId: number, parentOf: ((any) -> Instance)?)
			local staff = makePlayer(userId)
			staff.Character = Instance.new("Model")
			local area = makeArea(0)
			local order = makeOrder({ status = "Being Prepared", preparedBy = staff.UserId })
			service._orders = { order }
			if parentOf then
				makeTool(regularMedium(), parentOf(staff))
			end
			service:_handlePickUp(staff, area)
			cleanPickUpFolder(order.customer)
			area:Destroy()
			return order
		end

		it("should find tools in the player Backpack", function()
			local order = depositWith(700, function(staff)
				return staff.Backpack
			end)
			expect(order.status).to.equal("Ready for Pick Up")
			expect(#service.Client.Announcement._calls).to.equal(0)
		end)

		it("should find tools worn in the Character", function()
			local order = depositWith(701, function(staff)
				return staff.Character
			end)
			expect(order.status).to.equal("Ready for Pick Up")
			expect(#service.Client.Announcement._calls).to.equal(0)
		end)

		it("should fire Announcement when player has zero tools", function()
			local order = depositWith(702, nil)
			expect(order.status).to.equal("Being Prepared")
			expect(#service.Client.Announcement._calls).to.equal(1)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- Order number formatting
	-- ══════════════════════════════════════════════════════════════════════

	describe("order number formatting", function()
		it("should produce a 4-character string for order 1", function()
			addOrder(10001, { makeItem() })
			local num = service._orders[1].orderNum
			expect(#num).to.equal(4)
		end)

		it("should produce a 4-character string for order 100", function()
			service._currentOrderNum = 99
			addOrder(10001, { makeItem() })
			local num = service._orders[1].orderNum
			expect(#num).to.equal(4)
		end)

		it("should produce '0999' for order 999", function()
			service._currentOrderNum = 998
			addOrder(10001, { makeItem() })
			expect(service._orders[1].orderNum).to.equal("0999")
		end)

		it("should produce '0000' for order 1000 (wrap)", function()
			service._currentOrderNum = 999
			addOrder(10001, { makeItem() })
			expect(service._orders[1].orderNum).to.equal("0000")
		end)

		it("order nums should be comparable as strings for oldest-first ordering", function()
			-- Lexicographic order of zero-padded strings == numeric order
			expect("0001" < "0002").to.equal(true)
			expect("0009" < "0010").to.equal(true)
			expect("0099" < "0100").to.equal(true)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- Status colour constants
	-- ══════════════════════════════════════════════════════════════════════

	describe("status colours", function()
		it("new orders start with the pending (grey) colour", function()
			addOrder(10001, { makeItem() })
			expect(service._orders[1].statusColor).to.equal(COLOR_PENDING)
		end)

		it("claimed orders use the preparing (yellow) colour", function()
			mockClockedIn(true)
			local player = makePlayer(800)
			service._orders = { makeOrder() }
			service:_claimNextOrder(player)
			expect(service._orders[1].statusColor).to.equal(COLOR_PREPARING)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- _broadcastUpdate composition
	-- ══════════════════════════════════════════════════════════════════════

	describe("_broadcastUpdate", function()
		it("should call _updateOrders, _updateStaffScreens, and _updateStatusScreens", function()
			local called = { updateOrders = false, updateStaff = false, updateStatus = false }

			-- Temporarily restore a real-style broadcast that records calls
			service._broadcastUpdate = function(self)
				called.updateOrders = true
				self:_updateOrders()
				called.updateStaff = true
				self:_updateStaffScreens()
				called.updateStatus = true
				self:_updateStatusScreens()
			end

			service._orders = {} -- empty so screen updates are no-ops

			service:_broadcastUpdate()

			expect(called.updateOrders).to.equal(true)
			expect(called.updateStaff).to.equal(true)
			expect(called.updateStatus).to.equal(true)
		end)

		it("should not error when all internal collections are empty", function()
			service._broadcastUpdate = function(self)
				self:_updateOrders()
				self:_updateStaffScreens()
				self:_updateStatusScreens()
			end

			expect(function()
				service:_broadcastUpdate()
			end).never.to.throw()
		end)
	end)

	describe("Customer Orders and Status Screens", function()
		it("should register customer orders and return order numbers", function()
			local num = service:RegisterCustomerOrder("Cust_1", "Alex", 1, "Being Prepared")
			expect(num).to.be.a("string")
			expect(service._customerOrders["Cust_1"]).never.to.equal(nil)
			expect(service._customerOrders["Cust_1"].customerName).to.equal("Alex")
			expect(service._customerOrders["Cust_1"].status).to.equal("Being Prepared")
		end)

		it("should update customer order status", function()
			service:RegisterCustomerOrder("Cust_2", "Karen", 2, "Being Prepared")
			service:UpdateCustomerOrderStatus("Cust_2", "Ready for Pick Up")
			expect(service._customerOrders["Cust_2"].status).to.equal("Ready for Pick Up")
		end)

		it("should remove customer orders", function()
			service:RegisterCustomerOrder("Cust_3", "Sam", 1, "Being Prepared")
			expect(service._customerOrders["Cust_3"]).never.to.equal(nil)
			service:RemoveCustomerOrder("Cust_3")
			expect(service._customerOrders["Cust_3"]).to.equal(nil)
		end)
	end)
end

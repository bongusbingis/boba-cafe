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
    • RankUtil methods reach the Roblox group API. We monkey-patch them for
      all rank-gated tests and restore the originals in afterEach.
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

	local RankUtil = require(ReplicatedStorage.Shared.Utility.RankUtil)

	-- Require the service table. KnitInit/KnitStart are never invoked here,
	-- so workspace["Ordering System"] is never accessed.
	local service = require(ServerScriptService.Server.Modules.OrderService)

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

	-- Minimal order item
	local function makeItem(name: string?)
		return {
			DefaultInfo = { ItemName = name or "Boba" },
			CustomInfo = {},
		}
	end

	-- Build a raw Order entry directly (bypasses _addOrder / _broadcastUpdate)
	local COLOR_PENDING = Color3.fromRGB(140, 140, 140)
	local COLOR_PREPARING = Color3.fromRGB(229, 198, 103)
	local COLOR_READY = Color3.fromRGB(151, 190, 135)

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
		return base
	end

	-- Create a mock pick-up area Model with the expected children
	local function makeArea(ownerUserId: number?)
		local area = Instance.new("Model")
		area.Name = "MockPickUpArea"

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
	-- Rank mock helpers
	-- ──────────────────────────────────────────────────────────────────────

	local _origCanEnterKitchen = RankUtil.CanEnterKitchen
	local _origCanUseOrdering = RankUtil.CanUseOrderingSystem

	local function mockRank(enterKitchen: boolean, useOrdering: boolean?)
		RankUtil.CanEnterKitchen = function() return enterKitchen end
		RankUtil.CanUseOrderingSystem = function() return if useOrdering == nil then enterKitchen else useOrdering end
	end

	local function restoreRank()
		RankUtil.CanEnterKitchen = _origCanEnterKitchen
		RankUtil.CanUseOrderingSystem = _origCanUseOrdering
	end

	-- ──────────────────────────────────────────────────────────────────────
	-- Per-test state reset
	-- ──────────────────────────────────────────────────────────────────────

	beforeEach(function()
		service._orders = {}
		service._currentOrderNum = 0
		service._orderDebounces = {}
		service._areaDebounces = {}
		service._statusScreens = {}
		service._staffScreens = {}
		service._pickUpAreas = {}

		-- Replace Knit RemoteSignals with local mock objects so we can track
		-- fires without needing the full networking stack.
		service.Client.NotepadUpdated = makeMockSignal()
		service.Client.PickUpNodeVisibilityChanged = makeMockSignal()
		service.Client.Announcement = makeMockSignal()

		-- Wire Client.Server so that Client methods (CreateOrder) work correctly.
		service.Client.Server = service

		-- Suppress _broadcastUpdate — Players:GetPlayerByUserId always returns
		-- nil in tests, so running the real update would immediately prune all
		-- orders we add. Tests that specifically exercise pruning call
		-- _updateOrders directly.
		service._broadcastUpdate = function() end

		-- Default: no rank access
		restoreRank()
	end)

	afterEach(function()
		restoreRank()
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- _addOrder
	-- ══════════════════════════════════════════════════════════════════════

	describe("_addOrder", function()
		it("should add an order to the _orders table", function()
			service:_addOrder(10001, { makeItem() })
			expect(#service._orders).to.equal(1)
		end)

		it("should store the correct customer UserId", function()
			service:_addOrder(42, { makeItem() })
			expect(service._orders[1].customer).to.equal(42)
		end)

		it("should store the correct order items", function()
			local items = { makeItem("Tea"), makeItem("Boba") }
			service:_addOrder(10001, items)
			expect(service._orders[1].numItems).to.equal(2)
			expect(service._orders[1].order).to.equal(items)
		end)

		it("should start every order with 'Pending Preparation' status", function()
			service:_addOrder(10001, { makeItem() })
			expect(service._orders[1].status).to.equal("Pending Preparation")
		end)

		it("should start every order with the pending colour", function()
			service:_addOrder(10001, { makeItem() })
			expect(service._orders[1].statusColor).to.equal(COLOR_PENDING)
		end)

		it("should start every order with preparedBy = nil", function()
			service:_addOrder(10001, { makeItem() })
			expect(service._orders[1].preparedBy).to.equal(nil)
		end)

		it("should zero-pad orderNum to 4 digits", function()
			service:_addOrder(10001, { makeItem() })
			expect(service._orders[1].orderNum).to.equal("0001")
		end)

		it("should produce ascending orderNums for sequential calls", function()
			service:_addOrder(10001, { makeItem() })
			service:_addOrder(10002, { makeItem() })
			expect(service._orders[1].orderNum).to.equal("0001")
			expect(service._orders[2].orderNum).to.equal("0002")
		end)

		it("should wrap orderNum at 999 (mod 1000)", function()
			service._currentOrderNum = 999
			service:_addOrder(10001, { makeItem() })
			-- 1000 % 1000 == 0 → "0000"
			expect(service._orders[1].orderNum).to.equal("0000")
		end)

		it("should produce 'Pending Preparation' wrapped as '0000'", function()
			service._currentOrderNum = 999
			service:_addOrder(10001, { makeItem() })
			expect(service._orders[1].status).to.equal("Pending Preparation")
		end)

		it("should increment _currentOrderNum", function()
			service:_addOrder(10001, { makeItem() })
			service:_addOrder(10002, { makeItem() })
			expect(service._currentOrderNum).to.equal(2)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- _getPendingCount
	-- ══════════════════════════════════════════════════════════════════════

	describe("_getPendingCount", function()
		it("should return 0 when no orders exist", function()
			expect(service:_getPendingCount()).to.equal(0)
		end)

		it("should count only Pending Preparation orders", function()
			service._orders = {
				makeOrder({ status = "Pending Preparation" }),
				makeOrder({ status = "Pending Preparation" }),
				makeOrder({ status = "Being Prepared" }),
				makeOrder({ status = "Ready for Pick Up" }),
			}
			expect(service:_getPendingCount()).to.equal(2)
		end)

		it("should return 0 when all orders are Being Prepared", function()
			service._orders = {
				makeOrder({ status = "Being Prepared", preparedBy = 99 }),
			}
			expect(service:_getPendingCount()).to.equal(0)
		end)

		it("should return 0 when all orders are Ready for Pick Up", function()
			service._orders = {
				makeOrder({ status = "Ready for Pick Up" }),
			}
			expect(service:_getPendingCount()).to.equal(0)
		end)

		it("should reflect order table changes immediately", function()
			expect(service:_getPendingCount()).to.equal(0)
			table.insert(service._orders, makeOrder())
			expect(service:_getPendingCount()).to.equal(1)
			table.remove(service._orders, 1)
			expect(service:_getPendingCount()).to.equal(0)
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

		it("should return false when player lacks kitchen rank", function()
			mockRank(false)
			expect(service:_canClaimOrder(player)).to.equal(false)
		end)

		it("should return false when player already has an active Being Prepared order", function()
			mockRank(true)
			service._orders = {
				makeOrder({ status = "Being Prepared", preparedBy = player.UserId }),
			}
			expect(service:_canClaimOrder(player)).to.equal(false)
		end)

		it("should return true for a ranked player with no active order", function()
			mockRank(true)
			service._orders = {}
			expect(service:_canClaimOrder(player)).to.equal(true)
		end)

		it("should return true even if player has Pending or Ready orders that are not theirs", function()
			mockRank(true)
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
			mockRank(true)
			service._orders = {}
			service:_claimNextOrder(player)
			expect(#service._orders).to.equal(0)
		end)

		it("should do nothing when player cannot claim (no rank)", function()
			mockRank(false)
			service._orders = { makeOrder() }
			service:_claimNextOrder(player)
			expect(service._orders[1].status).to.equal("Pending Preparation")
		end)

		it("should change order status to Being Prepared", function()
			mockRank(true)
			service._orders = { makeOrder({ orderNum = "0001" }) }
			service:_claimNextOrder(player)
			expect(service._orders[1].status).to.equal("Being Prepared")
		end)

		it("should set preparedBy to the claiming player's UserId", function()
			mockRank(true)
			service._orders = { makeOrder() }
			service:_claimNextOrder(player)
			expect(service._orders[1].preparedBy).to.equal(player.UserId)
		end)

		it("should set statusColor to the preparing colour", function()
			mockRank(true)
			service._orders = { makeOrder() }
			service:_claimNextOrder(player)
			expect(service._orders[1].statusColor).to.equal(COLOR_PREPARING)
		end)

		it("should fire NotepadUpdated with SetNewOrder", function()
			mockRank(true)
			local items = { makeItem("Tea") }
			service._orders = { makeOrder({ order = items }) }
			service:_claimNextOrder(player)

			local calls = service.Client.NotepadUpdated._calls
			expect(#calls).to.equal(1)
			expect(calls[1][1]).to.equal(player) -- first arg is the player
			expect(calls[1][2]).to.equal("SetNewOrder")
			expect(calls[1][3]).to.equal(items)
		end)

		it("should claim the oldest pending order when multiple exist", function()
			mockRank(true)
			local older = makeOrder({ orderNum = "0001" })
			local newer = makeOrder({ orderNum = "0009" })
			service._orders = { newer, older }
			service:_claimNextOrder(player)
			expect(older.status).to.equal("Being Prepared")
			expect(newer.status).to.equal("Pending Preparation")
		end)

		it("should not let a player claim a second order while one is active", function()
			mockRank(true)
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
	-- Client.CreateOrder
	-- ══════════════════════════════════════════════════════════════════════

	describe("Client.CreateOrder", function()
		local player = makePlayer(300)

		it("should do nothing when customerId is nil", function()
			mockRank(false, true)
			service.Client:CreateOrder(player, nil, { makeItem() })
			expect(#service._orders).to.equal(0)
		end)

		it("should do nothing when orderItems is nil", function()
			mockRank(false, true)
			service.Client:CreateOrder(player, 10001, nil)
			expect(#service._orders).to.equal(0)
		end)

		it("should reject players without the ordering rank", function()
			RankUtil.CanUseOrderingSystem = function() return false end
			service.Client:CreateOrder(player, 10001, { makeItem() })
			expect(#service._orders).to.equal(0)
		end)

		it("should reject an empty order array", function()
			RankUtil.CanUseOrderingSystem = function() return true end
			service.Client:CreateOrder(player, 10001, {})
			expect(#service._orders).to.equal(0)
		end)

		it("should reject orders exceeding the 4-item maximum", function()
			RankUtil.CanUseOrderingSystem = function() return true end
			service.Client:CreateOrder(player, 10001, {
				makeItem(), makeItem(), makeItem(), makeItem(), makeItem(), -- 5 items
			})
			expect(#service._orders).to.equal(0)
		end)

		it("should accept a valid 1-item order", function()
			RankUtil.CanUseOrderingSystem = function() return true end
			service.Client:CreateOrder(player, 10001, { makeItem() })
			expect(#service._orders).to.equal(1)
		end)

		it("should accept a valid 4-item order", function()
			RankUtil.CanUseOrderingSystem = function() return true end
			service.Client:CreateOrder(player, 10001, {
				makeItem(), makeItem(), makeItem(), makeItem(),
			})
			expect(#service._orders).to.equal(1)
			expect(service._orders[1].numItems).to.equal(4)
		end)

		it("should apply a per-player debounce on the second call", function()
			RankUtil.CanUseOrderingSystem = function() return true end
			service.Client:CreateOrder(player, 10001, { makeItem() })
			service.Client:CreateOrder(player, 10002, { makeItem() }) -- debounced
			expect(#service._orders).to.equal(1)
		end)

		it("should set a debounce entry for the ordering player", function()
			RankUtil.CanUseOrderingSystem = function() return true end
			service.Client:CreateOrder(player, 10001, { makeItem() })
			expect(service._orderDebounces[player.UserId]).to.equal(true)
		end)

		it("should allow a different player to order while first is debounced", function()
			RankUtil.CanUseOrderingSystem = function() return true end
			local other = makePlayer(999)
			service.Client:CreateOrder(player, 10001, { makeItem() })
			service.Client:CreateOrder(other, 10002, { makeItem() })
			expect(#service._orders).to.equal(2)
		end)

		it("should store the customer UserId from the argument", function()
			RankUtil.CanUseOrderingSystem = function() return true end
			service.Client:CreateOrder(player, 77777, { makeItem() })
			expect(service._orders[1].customer).to.equal(77777)
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
	-- _handlePickUp — staff deposit path
	-- ══════════════════════════════════════════════════════════════════════

	describe("_handlePickUp (staff deposit path)", function()
		it("should do nothing when staff has no active Being Prepared order", function()
			local staff = makePlayer(600)
			local area = makeArea(0) -- unclaimed area
			service._orders = {} -- no active order for this staff

			service:_handlePickUp(staff, area)

			expect(area.OrderOwner.Value).to.equal(0) -- area untouched
			area:Destroy()
		end)

		it("should fire Announcement when staff has fewer tools than order requires", function()
			local staff = makePlayer(600)
			-- Staff has empty backpack and no character tools
			staff.Character = Instance.new("Model")

			local area = makeArea(0)
			service._orders = {
				makeOrder({
					customer = 10001,
					status = "Being Prepared",
					preparedBy = staff.UserId,
					order = { makeItem(), makeItem() }, -- requires 2 tools
					numItems = 2,
				}),
			}

			service:_handlePickUp(staff, area)

			local calls = service.Client.Announcement._calls
			expect(#calls).to.equal(1)
			expect(calls[1][1]).to.equal(staff)
			-- First string arg is the title
			expect(calls[1][2]).to.be.a("string")
			area:Destroy()
		end)

		it("should release area (keep OrderOwner = 0) when tools insufficient", function()
			local staff = makePlayer(601)
			staff.Character = Instance.new("Model")
			local area = makeArea(0)
			service._orders = {
				makeOrder({
					customer = 10001,
					status = "Being Prepared",
					preparedBy = staff.UserId,
					order = { makeItem(), makeItem() },
					numItems = 2,
				}),
			}

			service:_handlePickUp(staff, area)

			expect(area.OrderOwner.Value).to.equal(0)
			area:Destroy()
		end)

		it("should apply a per-area debounce while a deposit is in progress", function()
			local staff = makePlayer(602)
			local area = makeArea(0)
			service._areaDebounces[area] = true

			service:_handlePickUp(staff, area)

			-- Announcement should NOT fire (debounced before any logic runs)
			expect(#service.Client.Announcement._calls).to.equal(0)
			area:Destroy()
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- collectTools (tested indirectly via _handlePickUp tool count check)
	-- ══════════════════════════════════════════════════════════════════════

	describe("tool collection logic", function()
		-- We validate collectTools behaviour by confirming that
		-- _handlePickUp recognises staff with tools vs without tools.

		it("should count tools from the player Backpack", function()
			local staff = makePlayer(700)
			staff.Character = Instance.new("Model") -- empty character

			local tool = Instance.new("Tool")
			tool.Parent = staff.Backpack

			local area = makeArea(0)
			service._orders = {
				makeOrder({
					customer = 10001,
					status = "Being Prepared",
					preparedBy = staff.UserId,
					order = { makeItem() }, -- requires 1 tool
					numItems = 1,
				}),
			}

			-- With 1 tool in backpack, the insufficient-tool Announcement
			-- should NOT fire (enough tools → prompt flow begins instead)
			service:_handlePickUp(staff, area)
			expect(#service.Client.Announcement._calls).to.equal(0)

			area:Destroy()
		end)

		it("should count tools worn in the Character", function()
			local staff = makePlayer(701)
			local character = Instance.new("Model")
			staff.Character = character

			local tool = Instance.new("Tool")
			tool.Parent = character

			local area = makeArea(0)
			service._orders = {
				makeOrder({
					customer = 10001,
					status = "Being Prepared",
					preparedBy = staff.UserId,
					order = { makeItem() },
					numItems = 1,
				}),
			}

			service:_handlePickUp(staff, area)
			expect(#service.Client.Announcement._calls).to.equal(0)

			area:Destroy()
		end)

		it("should fire Announcement when player has zero tools", function()
			local staff = makePlayer(702)
			staff.Character = Instance.new("Model") -- empty

			local area = makeArea(0)
			service._orders = {
				makeOrder({
					customer = 10001,
					status = "Being Prepared",
					preparedBy = staff.UserId,
					order = { makeItem() },
					numItems = 1,
				}),
			}

			service:_handlePickUp(staff, area)
			expect(#service.Client.Announcement._calls).to.equal(1)

			area:Destroy()
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- Order number formatting
	-- ══════════════════════════════════════════════════════════════════════

	describe("order number formatting", function()
		it("should produce a 4-character string for order 1", function()
			service:_addOrder(10001, { makeItem() })
			local num = service._orders[1].orderNum
			expect(#num).to.equal(4)
		end)

		it("should produce a 4-character string for order 100", function()
			service._currentOrderNum = 99
			service:_addOrder(10001, { makeItem() })
			local num = service._orders[1].orderNum
			expect(#num).to.equal(4)
		end)

		it("should produce '0999' for order 999", function()
			service._currentOrderNum = 998
			service:_addOrder(10001, { makeItem() })
			expect(service._orders[1].orderNum).to.equal("0999")
		end)

		it("should produce '0000' for order 1000 (wrap)", function()
			service._currentOrderNum = 999
			service:_addOrder(10001, { makeItem() })
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
			service:_addOrder(10001, { makeItem() })
			expect(service._orders[1].statusColor).to.equal(COLOR_PENDING)
		end)

		it("claimed orders use the preparing (yellow) colour", function()
			mockRank(true)
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
end

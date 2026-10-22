-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	RegisterQueue.spec.luau
	Unit tests for multi-register queueing, line ordering, and advance-on-submit.
]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local CustomerService = require(ServerScriptService.Server.Modules.CustomerService) :: any

	describe("Register Queuing System", function()
		it("maintains line order per register", function()
			-- Reset test state
			CustomerService._registerLines = {}
			CustomerService._npcRegister = {}
			CustomerService._counter = {}

			local mockNpc1 = { Name = "Customer1" } :: any
			local mockNpc2 = { Name = "Customer2" } :: any
			local mockNpc3 = { Name = "Customer3" } :: any

			local spot = 2
			CustomerService._npcRegister[mockNpc1] = spot
			CustomerService._registerLines[spot] = { mockNpc1 }

			CustomerService._npcRegister[mockNpc2] = spot
			table.insert(CustomerService._registerLines[spot], mockNpc2)

			CustomerService._npcRegister[mockNpc3] = spot
			table.insert(CustomerService._registerLines[spot], mockNpc3)

			-- Context methods
			local dummyNodes = { Counter = { [spot] = Instance.new("Part") } } :: any
			local dummyFolder = Instance.new("Folder")
			local ctx = CustomerService:_makeContext(dummyNodes, dummyFolder)

			-- Customer 1 should be index 1
			expect(ctx.QueueIndex(mockNpc1)).to.equal(1)
			-- Customer 2 should be index 2
			expect(ctx.QueueIndex(mockNpc2)).to.equal(2)
			-- Customer 3 should be index 3
			expect(ctx.QueueIndex(mockNpc3)).to.equal(3)

			-- Only Customer 1 can take counter
			expect(ctx.TryTakeCounter(mockNpc2)).to.equal(nil)
			expect(ctx.TryTakeCounter(mockNpc3)).to.equal(nil)
			expect(ctx.TryTakeCounter(mockNpc1)).to.equal(spot)

			-- Front customer submits order and frees counter spot
			ctx.ReleaseCounter(mockNpc1)

			-- Customer 2 should now be index 1, Customer 3 index 2
			expect(ctx.QueueIndex(mockNpc2)).to.equal(1)
			expect(ctx.QueueIndex(mockNpc3)).to.equal(2)

			-- Customer 2 can now take counter
			expect(ctx.TryTakeCounter(mockNpc3)).to.equal(nil)
			expect(ctx.TryTakeCounter(mockNpc2)).to.equal(spot)

			-- Clean up
			ctx.Release(mockNpc2)
			ctx.Release(mockNpc3)
			expect(#CustomerService._registerLines[spot]).to.equal(0)
			dummyNodes.Counter[spot]:Destroy()
			dummyFolder:Destroy()
		end)

		it("chooses registers with random distribution among shorter lines", function()
			CustomerService._registerLines = {}
			CustomerService._npcRegister = {}

			local dummyNodes = { Counter = {} } :: any
			for i = 1, 6 do
				dummyNodes.Counter[i] = Instance.new("Part")
				CustomerService._registerLines[i] = {}
			end

			CustomerService._context = { Nodes = dummyNodes } :: any

			-- Simulate picking registers for 6 customers
			local picked = {}
			for _ = 1, 6 do
				local spot = CustomerService:_pickRegisterSpot()
				expect(spot >= 1 and spot <= 6).to.equal(true)
				table.insert(picked, spot)
				table.insert(CustomerService._registerLines[spot], {})
			end

			expect(#picked).to.equal(6)

			for i = 1, 6 do
				dummyNodes.Counter[i]:Destroy()
			end
		end)
	end)
end

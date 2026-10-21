-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	RealOrder.spec.luau
	TestEZ tests for the real-order anti-farm pay rule (REVIVAL-001 M2-REALORDER).
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local RealOrderService = require(ServerScriptService.Server.Modules.RealOrderService)

	describe("CountsForTeamChain", function()
		it("counts fresh serves and ignores throttled ones", function()
			expect(RealOrderService.CountsForTeamChain(2)).to.equal(true)
			expect(RealOrderService.CountsForTeamChain(1)).to.equal(false)
		end)

		it("counts the first 3 serves of a pair in the window and not the 4th", function()
			local history = {}
			local counted = {}
			for i = 1, 4 do
				local now = i * 10
				local m = RealOrderService.PayMultiplier(history, 1, 2, now)
				RealOrderService.Record(history, 1, 2, now)
				table.insert(counted, RealOrderService.CountsForTeamChain(m))
			end
			expect(counted[1]).to.equal(true)
			expect(counted[2]).to.equal(true)
			expect(counted[3]).to.equal(true)
			expect(counted[4]).to.equal(false)
		end)
	end)

	describe("ShiftResult", function()
		it("records Perfect and Close serves with neutral Fast and Combo", function()
			local perfect = RealOrderService.ShiftResult("Perfect", 20, 0)
			expect(perfect.Grade).to.equal("Perfect")
			expect(perfect.Pay).to.equal(20)
			expect(perfect.Kind).to.equal("Served")
			expect(perfect.Fast).to.equal(false)
			expect(perfect.Combo).to.equal(0)
			expect(RealOrderService.ShiftResult(nil, 10, 0).Grade).to.equal("Close")
		end)

		it("removes the tip extra from Pay so it is counted once", function()
			local r = RealOrderService.ShiftResult("Close", 20, 5)
			expect(r.Pay).to.equal(15)
			expect(r.Tip).to.equal(nil)
			expect(RealOrderService.ShiftResult("Perfect", 3, 5).Pay).to.equal(0)
		end)
	end)

	describe("PayMultiplier", function()
		it("pays x2 for 3 orders in the window, 1 for the 4th, x2 again after the window", function()
			local history = {}
			local m = {}
			for i = 1, 4 do
				local now = i * 10
				table.insert(m, RealOrderService.PayMultiplier(history, 1, 2, now))
				RealOrderService.Record(history, 1, 2, now)
			end
			expect(m[1]).to.equal(2)
			expect(m[2]).to.equal(2)
			expect(m[3]).to.equal(2)
			expect(m[4]).to.equal(1)
			expect(RealOrderService.PayMultiplier(history, 1, 2, 40 + 601)).to.equal(2)
		end)

		it("counts each barista and customer pair separately", function()
			local history = {}
			for i = 1, 3 do
				RealOrderService.Record(history, 1, 2, i)
			end
			expect(RealOrderService.PayMultiplier(history, 1, 3, 5)).to.equal(2)
			expect(RealOrderService.PayMultiplier(history, 9, 2, 5)).to.equal(2)
		end)
	end)
end

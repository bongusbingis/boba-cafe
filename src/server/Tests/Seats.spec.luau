-- selene: allow(undefined_variable)
--[[
	Seats.spec.luau (REVIVAL-001 BIG-B4)
	TestEZ unit tests for the Seats module: pool creation, seat claiming,
	distance sorting, budget limits, release and forget lifecycles.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")

	local Seats = require(ServerScriptService.Server.Modules.CustomerService.Seats)

	local function createSeat(pos: Vector3): Seat
		local seat = Instance.new("Seat")
		seat.Position = pos
		return seat
	end

	describe("Seats.new()", function()
		it("initializes an empty pool with provided seats and zero budget used", function()
			local s1 = createSeat(Vector3.new(0, 0, 0))
			local pool = Seats.new({ s1 }, 5)
			expect(pool:BudgetUsed()).to.equal(0)
		end)
	end)

	describe("TryClaim", function()
		it("claims the nearest free seat and sets NpcReservedBy attribute", function()
			local s1 = createSeat(Vector3.new(10, 0, 0))
			local s2 = createSeat(Vector3.new(5, 0, 0))
			local pool = Seats.new({ s1, s2 }, 5)

			local claimed = pool:TryClaim("npc1", Vector3.new(0, 0, 0), 20)
			expect(claimed).to.equal(s2)
			expect(s2:GetAttribute("NpcReservedBy")).to.equal("npc1")
			expect(pool:BudgetUsed()).to.equal(1)
		end)

		it("does not claim seats beyond maxDist", function()
			local s1 = createSeat(Vector3.new(100, 0, 0))
			local pool = Seats.new({ s1 }, 5)

			local claimed = pool:TryClaim("npc1", Vector3.new(0, 0, 0), 50)
			expect(claimed).to.equal(nil)
			expect(pool:BudgetUsed()).to.equal(0)
		end)

		it("skips disabled seats", function()
			local s1 = createSeat(Vector3.new(5, 0, 0))
			s1.Disabled = true
			local s2 = createSeat(Vector3.new(10, 0, 0))
			local pool = Seats.new({ s1, s2 }, 5)

			local claimed = pool:TryClaim("npc1", Vector3.new(0, 0, 0), 20)
			expect(claimed).to.equal(s2)
		end)

		it("skips seats with an existing occupant", function()
			local s1 = createSeat(Vector3.new(5, 0, 0))
			local hum = Instance.new("Humanoid")
			-- Occupant is a read-only property on Seat in live engine, but
			-- if a seat is reserved or occupied, Occupant ~= nil.
			-- We test NpcReservedBy and seat attributes:
			s1:SetAttribute("NpcReservedBy", "someone_else")
			local s2 = createSeat(Vector3.new(10, 0, 0))
			local pool = Seats.new({ s1, s2 }, 5)

			local claimed = pool:TryClaim("npc1", Vector3.new(0, 0, 0), 20)
			expect(claimed).to.equal(s2)
			hum:Destroy()
		end)

		it("does not allow the same npcId to claim multiple seats simultaneously", function()
			local s1 = createSeat(Vector3.new(5, 0, 0))
			local s2 = createSeat(Vector3.new(10, 0, 0))
			local pool = Seats.new({ s1, s2 }, 5)

			local claimed1 = pool:TryClaim("npc1", Vector3.new(0, 0, 0), 20)
			local claimed2 = pool:TryClaim("npc1", Vector3.new(0, 0, 0), 20)
			expect(claimed1).to.equal(s1)
			expect(claimed2).to.equal(nil)
			expect(pool:BudgetUsed()).to.equal(1)
		end)

		it("enforces budget limits", function()
			local s1 = createSeat(Vector3.new(5, 0, 0))
			local s2 = createSeat(Vector3.new(10, 0, 0))
			local pool = Seats.new({ s1, s2 }, 1) -- budget of 1

			local claimed1 = pool:TryClaim("npc1", Vector3.new(0, 0, 0), 20)
			local claimed2 = pool:TryClaim("npc2", Vector3.new(0, 0, 0), 20)
			expect(claimed1).to.equal(s1)
			expect(claimed2).to.equal(nil)
			expect(pool:BudgetUsed()).to.equal(1)
		end)

		it("respects dynamic budget functions", function()
			local s1 = createSeat(Vector3.new(5, 0, 0))
			local s2 = createSeat(Vector3.new(10, 0, 0))
			local budget = 0
			local pool = Seats.new({ s1, s2 }, function()
				return budget
			end)

			expect(pool:TryClaim("npc1", Vector3.new(0, 0, 0), 20)).to.equal(nil)
			budget = 2
			expect(pool:TryClaim("npc1", Vector3.new(0, 0, 0), 20)).to.equal(s1)
		end)
	end)

	describe("Release", function()
		it("releases seat reservation and decrements BudgetUsed", function()
			local s1 = createSeat(Vector3.new(5, 0, 0))
			local pool = Seats.new({ s1 }, 5)

			local claimed = pool:TryClaim("npc1", Vector3.new(0, 0, 0), 20)
			expect(claimed).to.equal(s1)
			expect(pool:BudgetUsed()).to.equal(1)

			pool:Release(s1, "npc1")
			expect(s1:GetAttribute("NpcReservedBy")).to.equal(nil)
			expect(pool:BudgetUsed()).to.equal(0)

			-- Can be claimed again after release
			local claimedAgain = pool:TryClaim("npc2", Vector3.new(0, 0, 0), 20)
			expect(claimedAgain).to.equal(s1)
		end)
	end)

	describe("Forget", function()
		it("cleans up claimed seats for an npcId", function()
			local s1 = createSeat(Vector3.new(5, 0, 0))
			local pool = Seats.new({ s1 }, 5)

			pool:TryClaim("npc1", Vector3.new(0, 0, 0), 20)
			expect(pool:BudgetUsed()).to.equal(1)

			pool:Forget("npc1")
			expect(s1:GetAttribute("NpcReservedBy")).to.equal(nil)
			expect(pool:BudgetUsed()).to.equal(0)
		end)

		it("is idempotent when forgetting unknown npcId", function()
			local s1 = createSeat(Vector3.new(5, 0, 0))
			local pool = Seats.new({ s1 }, 5)

			pool:Forget("nonexistent")
			expect(pool:BudgetUsed()).to.equal(0)
		end)
	end)
end

-- selene: allow(undefined_variable)
--[[
	CustomerService.spec.luau
	TestEZ tests for the pure NPC customer rules (REVIVAL-001 M1.4c): pacing target
	(design 4.2), patience (4.5) and the order pick (4.4).

	Rules is pure, so these tests need no Instances and no authored place content.
	Expected numbers come from the design tables; they are TUNING values, so a
	config change that moves them should update these cases on purpose.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local Rules = require(ServerScriptService.Server.Modules.CustomerService.Rules)
	local CustomerConfig = require(ReplicatedStorage.Shared.Configuration.CustomerConfig)

	-- An rng that returns the given rolls in order, then 0.
	local function sequence(rolls: { number }): () -> number
		local index = 0
		return function()
			index += 1
			return rolls[index] or 0
		end
	end

	local function item(category: string)
		return { Category = category, Item = "x", CustomInfo = {} }
	end

	describe("PacingTarget (design 4.2)", function()
		local cases = {
			{ baristas = 0, expected = 0 }, -- nobody clocked in: nothing spawns
			{ baristas = 1, expected = 2 }, -- slots 1 + line 1
			{ baristas = 3, expected = 4 }, -- slots 3 + line 1
			{ baristas = 4, expected = 6 }, -- slots 4 + line 2
			{ baristas = 5, expected = 7 }, -- slots 5 + line 2
			{ baristas = 20, expected = 16 }, -- 26 capped at SERVER_CAP
			{ baristas = 40, expected = 16 }, -- 51 capped at SERVER_CAP
		}

		for _, case in cases do
			it(`should give {case.expected} NPCs for {case.baristas} baristas`, function()
				expect(Rules.PacingTarget(case.baristas)).to.equal(case.expected)
			end)
		end

		it("should never exceed SERVER_CAP", function()
			for baristas = 0, 100 do
				expect(Rules.PacingTarget(baristas) <= CustomerConfig.SERVER_CAP).to.equal(true)
			end
		end)

		it("should treat a negative barista count as none", function()
			expect(Rules.PacingTarget(-3)).to.equal(0)
		end)
	end)

	describe("PatienceSeconds (design 4.5)", function()
		it("should give a single boba 70 seconds", function()
			expect(Rules.PatienceSeconds({ item("Boba Teas") })).to.equal(70)
		end)

		it("should give a single coffee 60 seconds", function()
			expect(Rules.PatienceSeconds({ item("Coffees") })).to.equal(60)
		end)

		it("should give a single brownie 55 seconds", function()
			expect(Rules.PatienceSeconds({ item("Pastries") })).to.equal(55)
		end)

		it("should give boba plus brownie 80 seconds", function()
			expect(Rules.PatienceSeconds({ item("Boba Teas"), item("Pastries") })).to.equal(80)
		end)

		it("should give hot cocoa the boba bonus and tea the coffee bonus", function()
			expect(Rules.PatienceSeconds({ item("Hot Cocoas") })).to.equal(70)
			expect(Rules.PatienceSeconds({ item("Teas") })).to.equal(60)
		end)

		it("should give an empty order just the base", function()
			expect(Rules.PatienceSeconds({})).to.equal(CustomerConfig.PATIENCE_BASE_SECONDS)
		end)
	end)

	describe("PatienceState", function()
		it("should be green above half", function()
			expect(Rules.PatienceState(1)).to.equal("Green")
			expect(Rules.PatienceState(0.51)).to.equal("Green")
		end)

		it("should be yellow from half down to a quarter", function()
			expect(Rules.PatienceState(0.5)).to.equal("Yellow")
			expect(Rules.PatienceState(0.26)).to.equal("Yellow")
		end)

		it("should be red at a quarter and below", function()
			expect(Rules.PatienceState(0.25)).to.equal("Red")
			expect(Rules.PatienceState(0)).to.equal("Red")
		end)
	end)

	describe("PickOrder (design 4.4)", function()
		-- Pool weights 55 / 30 / 15, so the first roll picks the item:
		-- [0, 0.55) boba, [0.55, 0.85) coffee, [0.85, 1) brownie.
		-- Size weights 30 / 40 / 30: [0, 0.3) Small, [0.3, 0.7) Medium, [0.7, 1) Large.

		it("should pick the boba on a low roll", function()
			local order = Rules.PickOrder(sequence({ 0, 0.5 }))
			expect(order.Category).to.equal("Boba Teas")
			expect(order.Item).to.equal("Custom Boba")
			expect(order.CustomInfo.Size).to.equal("Medium")
			expect(order.CustomInfo["Syrup Flavor"]).to.equal("Classic Milk Tea")
			expect(order.CustomInfo["Tapioca Flavor"]).to.equal("Normal")
		end)

		it("should pick the coffee in the middle of the roll range", function()
			local order = Rules.PickOrder(sequence({ 0.6, 0.1 }))
			expect(order.Category).to.equal("Coffees")
			expect(order.Item).to.equal("Regular")
			expect(order.CustomInfo.Size).to.equal("Small")
			expect(order.CustomInfo.Iced).to.equal(false)
			expect(order.CustomInfo.Sugar).to.equal(false)
		end)

		it("should pick the brownie on a high roll, with no size", function()
			local order = Rules.PickOrder(sequence({ 0.9 }))
			expect(order.Category).to.equal("Pastries")
			expect(order.Item).to.equal("Fudge Brownie")
			expect(order.CustomInfo.Size).to.equal(nil)
		end)

		it("should land on the item boundaries as the weights say", function()
			expect(Rules.PickOrder(sequence({ 0.549, 0 })).Item).to.equal("Custom Boba")
			expect(Rules.PickOrder(sequence({ 0.551, 0 })).Item).to.equal("Regular")
			expect(Rules.PickOrder(sequence({ 0.849, 0 })).Item).to.equal("Regular")
			expect(Rules.PickOrder(sequence({ 0.851, 0 })).Item).to.equal("Fudge Brownie")
		end)

		it("should pick Large on a high size roll", function()
			expect(Rules.PickOrder(sequence({ 0, 0.9 })).CustomInfo.Size).to.equal("Large")
		end)

		it("should survive a roll of exactly 1", function()
			expect(Rules.PickOrder(sequence({ 1 })).Item).to.equal("Fudge Brownie")
		end)

		it("should give the same order for the same rolls", function()
			local first = Rules.PickOrder(sequence({ 0.2, 0.8 }))
			local second = Rules.PickOrder(sequence({ 0.2, 0.8 }))
			expect(first.Item).to.equal(second.Item)
			expect(first.CustomInfo.Size).to.equal(second.CustomInfo.Size)
		end)

		it("should not change the config pool", function()
			local order = Rules.PickOrder(sequence({ 0, 0.9 }))
			order.CustomInfo.Marker = true
			expect(CustomerConfig.ORDER_POOL[1].OrderItem.CustomInfo.Size).to.equal(nil)
			expect(CustomerConfig.ORDER_POOL[1].OrderItem.CustomInfo.Marker).to.equal(nil)
		end)

		it("should work with the default rng", function()
			for _ = 1, 50 do
				local order = Rules.PickOrder()
				expect(typeof(order.Item)).to.equal("string")
			end
		end)
	end)
end

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
	local OrderSpec = require(ReplicatedStorage.Shared.Ordering.OrderSpec)
	local Menu = require(ReplicatedStorage.Shared.Ordering.Menu)
	local Progression = require(ReplicatedStorage.Shared.Configuration.Progression)

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

		it("should never pick a level-2 drink at level 1", function()
			for step = 0, 99 do
				local order = Rules.PickOrder(sequence({ step / 100, 0 }), nil, 1)
				local syrup = order.CustomInfo["Syrup Flavor"]
				expect(syrup == nil or syrup == "Classic Milk Tea").to.equal(true)
			end
		end)

		it("should pick Taro Boba at level 2", function()
			local order = Rules.PickOrder(sequence({ 0.85, 0 }), nil, 2)
			expect(order.Item).to.equal("Custom Boba")
			expect(order.CustomInfo["Syrup Flavor"]).to.equal("Taro")
			expect(order.CustomInfo["Tapioca Flavor"]).to.equal("Normal")
			expect(order.CustomInfo.Size).to.equal("Small")
		end)

		it("should pick Strawberry Boba at level 2", function()
			local order = Rules.PickOrder(sequence({ 0.95, 0 }), nil, 2)
			expect(order.CustomInfo["Syrup Flavor"]).to.equal("Strawberry")
		end)

		it("should keep the classic picks at level 2", function()
			expect(Rules.PickOrder(sequence({ 0.5, 0 }), nil, 2).Item).to.equal("Regular")
		end)

		it("should never pick Espresso or Mango Boba below their level", function()
			for step = 0, 99 do
				local order = Rules.PickOrder(sequence({ step / 100, 0 }), nil, 6)
				expect(order.Item ~= "Espresso").to.equal(true)
				expect(order.CustomInfo["Syrup Flavor"] ~= "Mango").to.equal(true)
			end
		end)

		it("should pick Espresso at level 7", function()
			local order = Rules.PickOrder(sequence({ 0.95, 0 }), nil, 7)
			expect(order.Category).to.equal("Coffees")
			expect(order.Item).to.equal("Espresso")
			expect(order.CustomInfo.Iced).to.equal(false)
			expect(order.CustomInfo.Sugar).to.equal(false)
			expect(order.CustomInfo.Size).to.equal("Small")
		end)

		it("should keep Strawberry Boba below Espresso at level 7", function()
			local order = Rules.PickOrder(sequence({ 0.9, 0 }), nil, 7)
			expect(order.CustomInfo["Syrup Flavor"]).to.equal("Strawberry")
		end)

		it("should pick Mango Boba at level 8", function()
			local order = Rules.PickOrder(sequence({ 0.97, 0 }), nil, 8)
			expect(order.Item).to.equal("Custom Boba")
			expect(order.CustomInfo["Syrup Flavor"]).to.equal("Mango")
			expect(order.CustomInfo["Tapioca Flavor"]).to.equal("Normal")
		end)

		it("should pick Espresso at level 8", function()
			local order = Rules.PickOrder(sequence({ 0.91, 0 }), nil, 8)
			expect(order.Item).to.equal("Espresso")
		end)
	end)

	-- A pool entry OrderSpec rejects makes CustomerService skip the spawn silently, so
	-- every entry at every size must resolve against the real Menu, and be orderable.
	describe("ORDER_POOL against the real OrderSpec and Menu", function()
		it("should have at least one entry and one size", function()
			expect(#CustomerConfig.ORDER_POOL > 0).to.equal(true)
			expect(#CustomerConfig.SIZE_WEIGHTS > 0).to.equal(true)
		end)

		for index, entry in CustomerConfig.ORDER_POOL do
			local label = `{entry.OrderItem.Category}/{entry.OrderItem.Item}`
			local sizes = if entry.Sized then CustomerConfig.SIZE_WEIGHTS else { { Size = false } }

			for _, sizeWeight in sizes do
				it(`should resolve pool entry {index} ({label}) at size {tostring(sizeWeight.Size)}`, function()
					local customInfo = table.clone(entry.OrderItem.CustomInfo)
					if sizeWeight.Size then
						customInfo.Size = sizeWeight.Size
					end
					local spec, reason = OrderSpec.FromOrderItem({
						Category = entry.OrderItem.Category,
						Item = entry.OrderItem.Item,
						CustomInfo = customInfo,
					})
					expect(reason).to.equal(nil)
					expect(spec).to.be.ok()
				end)
			end

			it(`should keep pool entry {index} ({label}) on the launch menu`, function()
				expect(Menu.IsLaunchItem(entry.OrderItem.Category, entry.OrderItem.Item, entry.OrderItem.CustomInfo)).to.equal(
					true
				)
			end)
		end

		it("should resolve what PickOrder returns, at every size", function()
			for rollIndex = 0, 9 do
				for sizeIndex = 0, 9 do
					local order = Rules.PickOrder(sequence({ rollIndex / 10, sizeIndex / 10 }))
					local spec = OrderSpec.FromOrderItem({
						Category = order.Category,
						Item = order.Item,
						CustomInfo = order.CustomInfo,
					})
					expect(spec).to.be.ok()
				end
			end
		end)
	end)

	describe("ORDER_POOL level ladder (B1)", function()
		it("should give every entry a unique Key and Label and the level from Progression", function()
			local seen = {}
			for _, entry in CustomerConfig.ORDER_POOL do
				expect(#entry.Key > 0).to.equal(true)
				expect(#entry.Label > 0).to.equal(true)
				expect(seen[entry.Key]).to.equal(nil)
				seen[entry.Key] = true
				expect(entry.MinLevel).to.equal(Progression.MIN_LEVEL_BY_ITEM[entry.Key])
			end
		end)

		it("should keep the classics at or above CLASSIC_MIN_SHARE at every level", function()
			for level = 1, Progression.MAX_LEVEL do
				local classic, total = 0, 0
				for _, entry in CustomerConfig.ORDER_POOL do
					if entry.MinLevel <= level then
						total += entry.Weight
						if entry.MinLevel == 1 then
							classic += entry.Weight
						end
					end
				end
				expect(classic / total >= CustomerConfig.CLASSIC_MIN_SHARE).to.equal(true)
			end
		end)

		it("should cap new entry weights at NEW_ENTRY_MAX_WEIGHT", function()
			for _, entry in CustomerConfig.ORDER_POOL do
				if entry.MinLevel > 1 then
					expect(entry.Weight <= CustomerConfig.NEW_ENTRY_MAX_WEIGHT).to.equal(true)
				end
			end
		end)

		it("should list the new drinks by level", function()
			expect(#Rules.NewDrinksAt(1)).to.equal(0)
			expect(#Rules.NewDrinksAt(3)).to.equal(0)
			local two = Rules.NewDrinksAt(2)
			expect(#two).to.equal(2)
			expect(two[1]).to.equal("Taro Boba")
			expect(two[2]).to.equal("Strawberry Boba")
		end)

		it("should list Espresso at 7 and Mango Boba at 8", function()
			local seven = Rules.NewDrinksAt(7)
			expect(#seven).to.equal(1)
			expect(seven[1]).to.equal("Espresso")
			local eight = Rules.NewDrinksAt(8)
			expect(#eight).to.equal(1)
			expect(eight[1]).to.equal("Mango Boba")
			expect(#Rules.NewDrinksAt(6)).to.equal(0)
		end)
	end)

	describe("Payout (design 3.5)", function()
		local function boba()
			return {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = { ["Syrup Flavor"] = "Classic Milk Tea", ["Tapioca Flavor"] = "Normal", Size = "Medium" },
			}
		end

		local function coffee(iced, sugar)
			return {
				Category = "Coffees",
				Item = "Regular",
				CustomInfo = { Iced = iced, Sugar = sugar, Size = "Small" },
			}
		end

		local function brownie()
			return { Category = "Pastries", Item = "Fudge Brownie", CustomInfo = {} }
		end

		it("should pay 5 for the first Perfect scripted boba", function()
			expect(Rules.Payout({ boba() }, "Perfect", 1, 0, true, false)).to.equal(5)
		end)

		it("should pay 2 for a Perfect non-fast coffee", function()
			expect(Rules.Payout({ coffee(false, false) }, "Perfect", 0, 0, false, false)).to.equal(2)
		end)

		it("should charge 1 per Iced and Sugar on coffee", function()
			expect(Rules.Payout({ coffee(true, true) }, "Perfect", 0, 0, false, false)).to.equal(4)
		end)

		it("should halve and round with a minimum of 1 on Close", function()
			expect(Rules.Payout({ coffee(false, false) }, "Close", 0, 0, false, false)).to.equal(1)
			expect(Rules.Payout({ brownie() }, "Close", 0, 0, false, false)).to.equal(1)
		end)

		it("should pay Fast x1.5 at half patience left", function()
			expect(Rules.Payout({ coffee(false, false) }, "Perfect", 0.5, 0, false, false)).to.equal(3)
			expect(Rules.Payout({ coffee(false, false) }, "Perfect", 0.49, 0, false, false)).to.equal(2)
		end)

		it("should cap the combo bonus at +50%", function()
			expect(Rules.Payout({ coffee(false, false) }, "Perfect", 0, 5, false, false)).to.equal(3)
			expect(Rules.Payout({ coffee(false, false) }, "Perfect", 0, 10, false, false)).to.equal(3)
			expect(Rules.Payout({ coffee(false, false) }, "Perfect", 0, 2, false, false)).to.equal(2)
		end)

		it("should pay Rescue x1.5", function()
			expect(Rules.Payout({ coffee(false, false) }, "Perfect", 0.1, 0, false, true)).to.equal(3)
		end)

		it("should sum a multi-item order", function()
			expect(Rules.Payout({ boba(), brownie() }, "Perfect", 0, 0, false, false)).to.equal(4)
		end)

		it("should never pay below MIN_PAY", function()
			expect(Rules.Payout({ brownie() }, "Close", 0, 0, false, false)).to.equal(1)
		end)
	end)

	describe("Variants (design 4.10)", function()
		it("should pick no variant below L6", function()
			expect(Rules.PickVariant(5, 0.05)).to.equal(nil)
		end)

		it("should pick VIP from L6 and Karen from L10", function()
			expect(Rules.PickVariant(6, 0.05)).to.equal("VIP")
			expect(Rules.PickVariant(6, 0.5)).to.equal(nil)
			expect(Rules.PickVariant(10, 0.05)).to.equal("Karen")
			expect(Rules.PickVariant(10, 0.15)).to.equal("VIP")
		end)

		it("should pay VIP double and Karen triple only on Perfect", function()
			expect(Rules.PayoutVariant(5, "VIP", "Perfect")).to.equal(10)
			expect(Rules.PayoutVariant(5, "Karen", "Perfect")).to.equal(15)
			expect(Rules.PayoutVariant(5, "Karen", "Close")).to.equal(5)
			expect(Rules.PayoutVariant(5, nil, "Perfect")).to.equal(5)
		end)
	end)

	describe("NextCombo", function()
		it("should add one step on Perfect", function()
			expect(Rules.NextCombo(0, "Perfect")).to.equal(1)
			expect(Rules.NextCombo(3, "Perfect")).to.equal(4)
		end)

		it("should reset to 0 on Close", function()
			expect(Rules.NextCombo(3, "Close")).to.equal(0)
			expect(Rules.NextCombo(0, "Close")).to.equal(0)
		end)
	end)

	describe("CanServe (design 4.3)", function()
		it("should always let the assignee serve", function()
			expect(Rules.CanServe(true, 1)).to.equal(true)
			expect(Rules.CanServe(true, 0)).to.equal(true)
		end)

		it("should let others serve only below 30% patience", function()
			expect(Rules.CanServe(false, 0.31)).to.equal(false)
			expect(Rules.CanServe(false, 0.3)).to.equal(false)
			expect(Rules.CanServe(false, 0.29)).to.equal(true)
		end)
	end)

	describe("PickAssignee (design 4.3)", function()
		it("should pick the longest idle barista", function()
			local ana = { UserId = 1 }
			local bo = { UserId = 2 }
			local idleSince = { [ana] = 100, [bo] = 50 }
			expect(Rules.PickAssignee({ ana, bo }, idleSince)).to.equal(bo)
			expect(Rules.PickAssignee({ bo, ana }, idleSince)).to.equal(bo)
		end)

		it("should return nil when nobody qualifies", function()
			expect(Rules.PickAssignee({}, {})).to.equal(nil)
		end)
	end)
end

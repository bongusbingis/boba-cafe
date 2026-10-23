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
	local CounterLock = require(ServerScriptService.Server.Modules.CustomerService.CounterLock)
	local CustomerService = require(ServerScriptService.Server.Modules.CustomerService)
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

	describe("PatienceRampMult (C6)", function()
		it("should give 1 for nil", function()
			expect(Rules.PatienceRampMult(nil)).to.equal(1)
		end)

		it("should give 1 for shift 1", function()
			expect(Rules.PatienceRampMult(1)).to.equal(1)
		end)

		it("should give 1 for shift 2", function()
			expect(Rules.PatienceRampMult(2)).to.equal(1)
		end)

		it("should give 0.95 for shift 3", function()
			expect(Rules.PatienceRampMult(3)).to.be.near(0.95, 0.001)
		end)

		it("should give 0.90 for shift 4", function()
			expect(Rules.PatienceRampMult(4)).to.be.near(0.90, 0.001)
		end)

		it("should cap at 0.90 for shift 5", function()
			expect(Rules.PatienceRampMult(5)).to.be.near(0.90, 0.001)
		end)

		it("should cap at 0.90 for shift 50", function()
			expect(Rules.PatienceRampMult(50)).to.be.near(0.90, 0.001)
		end)
	end)

	describe("PatienceSeconds with a session shift (C6)", function()
		it("should give a single boba 70 with a nil shift", function()
			expect(Rules.PatienceSeconds({ item("Boba Teas") }, nil, nil)).to.equal(70)
		end)

		it("should give a single boba 70 on shift 2", function()
			expect(Rules.PatienceSeconds({ item("Boba Teas") }, nil, 2)).to.equal(70)
		end)

		it("should give a single boba 66.5 on shift 3", function()
			expect(Rules.PatienceSeconds({ item("Boba Teas") }, nil, 3)).to.be.near(66.5, 0.001)
		end)

		it("should give a single boba 63 on shift 4", function()
			expect(Rules.PatienceSeconds({ item("Boba Teas") }, nil, 4)).to.be.near(63, 0.001)
		end)

		it("should give a single coffee 54 on shift 5", function()
			expect(Rules.PatienceSeconds({ item("Coffees") }, nil, 5)).to.be.near(54, 0.001)
		end)

		it("should give an empty order 42.75 on shift 3", function()
			expect(Rules.PatienceSeconds({}, nil, 3)).to.be.near(42.75, 0.001)
		end)

		it("should give boba plus brownie 72 on shift 4", function()
			expect(Rules.PatienceSeconds({ item("Boba Teas"), item("Pastries") }, nil, 4)).to.be.near(72, 0.001)
		end)

		it("should follow a config override", function()
			local c = table.clone(CustomerConfig) :: any
			c.PATIENCE_RAMP_FIRST_SHIFT = 2
			c.PATIENCE_RAMP_TRIM_PER_SHIFT = 0.1
			c.PATIENCE_RAMP_MAX_TRIM = 0.2
			expect(Rules.PatienceSeconds({ item("Boba Teas") }, c, 3)).to.be.near(56, 0.001)
		end)

		it("should compose Karen after the ramp", function()
			expect(Rules.VariantPatience(Rules.PatienceSeconds({ item("Boba Teas") }, nil, 3), "Karen")).to.be.near(
				66.5 * CustomerConfig.VARIANTS.Karen.PatienceMult,
				0.001
			)
		end)

		it("should keep the ramp constants in range", function()
			expect(CustomerConfig.PATIENCE_RAMP_FIRST_SHIFT >= 3).to.equal(true)
			expect(CustomerConfig.PATIENCE_RAMP_MAX_TRIM <= 0.10).to.equal(true)
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
			local two = Rules.NewDrinksAt(2)
			expect(#two).to.equal(2)
			expect(two[1]).to.equal("Taro Boba")
			expect(two[2]).to.equal("Strawberry Boba")
			local three = Rules.NewDrinksAt(3)
			expect(#three).to.equal(2)
			expect(three[1]).to.equal("Coconut Boba")
			expect(three[2]).to.equal("Green Tea Boba")
		end)

		it("should list Espresso at 7 and Mango Boba at 8", function()
			local seven = Rules.NewDrinksAt(7)
			expect(#seven).to.equal(1)
			expect(seven[1]).to.equal("Espresso")
			local eight = Rules.NewDrinksAt(8)
			expect(#eight).to.equal(2)
			expect(eight[1]).to.equal("Mango Boba")
			expect(eight[2]).to.equal("Matcha Boba")
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

	describe("Dedicated Assignment Mode", function()
		it("should configure ASSIGNMENT_MODE as Dedicated", function()
			expect(CustomerConfig.ASSIGNMENT_MODE).to.equal("Dedicated")
		end)
	end)

	describe("FormatOrderForNotepad", function()
		it("should format a boba drink with size, syrup, tapioca, and ice", function()
			local bobaOrder = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = {
					Size = "Large",
					["Syrup Flavor"] = "Strawberry",
					["Tapioca Flavor"] = "Normal",
					Iced = true,
				},
			}
			local text = Rules.FormatOrderItemForNotepad(bobaOrder)
			expect(text).to.equal("Large Strawberry Boba, Normal Tapioca, Ice")
		end)

		it("should format multi-item orders joined by newline", function()
			local bobaOrder = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = {
					Size = "Large",
					["Syrup Flavor"] = "Strawberry",
					["Tapioca Flavor"] = "Normal",
					Iced = true,
				},
			}
			local pastryOrder = {
				Category = "Pastries",
				Item = "Fudge Brownie",
				CustomInfo = {},
			}
			local text = Rules.FormatOrderForNotepad({ bobaOrder, pastryOrder })
			expect(text).to.equal("Large Strawberry Boba, Normal Tapioca, Ice\nFudge Brownie")
		end)
	end)

	describe("ValidateSubmittedOrder", function()
		local bobaOrder = {
			Category = "Boba Teas",
			Item = "Custom Boba",
			CustomInfo = {
				Size = "Large",
				["Syrup Flavor"] = "Strawberry",
				["Tapioca Flavor"] = "Normal",
				Iced = true,
			},
		}
		local brownieOrder = {
			Category = "Pastries",
			Item = "Fudge Brownie",
			CustomInfo = {},
		}

		it("should validate an exact matching single order", function()
			expect(Rules.ValidateSubmittedOrder({ bobaOrder }, { bobaOrder })).to.equal(true)
		end)

		it("should validate matching orders in any permutation", function()
			expect(Rules.ValidateSubmittedOrder({ brownieOrder, bobaOrder }, { bobaOrder, brownieOrder })).to.equal(
				true
			)
		end)

		it("should reject mismatch in size", function()
			local wrongSize = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = {
					Size = "Small",
					["Syrup Flavor"] = "Strawberry",
					["Tapioca Flavor"] = "Normal",
					Iced = true,
				},
			}
			expect(Rules.ValidateSubmittedOrder({ wrongSize }, { bobaOrder })).to.equal(false)
		end)

		it("should reject mismatch in flavor", function()
			local wrongFlavor = {
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = {
					Size = "Large",
					["Syrup Flavor"] = "Taro",
					["Tapioca Flavor"] = "Normal",
					Iced = true,
				},
			}
			expect(Rules.ValidateSubmittedOrder({ wrongFlavor }, { bobaOrder })).to.equal(false)
		end)

		it("should reject mismatch in count", function()
			expect(Rules.ValidateSubmittedOrder({ bobaOrder, brownieOrder }, { bobaOrder })).to.equal(false)
			expect(Rules.ValidateSubmittedOrder({ bobaOrder }, { bobaOrder, brownieOrder })).to.equal(false)
		end)
	end)

	describe("DisplayNames", function()
		it("should return Customer with no tag for standard customers", function()
			local name, tag = Rules.DisplayNames(nil, nil)
			expect(name).to.equal("Customer")
			expect(tag).to.equal(nil)
		end)

		it("should return regular's name with Regular tag for regulars", function()
			local name, tag = Rules.DisplayNames(nil, "Mabel")
			expect(name).to.equal("Mabel")
			expect(tag).to.equal("Regular")
		end)

		it("should return Customer with VIP tag for VIP customers", function()
			local name, tag = Rules.DisplayNames("VIP", nil)
			expect(name).to.equal("Customer")
			expect(tag).to.equal("VIP")
		end)

		it("should return Karen with no tag for Karen customers", function()
			local name, tag = Rules.DisplayNames("Karen", nil)
			expect(name).to.equal("Karen")
			expect(tag).to.equal(nil)
		end)

		it("should prioritize regular name if regularName is present", function()
			local name, tag = Rules.DisplayNames("VIP", "Theo")
			expect(name).to.equal("Theo")
			expect(tag).to.equal("Regular")
		end)
	end)

	-- Counter orders and real-order tickets (DEC-059). The service methods run on a
	-- plain table standing in for `self`; players are plain tables too (no Character,
	-- so nothing here touches the world).

	local function fakeService()
		local fired = {}
		local svc = {
			_tickets = {},
			_idleSince = {},
			_counterCustomers = {},
			_counterAreas = {},
			_counterSubmitAt = {},
			_counterLockSeq = 0,
			fired = fired,
			unwatched = 0,
		}
		function svc:_fireTicket(player, ticket, slot)
			table.insert(fired, { player, ticket, slot })
		end
		function svc:_unwatchBaristaInventory()
			svc.unwatched += 1
		end
		return svc
	end

	local function fakePrompt()
		local attributes = {}
		return {
			attributes = attributes,
			SetAttribute = function(_, name, value)
				attributes[name] = value
			end,
		}
	end

	describe("CounterLock (counter customers)", function()
		local baristaA = { UserId = 1 }
		local baristaB = { UserId = 2 }

		it("should let the first barista take a free customer", function()
			expect(CounterLock.CanTake(nil, baristaA, 0)).to.equal(true)
			local lock = CounterLock.Take(baristaA, 1, 0)
			expect(CounterLock.IsHeld(lock, 1)).to.equal(true)
			expect(CounterLock.Holds(lock, baristaA, 1, 1)).to.equal(true)
		end)

		it("should refuse a second barista while the lock holds", function()
			local lock = CounterLock.Take(baristaA, 1, 0)
			expect(CounterLock.CanTake(lock, baristaB, 10)).to.equal(false)
			expect(CounterLock.CanTake(lock, baristaA, 10)).to.equal(true)
			expect(CounterLock.Holds(lock, baristaB, 1, 10)).to.equal(false)
		end)

		it("should release on timeout", function()
			local lock = CounterLock.Take(baristaA, 1, 0)
			expect(CounterLock.IsHeld(lock, CounterLock.LOCK_SECONDS - 1)).to.equal(true)
			expect(CounterLock.IsHeld(lock, CounterLock.LOCK_SECONDS + 1)).to.equal(false)
			expect(CounterLock.CanTake(lock, baristaB, CounterLock.LOCK_SECONDS + 1)).to.equal(true)
			expect(CounterLock.Holds(lock, baristaA, 1, CounterLock.LOCK_SECONDS + 1)).to.equal(false)
		end)

		it("should not honour a stale lock Id", function()
			local lock = CounterLock.Take(baristaA, 2, 0)
			expect(CounterLock.Holds(lock, baristaA, 1, 1)).to.equal(false)
		end)

		it("should only treat a lone customer with no NPC and no open order as eligible", function()
			local function noOrder()
				return false
			end
			local function hasOrder()
				return true
			end
			local p1, p2 = { UserId = 3 }, { UserId = 4 }
			expect(CounterLock.EligibleCustomer({ p1 }, false, noOrder)).to.equal(p1)
			expect(CounterLock.EligibleCustomer({ p1, p2 }, false, noOrder)).to.equal(nil)
			expect(CounterLock.EligibleCustomer({ p1 }, true, noOrder)).to.equal(nil)
			expect(CounterLock.EligibleCustomer({}, false, noOrder)).to.equal(nil)
			expect(CounterLock.EligibleCustomer({ p1 }, false, hasOrder)).to.equal(nil)
		end)

		it("should find the area box with depth slack", function()
			local cf, size = CFrame.new(0, 0, 0), Vector3.new(6, 6, 2)
			expect(CounterLock.InArea(cf, size, Vector3.new(0, 0, 2), 1.5)).to.equal(true)
			expect(CounterLock.InArea(cf, size, Vector3.new(0, 0, 3), 1.5)).to.equal(false)
			expect(CounterLock.InArea(cf, size, Vector3.new(4, 0, 0), 1.5)).to.equal(false)
		end)

		it("should match the nearest counter spot within range only", function()
			local spots = { Vector3.new(0, 0, 0), Vector3.new(20, 0, 0) }
			expect(CounterLock.MatchSpot(Vector3.new(19, 5, 1), spots, 3)).to.equal(2)
			expect(CounterLock.MatchSpot(Vector3.new(10, 0, 0), spots, 3)).to.equal(nil)
		end)
	end)

	describe("CustomerService counter lock handling", function()
		it("should clear the lock and the prompt TakerUserId on release", function()
			local svc = fakeService()
			local customer, taker = { UserId = 5 }, { UserId = 6 }
			local prompt = fakePrompt()
			svc._counterCustomers[customer] =
				{ Area = 1, Prompt = prompt, Lock = CounterLock.Take(taker, 1, os.clock()) }
			CustomerService._releaseCounterLock(svc, customer)
			expect(svc._counterCustomers[customer].Lock).to.equal(nil)
			expect(prompt.attributes.TakerUserId).to.equal(0)
		end)

		it("should ignore release for a customer who is not at a counter", function()
			local svc = fakeService()
			CustomerService._releaseCounterLock(svc, { UserId = 7 })
		end)

		it("should refuse a submit from a barista who does not hold the lock", function()
			local svc = fakeService()
			local customer, holder, other = { UserId = 8 }, { UserId = 9 }, { UserId = 10 }
			svc._counterCustomers[customer] = {
				Area = 1,
				Prompt = fakePrompt(),
				Lock = CounterLock.Take(holder, 1, os.clock()),
			}
			-- No real Player has that UserId, so the customer reads as gone.
			local result = CustomerService._submitCounterOrder(svc, other, 8, 1, {})
			expect(result.Success).to.equal(false)
		end)

		it("should refuse a submit with malformed arguments", function()
			local svc = fakeService()
			local result = CustomerService._submitCounterOrder(svc, { UserId = 11 }, "x", 1, {})
			expect(result.Success).to.equal(false)
		end)
	end)

	describe("NPC tablet notepad", function()
		local function takeOrderSetup(scriptedForUserId: number?)
			local firedPayload: any = nil
			local svc = fakeService()
			svc._context = {}
			svc._activeOrderingNpc = {}
			svc._orderTakers = {}
			svc._npcs = {}
			svc._shift = {
				IsWrappingUp = function()
					return false
				end,
			}
			function svc:_ensureClockedIn()
				return true
			end
			function svc:_hasFreeSlot()
				return true
			end
			svc._onTakeOrderTriggered = CustomerService._onTakeOrderTriggered
			svc.Client = {
				OpenOrderingTablet = {
					Fire = function(_, _, payload)
						firedPayload = payload
					end,
				},
			}
			local origin = Vector3.new(0, 0, 0)
			local player = {
				UserId = 1,
				Character = { PrimaryPart = { Position = origin } },
			}
			local npc = {
				Id = "npc-1",
				Left = false,
				State = "AtCounter",
				Root = { Position = origin },
				OrderRolled = true,
				RolledScriptedFor = scriptedForUserId,
				RequestedDrinkText = "1x Classic Milk Tea",
				Orders = { { Category = "Boba Teas", Item = "Custom Boba", CustomInfo = {} } },
				Specs = {},
			}
			function npc:ExtendRegisterPatience() end
			svc._npcs[npc] = true
			return svc, npc, player, function()
				return firedPayload
			end
		end

		it("should put a non-scripted NPC order in the notepad with no prefill", function()
			local svc, npc, player, payloadOf = takeOrderSetup(nil)
			CustomerService._onTakeOrderTriggered(svc, npc, player)
			local payload = payloadOf()
			expect(payload).to.never.equal(nil)
			expect(payload.NpcId).to.equal("npc-1")
			expect(payload.RequestedText).to.equal("1x Classic Milk Tea")
			expect(payload.Prefill).to.equal(nil)
			expect(payload.Guided).to.equal(false)
		end)

		it("should put a scripted first-session order in the notepad with no prefill", function()
			local svc, npc, player, payloadOf = takeOrderSetup(1)
			CustomerService._onTakeOrderTriggered(svc, npc, player)
			local payload = payloadOf()
			expect(payload).to.never.equal(nil)
			expect(payload.RequestedText).to.equal("1x Classic Milk Tea")
			expect(payload.Prefill).to.equal(nil)
			expect(payload.Guided).to.equal(true)
		end)
	end)

	describe("Real-order tickets", function()
		local order = {
			Id = "R-1",
			CustomerName = "Sam",
			Items = { { Category = "Drink", Item = "Coffee", CustomInfo = { Size = "Medium" } } },
		}

		it("should put a real order in the first free slot, tagged Real", function()
			local svc = fakeService()
			local barista = { UserId = 20 }
			CustomerService.IssueRealTicket(svc, barista, order)
			local ticket = svc._tickets[barista][1]
			expect(ticket.Real).to.equal(true)
			expect(ticket.Id).to.equal("R-1")
			expect(ticket.CustomerName).to.equal("Sam")
			expect(ticket.Slot).to.equal(1)
			expect(ticket.Spec.Item).to.equal("Coffee")
			expect(#svc.fired).to.equal(1)
		end)

		it("should not duplicate a ticket issued twice", function()
			local svc = fakeService()
			local barista = { UserId = 21 }
			CustomerService.IssueRealTicket(svc, barista, order)
			CustomerService.IssueRealTicket(svc, barista, order)
			expect(svc._tickets[barista][2]).to.equal(nil)
		end)

		it("should use the next slot when one is taken", function()
			local svc = fakeService()
			local barista = { UserId = 22 }
			CustomerService.IssueRealTicket(svc, barista, order)
			CustomerService.IssueRealTicket(svc, barista, { Id = "R-2", CustomerName = "Al", Items = order.Items })
			expect(svc._tickets[barista][2].Id).to.equal("R-2")
		end)

		it("should free the slot on clear and be idempotent", function()
			local svc = fakeService()
			local barista = { UserId = 23 }
			CustomerService.IssueRealTicket(svc, barista, order)
			CustomerService.ClearRealTicket(svc, barista, "R-1")
			expect(svc._tickets[barista]).to.equal(nil)
			expect(svc.unwatched).to.equal(1)
			CustomerService.ClearRealTicket(svc, barista, "R-1")
			expect(svc._idleSince[barista]).to.be.ok()
		end)
	end)

	describe("Wrong order submission rules", function()
		local function setupSubmit(servedCount, variant, isRegular)
			local closedTablets = {}
			local leftReasons = {}
			local playedAngry = 0
			local showedAngry = 0
			local reducedPatience = {}

			local model = Instance.new("Model")
			if isRegular then
				model:SetAttribute("RegularName", "Alex")
			end

			local npc = {
				Id = "npc-test",
				Left = false,
				State = "AtCounter",
				Variant = variant,
				Model = model,
				Root = { Position = Vector3.new(0, 0, 0) },
				Orders = {
					{
						Category = "Boba Teas",
						Item = "Classic Milk Tea",
						CustomInfo = { Size = "Medium" },
					},
				},
				_wrongAttempts = 0,
			}

			function npc:PlayConfused() end
			function npc:Leave(reason)
				self.Left = true
				table.insert(leftReasons, reason)
			end
			function npc:ReduceRegisterPatience(factor)
				table.insert(reducedPatience, factor)
				return 10 -- remaining
			end

			local player = {
				UserId = 42,
				Character = {
					PrimaryPart = { Position = Vector3.new(0, 0, 0) },
				},
			}

			local svc = {
				Enabled = true,
				_context = {
					ClaimPickupSpot = function()
						return Vector3.new(0, 0, 0), CFrame.new()
					end,
					ReleaseCounter = function() end,
				},
				_shift = {
					IsClockedIn = function()
						return true
					end,
					IsWrappingUp = function()
						return false
					end,
				},
				_npcs = { [npc] = true },
				_activeOrderingNpc = { [player] = npc },
				_orderTakers = { [npc] = { [player] = true } },
				_readServedCount = function()
					return servedCount
				end,
				_hasFreeSlot = function()
					return true
				end,
				_playAngrySound = function()
					playedAngry += 1
				end,
				_showAngryEffect = function()
					showedAngry += 1
				end,
				_sessionShiftOf = function()
					return nil
				end,
				_issueTicket = function() end,
				Client = {
					CloseOrderingTablet = {
						Fire = function(_, p)
							table.insert(closedTablets, p)
						end,
					},
				},
			}

			local wrongOrder = {
				{
					Category = "Boba Teas",
					Item = "Classic Milk Tea",
					CustomInfo = { Size = "Large" }, -- Wrong size!
				},
			}

			return {
				svc = svc,
				npc = npc,
				player = player,
				wrongOrder = wrongOrder,
				closedTablets = closedTablets,
				leftReasons = leftReasons,
				reducedPatience = reducedPatience,
				getPlayedAngry = function()
					return playedAngry
				end,
				getShowedAngry = function()
					return showedAngry
				end,
			}
		end

		it("should not penalize an onboarding player when order is wrong", function()
			local env = setupSubmit(0, nil, false)
			local res = CustomerService._submitNpcOrder(env.svc, env.player, env.npc.Id, env.wrongOrder)
			expect(res.Success).to.equal(false)
			expect(env.npc.Left).to.equal(false)
			expect(#env.leftReasons).to.equal(0)
			expect(#env.reducedPatience).to.equal(0)
			expect(env.getPlayedAngry()).to.equal(0)
		end)

		it("should make Karen leave immediately on 1st wrong attempt for experienced player", function()
			local env = setupSubmit(10, "Karen", false)
			local res = CustomerService._submitNpcOrder(env.svc, env.player, env.npc.Id, env.wrongOrder)
			expect(res.Success).to.equal(false)
			expect(env.npc.Left).to.equal(true)
			expect(env.leftReasons[1]).to.equal("WrongOrder")
			expect(env.getPlayedAngry()).to.equal(1)
			expect(env.getShowedAngry()).to.equal(1)
		end)

		it("should allow normal customer 1 retry with 25% patience reduction, leaving on 2nd", function()
			local env = setupSubmit(10, nil, false)
			local res1 = CustomerService._submitNpcOrder(env.svc, env.player, env.npc.Id, env.wrongOrder)
			expect(res1.Success).to.equal(false)
			expect(env.npc.Left).to.equal(false)
			expect(#env.reducedPatience).to.equal(1)
			expect(env.reducedPatience[1]).to.equal(0.25)
			expect(env.getPlayedAngry()).to.equal(1)

			local res2 = CustomerService._submitNpcOrder(env.svc, env.player, env.npc.Id, env.wrongOrder)
			expect(res2.Success).to.equal(false)
			expect(env.npc.Left).to.equal(true)
			expect(env.leftReasons[1]).to.equal("WrongOrder")
			expect(env.getPlayedAngry()).to.equal(2)
		end)

		it("should set walkout rating multiplier 1.5 when regular customer leaves on 2nd wrong attempt", function()
			local env = setupSubmit(10, nil, true)
			CustomerService._submitNpcOrder(env.svc, env.player, env.npc.Id, env.wrongOrder)
			expect(env.npc.Left).to.equal(false)
			CustomerService._submitNpcOrder(env.svc, env.player, env.npc.Id, env.wrongOrder)
			expect(env.npc.Left).to.equal(true)
			expect(env.npc._walkoutRatingMult).to.equal(1.5)
		end)

		it("should close ordering tablet when customer leaves", function()
			local closed = {}
			local fakeSvc = {
				_order = nil,
				_context = nil,
				_activeOrderingNpc = {},
				_orderTakers = {},
				_assignee = {},
				_tickets = {},
				_combo = {},
				RecordTeamServe = function() end,
				_clearTicket = function() end,
				CustomerResolved = {
					Fire = function() end,
				},
				Client = {
					CloseOrderingTablet = {
						Fire = function(_, p)
							table.insert(closed, p)
						end,
					},
				},
			}
			local player = { UserId = 99 }
			local npc = { Id = "test-npc" }
			fakeSvc._activeOrderingNpc[player] = npc
			fakeSvc._orderTakers[npc] = { [player] = true }

			CustomerService._onCustomerLeft(fakeSvc, npc, "WrongOrder")
			expect(#closed >= 1).to.equal(true)
			expect(closed[1]).to.equal(player)
			expect(fakeSvc._activeOrderingNpc[player]).to.equal(nil)
		end)
	end)
end

-- selene: allow(undefined_variable)
--[[
	OrderSpec.spec.luau
	TestEZ tests for OrderSpec: Match, PickTools, FromMenuItem, FromOrderItem, and
	the recipe card functions Steps and StepState.

	Testing strategy
	────────────────
	Match and PickTools are pure: specs and tool attributes are plain tables, so no
	Instances are needed. FromMenuItem / FromOrderItem read the real Menu (it reads
	the authored SelectorModels, as OrderService.spec does), so those cases also
	cover the Menu's ServeItem data. If the Menu cannot load, only the Menu-backed
	cases fail.

	Cases 1-23 are the 23 cases of REVIVAL-001 M1.1 section 4 (case numbers are in
	the test names). The "FromOrderItem" block and the cases marked "extra" cover
	REVIVAL-001 M1.3b and edge rules not in that table. The "Steps" and "StepState"
	blocks cover REVIVAL-001 M1.5a (design 3.8). StepState is table driven: a list of
	held-tool snapshots per item, each with the expected current row and problem.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local OrderSpec = require(ReplicatedStorage.Shared.Ordering.OrderSpec)
	local menuLoaded, Menu = pcall(require, ReplicatedStorage.Shared.Ordering.Menu)

	-- ──────────────────────────────────────────────────────────────────────
	-- Fixtures (functions, so a test can change a copy freely)
	-- ──────────────────────────────────────────────────────────────────────

	local SPEC_FIELDS = { "Kind", "Item", "Size", "Syrup", "Tapioca", "Iced", "Sugar", "Label" }

	local function with(base: { [string]: any }, changes: { [string]: any }): { [string]: any }
		local copy = table.clone(base)
		for key, value in changes do
			copy[key] = value
		end
		return copy
	end

	-- Spec A: Medium Custom Boba, Classic Milk Tea syrup, Normal tapioca.
	local function specA()
		return {
			Kind = "Drink",
			Item = "Boba",
			Size = "Medium",
			Syrup = "Classic Milk Tea",
			Tapioca = "Normal",
			Label = "Medium Custom Boba",
		}
	end

	-- Spec B: Small Regular coffee, no ice, no sugar.
	local function specB()
		return { Kind = "Drink", Item = "Regular", Size = "Small", Iced = false, Sugar = false, Label = "Small Regular" }
	end

	-- Spec C: a grab item.
	local function specC()
		return { Kind = "Grab", Item = "Fudge Brownie", Label = "Fudge Brownie" }
	end

	-- Spec D: a mug drink.
	local function specD()
		return { Kind = "Drink", Item = "Caramel Hot Chocolate", Size = "Mug", Label = "Mug Caramel Hot Chocolate" }
	end

	-- Spec B2: Small Regular coffee with ice and sugar.
	local function specB2()
		return with(specB(), { Iced = true, Sugar = true, Label = "Small Regular" })
	end

	-- Spec B1: Small Regular coffee with sugar, no ice.
	local function specB1()
		return with(specB(), { Sugar = true })
	end

	-- Spec E: Vanilla Ice Cream, a grab item from the Ice Cream Freezer.
	local function specE()
		return { Kind = "Grab", Item = "Vanilla Ice Cream", Label = "Vanilla Ice Cream" }
	end

	-- Spec F: a tea. Teas and water have no card chain yet (PENDING JACK: Q22).
	local function specF()
		return { Kind = "Drink", Item = "Green Tea", Size = "Small", Iced = false, Label = "Small Green Tea" }
	end

	-- The attributes a correctly made spec A tool carries.
	local function attrsA()
		return { Item = "Boba", Size = "Medium", Syrup = "Classic Milk Tea", Tapioca = "Normal" }
	end

	local function menuDef(category: string, item: string)
		assert(menuLoaded, "Shared.Ordering.Menu failed to load: " .. tostring(Menu))
		local def = Menu.FoodTable[category].Items[item]
		assert(def, "Menu has no " .. category .. " > " .. item)
		return def
	end

	-- ──────────────────────────────────────────────────────────────────────
	-- Assertion helpers
	-- ──────────────────────────────────────────────────────────────────────

	local function expectList(actual: { any }, expected: { any })
		expect(#actual).to.equal(#expected)
		for i, value in expected do
			expect(actual[i]).to.equal(value)
		end
	end

	local function expectMatch(spec, attrs, grade: string, reasons: { string })
		local actualGrade, actualReasons = OrderSpec.Match(spec, attrs)
		expect(actualGrade).to.equal(grade)
		expectList(actualReasons, reasons)
	end

	-- OrderSpec has no Instances, so equality is field by field.
	local function expectSpec(actual, expected)
		expect(actual).to.be.ok()
		for _, field in SPEC_FIELDS do
			expect(actual[field]).to.equal(expected[field])
		end
	end

	local function expectFailure(spec, reason, expectedReason: string)
		expect(spec).to.equal(nil)
		expect(reason).to.equal(expectedReason)
	end

	-- ══════════════════════════════════════════════════════════════════════
	-- Match
	-- ══════════════════════════════════════════════════════════════════════

	describe("Match", function()
		describe("spec A (Medium Custom Boba, Classic Milk Tea, Normal)", function()
			it("case 1: the exact attributes, plus Lid, are Perfect", function()
				expectMatch(specA(), with(attrsA(), { Lid = true }), "Perfect", {})
			end)

			it("case 2: the wrong size is Close", function()
				expectMatch(specA(), with(attrsA(), { Size = "Large" }), "Close", { "Size" })
			end)

			it("case 3: the wrong tapioca is Close", function()
				expectMatch(specA(), with(attrsA(), { Tapioca = "Strawberry" }), "Close", { "Tapioca" })
			end)

			it("case 4: the wrong syrup is Wrong", function()
				expectMatch(specA(), with(attrsA(), { Syrup = "Taro" }), "Wrong", { "Syrup" })
			end)

			it("case 5: the wrong size and tapioca together are Wrong, with both reasons in order", function()
				expectMatch(
					specA(),
					with(attrsA(), { Size = "Large", Tapioca = "Strawberry" }),
					"Wrong",
					{ "Size", "Tapioca" }
				)
			end)

			it("case 6: another item is Wrong", function()
				expectMatch(
					specA(),
					{ Item = "Flavored Milk", Size = "Medium", Syrup = "Classic Milk Tea" },
					"Wrong",
					{ "Item" }
				)
			end)

			it("extra: the wrong syrup is reported before any minor mistake", function()
				expectMatch(specA(), with(attrsA(), { Syrup = "Taro", Size = "Large" }), "Wrong", { "Syrup" })
			end)

			it("extra: a missing attribute counts as a mistake", function()
				local attrs = attrsA()
				attrs.Tapioca = nil
				expectMatch(specA(), attrs, "Close", { "Tapioca" })
			end)
		end)

		describe("spec B (Small Regular, no ice, no sugar)", function()
			it("case 7: no Iced or Sugar attribute counts as false, so it is Perfect", function()
				expectMatch(specB(), { Item = "Regular", Size = "Small" }, "Perfect", {})
			end)

			it("case 8: an extra Iced is Close", function()
				expectMatch(specB(), { Item = "Regular", Size = "Small", Iced = true }, "Close", { "Iced" })
			end)

			it("case 9: an extra Iced and Sugar are Wrong, with both reasons in order", function()
				expectMatch(
					specB(),
					{ Item = "Regular", Size = "Small", Iced = true, Sugar = true },
					"Wrong",
					{ "Iced", "Sugar" }
				)
			end)

			it("case 10: another coffee is Wrong", function()
				expectMatch(specB(), { Item = "Decaf", Size = "Small" }, "Wrong", { "Item" })
			end)

			it("case 11: an iced spec matches an iced tool", function()
				expectMatch(
					with(specB(), { Iced = true }),
					{ Item = "Regular", Size = "Small", Iced = true },
					"Perfect",
					{}
				)
			end)

			it("extra: an iced spec with a tool that has no Iced attribute is Close", function()
				expectMatch(with(specB(), { Iced = true }), { Item = "Regular", Size = "Small" }, "Close", { "Iced" })
			end)

			it("extra: a missing Sugar attribute against a sugar spec is Close", function()
				expectMatch(with(specB(), { Sugar = true }), { Item = "Regular", Size = "Small" }, "Close", { "Sugar" })
			end)
		end)

		describe("spec C (Fudge Brownie, a grab item)", function()
			it("case 12: extra attributes are ignored", function()
				expectMatch(specC(), { Item = "Fudge Brownie", Sugar = true }, "Perfect", {})
			end)

			it("case 13: a tool with no attributes is Wrong", function()
				expectMatch(specC(), {}, "Wrong", { "Item" })
			end)
		end)

		describe("spec D (Caramel Hot Chocolate, Mug)", function()
			it("case 14: the exact attributes are Perfect", function()
				expectMatch(specD(), { Item = "Caramel Hot Chocolate", Size = "Mug" }, "Perfect", {})
			end)

			it("case 15: another item with the same size is Wrong", function()
				expectMatch(specD(), { Item = "Milk", Size = "Mug" }, "Wrong", { "Item" })
			end)
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- PickTools
	-- ══════════════════════════════════════════════════════════════════════

	describe("PickTools", function()
		it("case 16: Perfect picks come first, then Close picks fill the rest", function()
			local picks, grade, reasons = OrderSpec.PickTools({ with(specB(), { Size = "Medium" }), specB() }, {
				{ Item = "Regular", Size = "Small" },
				{ Item = "Regular", Size = "Large" },
			})
			expect(picks).to.be.ok()
			expectList(picks, { 2, 1 })
			expect(grade).to.equal("Close")
			expectList(reasons, {})
		end)

		it("case 17: a Perfect tool is found past a tool of another item", function()
			local picks, grade, reasons = OrderSpec.PickTools({ specA() }, {
				{ Item = "Regular", Size = "Small" },
				attrsA(),
			})
			expect(picks).to.be.ok()
			expectList(picks, { 2 })
			expect(grade).to.equal("Perfect")
			expectList(reasons, {})
		end)

		it("case 18: one tool cannot fill two specs", function()
			local picks, grade, reasons = OrderSpec.PickTools({ specC(), specC() }, {
				{ Item = "Fudge Brownie" },
			})
			expect(picks).to.equal(nil)
			expect(grade).to.equal("Wrong")
			expectList(reasons, { "Missing" })
		end)

		it("extra: every spec Perfect gives Perfect, and picks are in spec order", function()
			local picks, grade = OrderSpec.PickTools({ specC(), specA() }, {
				attrsA(),
				{ Item = "Fudge Brownie" },
			})
			expectList(picks, { 2, 1 })
			expect(grade).to.equal("Perfect")
		end)

		it("extra: with one spec and no match, reasons come from the first candidate", function()
			local picks, grade, reasons = OrderSpec.PickTools({ specA() }, {
				with(attrsA(), { Syrup = "Taro" }),
				{ Item = "Regular", Size = "Small" },
			})
			expect(picks).to.equal(nil)
			expect(grade).to.equal("Wrong")
			expectList(reasons, { "Syrup" })
		end)

		it("extra: with one spec and no candidates, the reason is Missing", function()
			local picks, grade, reasons = OrderSpec.PickTools({ specA() }, {})
			expect(picks).to.equal(nil)
			expect(grade).to.equal("Wrong")
			expectList(reasons, { "Missing" })
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- FromMenuItem
	-- ══════════════════════════════════════════════════════════════════════

	describe("FromMenuItem", function()
		it("case 19: Custom Boba with Medium / Classic Milk Tea / Normal equals spec A", function()
			local spec, reason = OrderSpec.FromMenuItem(menuDef("Boba Teas", "Custom Boba"), {
				Size = "Medium",
				["Syrup Flavor"] = "Classic Milk Tea",
				["Tapioca Flavor"] = "Normal",
			})
			expect(reason).to.equal(nil)
			expectSpec(spec, specA())
		end)

		it("case 20: Custom Boba without a Tapioca Flavor fails on Tapioca Flavor", function()
			local spec, reason = OrderSpec.FromMenuItem(menuDef("Boba Teas", "Custom Boba"), {
				Size = "Medium",
				["Syrup Flavor"] = "Classic Milk Tea",
			})
			expectFailure(spec, reason, "Tapioca Flavor")
		end)

		it("case 21: a Coffee with Size Huge fails on Size", function()
			local spec, reason = OrderSpec.FromMenuItem(menuDef("Coffees", "Regular"), { Size = "Huge" })
			expectFailure(spec, reason, "Size")
		end)

		it("case 22: Water reads its ice choice from Ice", function()
			local spec, reason = OrderSpec.FromMenuItem(menuDef("Others", "Water"), { Size = "Small", Ice = true })
			expect(reason).to.equal(nil)
			expect(spec).to.be.ok()
			expect(spec.Iced).to.equal(true)
		end)

		it("case 23: Orange Cream Mochi is a Grab served as Orange Mochi", function()
			local spec, reason = OrderSpec.FromMenuItem(menuDef("Mochis", "Orange Cream"), {})
			expect(reason).to.equal(nil)
			expect(spec).to.be.ok()
			expect(spec.Kind).to.equal("Grab")
			expect(spec.Item).to.equal("Orange Mochi")
		end)

		it("extra: a Coffee without Iced or Sugar choices takes the Menu defaults", function()
			local spec, reason = OrderSpec.FromMenuItem(menuDef("Coffees", "Regular"), { Size = "Small" })
			expect(reason).to.equal(nil)
			expectSpec(spec, specB())
		end)

		it("extra: a Coffee with Iced and Sugar chosen keeps both", function()
			local spec =
				OrderSpec.FromMenuItem(menuDef("Coffees", "Regular"), { Size = "Small", Iced = true, Sugar = true })
			expect(spec).to.be.ok()
			expect(spec.Iced).to.equal(true)
			expect(spec.Sugar).to.equal(true)
		end)

		it("extra: a non-boolean Iced fails on Iced", function()
			local spec, reason = OrderSpec.FromMenuItem(menuDef("Coffees", "Regular"), { Size = "Small", Iced = "yes" })
			expectFailure(spec, reason, "Iced")
		end)

		it("extra: a non-boolean Sugar fails on Sugar", function()
			local spec, reason = OrderSpec.FromMenuItem(menuDef("Coffees", "Regular"), { Size = "Small", Sugar = 1 })
			expectFailure(spec, reason, "Sugar")
		end)

		it("extra: an item with no ice or sugar option leaves Iced and Sugar nil", function()
			local spec = OrderSpec.FromMenuItem(menuDef("Hot Cocoas", "Caramel"), { Size = "Mug" })
			expect(spec).to.be.ok()
			expect(spec.Iced).to.equal(nil)
			expect(spec.Sugar).to.equal(nil)
		end)

		it("extra: a Hot Cocoa spec has the Mug size and the full item name", function()
			local spec, reason = OrderSpec.FromMenuItem(menuDef("Hot Cocoas", "Caramel"), { Size = "Mug" })
			expect(reason).to.equal(nil)
			expectSpec(spec, specD())
		end)

		it("extra: a syrup that is not on the Menu fails on Syrup Flavor", function()
			local spec, reason = OrderSpec.FromMenuItem(menuDef("Boba Teas", "Custom Boba"), {
				Size = "Medium",
				["Syrup Flavor"] = "Not A Syrup",
				["Tapioca Flavor"] = "Normal",
			})
			expectFailure(spec, reason, "Syrup Flavor")
		end)

		it("extra: a non-string Size fails on Size", function()
			local spec, reason = OrderSpec.FromMenuItem(menuDef("Coffees", "Regular"), { Size = 2 })
			expectFailure(spec, reason, "Size")
		end)

		it("extra: a non-table definition or CustomInfo fails", function()
			local spec, reason = OrderSpec.FromMenuItem(nil :: any, {})
			expectFailure(spec, reason, "Item")
			spec, reason = OrderSpec.FromMenuItem(menuDef("Pastries", "Fudge Brownie"), nil :: any)
			expectFailure(spec, reason, "CustomInfo")
		end)

		it("extra: Matcha Tea Boba is served as Boba with the Matcha syrup", function()
			local spec = OrderSpec.FromMenuItem(menuDef("Boba Teas", "Matcha Tea Boba"), {
				Size = "Small",
				["Syrup Flavor"] = "Matcha",
				["Tapioca Flavor"] = "Normal",
			})
			expect(spec).to.be.ok()
			expect(spec.Item).to.equal("Boba")
			expect(spec.Syrup).to.equal("Matcha")
			expect(spec.Label).to.equal("Small Matcha Tea Boba")
		end)

		it("extra: the Cup is served as Clear Cup", function()
			local spec = OrderSpec.FromMenuItem(menuDef("Others", "Cup"), { Size = "Large" })
			expect(spec).to.be.ok()
			expect(spec.Item).to.equal("Clear Cup")
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- FromOrderItem (M1.3b: Category on order items, ServeItem on the Menu)
	-- ══════════════════════════════════════════════════════════════════════

	describe("FromOrderItem", function()
		it("slice item: Classic Milk Tea Boba resolves to spec A", function()
			local spec, reason = OrderSpec.FromOrderItem({
				Category = "Boba Teas",
				Item = "Custom Boba",
				CustomInfo = {
					Size = "Medium",
					["Syrup Flavor"] = "Classic Milk Tea",
					["Tapioca Flavor"] = "Normal",
				},
			})
			expect(reason).to.equal(nil)
			expectSpec(spec, specA())
		end)

		it("slice item: Regular Coffee resolves to spec B", function()
			local spec, reason = OrderSpec.FromOrderItem({
				Category = "Coffees",
				Item = "Regular",
				CustomInfo = { Size = "Small" },
			})
			expect(reason).to.equal(nil)
			expectSpec(spec, specB())
		end)

		it("slice item: Fudge Brownie resolves to spec C", function()
			local spec, reason = OrderSpec.FromOrderItem({
				Category = "Pastries",
				Item = "Fudge Brownie",
				CustomInfo = {},
			})
			expect(reason).to.equal(nil)
			expectSpec(spec, specC())
		end)

		it("a MobileOrder order item resolves, and its DefaultInfo is ignored", function()
			-- Shape built by MobileOrder.onAddItem: Menu defaults for Select and Options, then the
			-- required choices. DefaultInfo is forged here to prove the server's Menu is used.
			local spec, reason = OrderSpec.FromOrderItem({
				Category = "Coffees",
				Item = "Espresso",
				DefaultInfo = { ItemName = "Forged", ServeItem = "Forged", Select = { Size = { "Small" } } },
				CustomInfo = { Size = "Small", Iced = false, Sugar = false },
			} :: any)
			expect(reason).to.equal(nil)
			expectSpec(spec, with(specB(), { Item = "Espresso", Label = "Small Espresso" }))
		end)

		it("a missing CustomInfo counts as empty", function()
			local spec, reason = OrderSpec.FromOrderItem({ Category = "Pastries", Item = "Fudge Brownie" } :: any)
			expect(reason).to.equal(nil)
			expectSpec(spec, specC())
		end)

		it("an item with no Category fails on Category", function()
			local spec, reason = OrderSpec.FromOrderItem({ Item = "Regular", CustomInfo = { Size = "Small" } } :: any)
			expectFailure(spec, reason, "Category")
		end)

		it("an unknown Category fails on Category", function()
			local spec, reason = OrderSpec.FromOrderItem({ Category = "Nope", Item = "Regular", CustomInfo = {} })
			expectFailure(spec, reason, "Category")
		end)

		it("an unknown Item in a known Category fails on Item", function()
			local spec, reason = OrderSpec.FromOrderItem({ Category = "Coffees", Item = "Nope", CustomInfo = {} })
			expectFailure(spec, reason, "Item")
		end)

		it("an Item from another Category fails on Item", function()
			-- "Regular" is a Coffee; a Category is needed to resolve it.
			local spec, reason = OrderSpec.FromOrderItem({ Category = "Pastries", Item = "Regular", CustomInfo = {} })
			expectFailure(spec, reason, "Item")
		end)

		it("a non-table CustomInfo fails on CustomInfo", function()
			local spec, reason = OrderSpec.FromOrderItem({
				Category = "Coffees",
				Item = "Regular",
				CustomInfo = "Small",
			} :: any)
			expectFailure(spec, reason, "CustomInfo")
		end)

		it("a non-table order item fails", function()
			local spec, reason = OrderSpec.FromOrderItem("Regular" :: any)
			expectFailure(spec, reason, "Item")
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- Steps and StepState (M1.5a, design 3.8)
	-- ══════════════════════════════════════════════════════════════════════

	-- rows = { { Station, Choice?, Label } } in card order.
	local function expectSteps(spec, rows: { { [string]: any } })
		local steps = OrderSpec.Steps(spec)
		expect(#steps).to.equal(#rows)
		for index, row in rows do
			expect(steps[index].Station).to.equal(row.Station)
			expect(steps[index].Choice).to.equal(row.Choice)
			expect(steps[index].Label).to.equal(row.Label)
			expect(steps[index].Optional).to.equal(nil)
		end
	end

	-- problem = nil, or { Step, Severity, Reason, Reasons? } (Reasons defaults to { Reason }).
	local function expectState(spec, attrs, current: number, problem: { [string]: any }?)
		local actualCurrent, actualProblem = OrderSpec.StepState(spec, attrs)
		expect(actualCurrent).to.equal(current)
		if problem == nil then
			expect(actualProblem).to.equal(nil)
			return
		end
		expect(actualProblem).to.be.ok()
		expect(actualProblem.Step).to.equal(problem.Step)
		expect(actualProblem.Severity).to.equal(problem.Severity)
		expect(actualProblem.Reason).to.equal(problem.Reason)
		expectList(actualProblem.Reasons, problem.Reasons or { problem.Reason })
	end

	-- Runs one test per case: { name, attrs, current, problem? }.
	local function stateCases(label: string, makeSpec, cases: { { any } })
		describe(label, function()
			for _, case in cases do
				it(case[1], function()
					expectState(makeSpec(), case[2], case[3], case[4])
				end)
			end
		end)
	end

	describe("Steps", function()
		it("spec A (boba): Clear Cup, Milk, syrup, tapioca, no Blender (PENDING JACK: Q3)", function()
			expectSteps(specA(), {
				{ Station = "Clear Cup", Choice = "Medium", Label = "Medium Clear Cup" },
				{ Station = "Milk", Label = "Milk" },
				{ Station = "Classic Milk Tea Syrup", Label = "Classic Milk Tea Syrup" },
				{ Station = "Normal Tapioca", Label = "Normal Tapioca" },
			})
		end)

		it("spec B (coffee with no ice or sugar): Cup with the size, Coffee Machine with the coffee", function()
			expectSteps(specB(), {
				{ Station = "Cup", Choice = "Small", Label = "Small Cup" },
				{ Station = "Coffee Machine", Choice = "Regular", Label = "Regular" },
			})
		end)

		it("spec B2 (coffee with ice and sugar): adds Ice Machine then Sugar, ice first", function()
			expectSteps(specB2(), {
				{ Station = "Cup", Choice = "Small", Label = "Small Cup" },
				{ Station = "Coffee Machine", Choice = "Regular", Label = "Regular" },
				{ Station = "Ice Machine", Label = "Ice" },
				{ Station = "Sugar", Label = "Sugar" },
			})
		end)

		it("a coffee that wants only sugar skips the Ice Machine", function()
			local steps = OrderSpec.Steps(with(specB(), { Sugar = true }))
			expect(#steps).to.equal(3)
			expect(steps[3].Station).to.equal("Sugar")
		end)

		it("spec C (a pastry): one Food Display step, picking the item", function()
			expectSteps(specC(), { { Station = "Food Display", Choice = "Fudge Brownie", Label = "Fudge Brownie" } })
		end)

		it("spec E (ice cream): one Ice Cream Freezer step, picking the item", function()
			expectSteps(
				specE(),
				{ { Station = "Ice Cream Freezer", Choice = "Vanilla Ice Cream", Label = "Vanilla Ice Cream" } }
			)
		end)

		it("spec D (hot cocoa): Mug, Milk, then the flavour's powder station", function()
			expectSteps(specD(), {
				{ Station = "Mug", Label = "Mug" },
				{ Station = "Milk", Label = "Steamed Milk" },
				{ Station = "Caramel Hot Chocolate Powder", Label = "Caramel Hot Chocolate Powder" },
			})
		end)

		it("plain Hot Chocolate uses the Hot Chocolate Powder station", function()
			local steps = OrderSpec.Steps(with(specD(), { Item = "Hot Chocolate" }))
			expect(steps[3].Station).to.equal("Hot Chocolate Powder")
		end)

		it("items with no chain have no steps: a tea, a smoothie, a bare Clear Cup, malformed specs", function()
			expectSteps(specF(), {})
			expectSteps({ Kind = "Drink", Item = "Kiwi Smoothie", Size = "Small", Label = "Small Kiwi Smoothie" }, {})
			expectSteps({ Kind = "Drink", Item = "Clear Cup", Size = "Large", Label = "Large Cup" }, {})
			expectSteps({ Kind = "Drink", Label = "No item" } :: any, {})
			expectSteps(nil :: any, {})
		end)

		it("returns a fresh table on every call", function()
			local first = OrderSpec.Steps(specA())
			first[1].Station = "Changed"
			table.remove(first, 2)
			expectSteps(specA(), {
				{ Station = "Clear Cup", Choice = "Medium", Label = "Medium Clear Cup" },
				{ Station = "Milk", Label = "Milk" },
				{ Station = "Classic Milk Tea Syrup", Label = "Classic Milk Tea Syrup" },
				{ Station = "Normal Tapioca", Label = "Normal Tapioca" },
			})
		end)
	end)

	describe("StepState", function()
		-- Spec A (boba): rows 1 Clear Cup, 2 Milk, 3 Syrup, 4 Tapioca; 5 = ready to serve.
		stateCases("spec A: each step advances", specA, {
			{ "holding nothing is row 1", nil, 1 },
			{ "an empty attribute table is row 1", {}, 1 },
			{ "a Clear Cup with no size yet is still row 1", { Item = "Clear Cup" }, 1 },
			{ "a Medium Clear Cup is row 2", { Item = "Clear Cup", Size = "Medium" }, 2 },
			{ "Milk is row 3", { Item = "Milk", Size = "Medium" }, 3 },
			{
				"Classic Milk Tea syrup is row 4",
				{ Item = "Flavored Milk", Size = "Medium", Syrup = "Classic Milk Tea" },
				4,
			},
			{ "Normal tapioca is row 5, ready to serve", attrsA(), 5 },
			{ "a Lid and other extra attributes change nothing", with(attrsA(), { Lid = true, Blended = true }), 5 },
		})

		stateCases("spec A: mistakes", specA, {
			{
				"a wrong syrup at step 3 is Wrong the moment it goes in",
				{ Item = "Flavored Milk", Size = "Medium", Syrup = "Taro" },
				4,
				{ Step = 3, Severity = "Wrong", Reason = "Syrup" },
			},
			{
				"a wrong size is Close, shown on the cup row",
				{ Item = "Clear Cup", Size = "Large" },
				2,
				{ Step = 1, Severity = "Close", Reason = "Size" },
			},
			{
				"a wrong tapioca is Close, shown on the tapioca row",
				with(attrsA(), { Tapioca = "Strawberry" }),
				5,
				{ Step = 4, Severity = "Close", Reason = "Tapioca" },
			},
			{
				"a wrong size and tapioca together are Wrong, first reason Size",
				with(attrsA(), { Size = "Large", Tapioca = "Strawberry" }),
				5,
				{ Step = 1, Severity = "Wrong", Reason = "Size", Reasons = { "Size", "Tapioca" } },
			},
			{
				"a wrong syrup wins over a wrong size",
				with(attrsA(), { Syrup = "Taro", Size = "Large" }),
				5,
				{ Step = 3, Severity = "Wrong", Reason = "Syrup" },
			},
			{
				"a coffee in hand is a Wrong Item on row 1",
				{ Item = "Regular", Size = "Medium" },
				1,
				{ Step = 1, Severity = "Wrong", Reason = "Item" },
			},
			{
				"a Cup instead of a Clear Cup is a Wrong Item on row 1",
				{ Item = "Cup", Size = "Medium" },
				1,
				{ Step = 1, Severity = "Wrong", Reason = "Item" },
			},
			{
				"a pastry in hand is a Wrong Item on row 1",
				{ Item = "Fudge Brownie" },
				1,
				{ Step = 1, Severity = "Wrong", Reason = "Item" },
			},
		})

		-- Spec B (coffee): rows 1 Cup, 2 Coffee Machine; 3 = ready to serve.
		stateCases("spec B: each step advances", specB, {
			{ "holding nothing is row 1", nil, 1 },
			{ "a Small Cup is row 2", { Item = "Cup", Size = "Small" }, 2 },
			{ "a Small Regular is row 3, ready to serve", { Item = "Regular", Size = "Small" }, 3 },
		})

		stateCases("spec B: mistakes", specB, {
			{
				"a Medium Cup is Close on row 1",
				{ Item = "Cup", Size = "Medium" },
				2,
				{ Step = 1, Severity = "Close", Reason = "Size" },
			},
			{
				"the wrong coffee is a Wrong Item on the Coffee Machine row",
				{ Item = "Decaf", Size = "Small" },
				2,
				{ Step = 2, Severity = "Wrong", Reason = "Item" },
			},
			{
				"ice nobody asked for is Close, with no row to show it on",
				{ Item = "Regular", Size = "Small", Iced = true },
				3,
				{ Step = nil, Severity = "Close", Reason = "Iced" },
			},
			{
				"sugar nobody asked for is Close, with no row to show it on",
				{ Item = "Regular", Size = "Small", Sugar = true },
				3,
				{ Step = nil, Severity = "Close", Reason = "Sugar" },
			},
			{
				"unwanted ice and sugar together are Wrong",
				{ Item = "Regular", Size = "Small", Iced = true, Sugar = true },
				3,
				{ Step = nil, Severity = "Wrong", Reason = "Iced", Reasons = { "Iced", "Sugar" } },
			},
			{
				"a Clear Cup is a Wrong Item on the Coffee Machine row",
				{ Item = "Clear Cup", Size = "Small" },
				2,
				{ Step = 2, Severity = "Wrong", Reason = "Item" },
			},
		})

		-- Spec B2 (coffee with ice and sugar): rows 1 Cup, 2 Coffee, 3 Ice, 4 Sugar; 5 = ready.
		stateCases("spec B2: ice then sugar", specB2, {
			{ "a Small Regular still needs ice", { Item = "Regular", Size = "Small" }, 3 },
			{ "iced is row 4", { Item = "Regular", Size = "Small", Iced = true }, 4 },
			{
				"iced and sugared is row 5, ready to serve",
				{ Item = "Regular", Size = "Small", Iced = true, Sugar = true },
				5,
			},
			{
				"sugar before ice is allowed; ice is still current",
				{ Item = "Regular", Size = "Small", Sugar = true },
				3,
			},
			{ "sugar on a bare cup leaves the coffee current", { Item = "Cup", Size = "Small", Sugar = true }, 2 },
		})

		-- Spec B1 (coffee with sugar, no ice): rows 1 Cup, 2 Coffee, 3 Sugar; 4 = ready.
		stateCases("spec B1: sugar without ice", specB1, {
			{
				"ice before sugar is allowed; sugar is still current",
				{ Item = "Regular", Size = "Small", Iced = true },
				3,
				{ Step = nil, Severity = "Close", Reason = "Iced" },
			},
		})

		-- Spec C (a grab item): row 1 Food Display; 2 = ready to serve.
		stateCases("spec C: a grab item", specC, {
			{ "holding nothing is row 1", nil, 1 },
			{ "the Fudge Brownie is row 2, ready to serve", { Item = "Fudge Brownie" }, 2 },
			{ "a size attribute on a grab item is ignored", { Item = "Fudge Brownie", Size = "Large" }, 2 },
			{
				"another pastry is a Wrong Item on row 1",
				{ Item = "Vanilla Macaron" },
				1,
				{ Step = 1, Severity = "Wrong", Reason = "Item" },
			},
			{
				"a boba in hand is a Wrong Item on row 1",
				attrsA(),
				1,
				{ Step = 1, Severity = "Wrong", Reason = "Item" },
			},
		})

		-- Spec D (hot cocoa): rows 1 Mug, 2 Milk, 3 Powder; 4 = ready to serve.
		stateCases("spec D: hot cocoa", specD, {
			{ "holding nothing is row 1", nil, 1 },
			{ "a Mug is row 2", { Item = "Mug", Size = "Mug" }, 2 },
			{ "steamed milk is row 3", { Item = "Milk", Size = "Mug" }, 3 },
			{ "Caramel Hot Chocolate is row 4, ready to serve", { Item = "Caramel Hot Chocolate", Size = "Mug" }, 4 },
			{
				"a cup is a Wrong Item on row 1",
				{ Item = "Clear Cup", Size = "Small" },
				1,
				{ Step = 1, Severity = "Wrong", Reason = "Item" },
			},
		})

		stateCases("spec F: a tea has no chain", specF, {
			{ "holding nothing is row 1, no problem", nil, 1 },
			{ "any held tool is row 1, no problem", { Item = "Green Tea", Size = "Large" }, 1 },
		})

		it("a non-table attribute value is treated as nothing held", function()
			expectState(specA(), "Boba" :: any, 1, nil)
		end)

		it("a malformed spec is row 1 with no problem", function()
			expectState(nil :: any, attrsA(), 1, nil)
		end)

		-- The card and the serve must agree (design 3.8): a finished tool's problem
		-- Severity equals the grade Match gives it, and a clean tool has no problem.
		describe("agreement with Match", function()
			local function expectAgrees(spec, attrs)
				local grade = OrderSpec.Match(spec, attrs)
				local _, problem = OrderSpec.StepState(spec, attrs)
				if grade == "Perfect" then
					expect(problem).to.equal(nil)
				else
					expect(problem).to.be.ok()
					expect(problem.Severity).to.equal(grade)
				end
			end

			it("spec A finished tools", function()
				expectAgrees(specA(), attrsA())
				expectAgrees(specA(), with(attrsA(), { Size = "Large" }))
				expectAgrees(specA(), with(attrsA(), { Tapioca = "Strawberry" }))
				expectAgrees(specA(), with(attrsA(), { Syrup = "Taro" }))
				expectAgrees(specA(), with(attrsA(), { Size = "Large", Tapioca = "Strawberry" }))
				expectAgrees(specA(), { Item = "Fudge Brownie" })
			end)

			it("spec B finished tools", function()
				local made = { Item = "Regular", Size = "Small" }
				expectAgrees(specB(), made)
				expectAgrees(specB(), with(made, { Size = "Large" }))
				expectAgrees(specB(), with(made, { Iced = true }))
				expectAgrees(specB(), with(made, { Iced = true, Sugar = true }))
				expectAgrees(specB2(), with(made, { Iced = true, Sugar = true }))
				expectAgrees(specB(), { Item = "Decaf", Size = "Small" })
			end)

			it("spec C and D finished tools", function()
				expectAgrees(specC(), { Item = "Fudge Brownie" })
				expectAgrees(specC(), { Item = "Vanilla Macaron" })
				expectAgrees(specD(), { Item = "Caramel Hot Chocolate", Size = "Mug" })
				expectAgrees(specD(), { Item = "Vanilla Hot Chocolate", Size = "Mug" })
			end)
		end)
	end)

	describe("Steps and StepState with the real Menu", function()
		local function menuSpec(category: string, item: string, customInfo: { [string]: any }?)
			assert(menuLoaded, "Shared.Ordering.Menu failed to load: " .. tostring(Menu))
			local spec, reason = OrderSpec.FromOrderItem({ Category = category, Item = item, CustomInfo = customInfo })
			assert(spec, "FromOrderItem failed on " .. tostring(reason))
			return spec
		end

		it("slice item: Classic Milk Tea Boba has 4 steps", function()
			local spec = menuSpec("Boba Teas", "Custom Boba", {
				Size = "Medium",
				["Syrup Flavor"] = "Classic Milk Tea",
				["Tapioca Flavor"] = "Normal",
			})
			local steps = OrderSpec.Steps(spec)
			expect(#steps).to.equal(4)
			expect(steps[3].Station).to.equal("Classic Milk Tea Syrup")
			expect(OrderSpec.StepState(spec, attrsA())).to.equal(5)
		end)

		it("slice item: Regular Coffee has 2 steps", function()
			local spec = menuSpec("Coffees", "Regular", { Size = "Small" })
			expect(#OrderSpec.Steps(spec)).to.equal(2)
			expect(OrderSpec.StepState(spec, { Item = "Regular", Size = "Small" })).to.equal(3)
		end)

		it("slice item: Fudge Brownie has 1 step", function()
			local spec = menuSpec("Pastries", "Fudge Brownie")
			local steps = OrderSpec.Steps(spec)
			expect(#steps).to.equal(1)
			expect(steps[1].Station).to.equal("Food Display")
			expect(OrderSpec.StepState(spec, { Item = "Fudge Brownie" })).to.equal(2)
		end)

		it("every Ice Creams item is picked at the Ice Cream Freezer", function()
			assert(menuLoaded, "Shared.Ordering.Menu failed to load: " .. tostring(Menu))
			local count = 0
			for itemName in Menu.FoodTable["Ice Creams"].Items do
				local steps = OrderSpec.Steps(menuSpec("Ice Creams", itemName))
				expect(#steps).to.equal(1)
				expect(steps[1].Station).to.equal("Ice Cream Freezer")
				count += 1
			end
			expect(count > 0).to.equal(true)
		end)

		it("every Macarons, Mochis and Pastries item is picked at the Food Display", function()
			assert(menuLoaded, "Shared.Ordering.Menu failed to load: " .. tostring(Menu))
			for _, category in { "Macarons", "Mochis", "Pastries" } do
				for itemName in Menu.FoodTable[category].Items do
					local steps = OrderSpec.Steps(menuSpec(category, itemName))
					expect(#steps).to.equal(1)
					expect(steps[1].Station).to.equal("Food Display")
				end
			end
		end)
	end)

	-- ══════════════════════════════════════════════════════════════════════
	-- Menu data
	-- ══════════════════════════════════════════════════════════════════════

	describe("Menu ServeItem data", function()
		it("should set ServeItem on exactly the items whose tool is named differently", function()
			expect(menuDef("Boba Teas", "Custom Boba").ServeItem).to.equal("Boba")
			expect(menuDef("Boba Teas", "Matcha Tea Boba").ServeItem).to.equal("Boba")
			expect(menuDef("Mochis", "Orange Cream").ServeItem).to.equal("Orange Mochi")
			expect(menuDef("Others", "Cup").ServeItem).to.equal("Clear Cup")
			expect(menuDef("Coffees", "Regular").ServeItem).to.equal(nil)
		end)

		it("should keep the Featured Matcha entry the same table as the Boba Teas one", function()
			local matcha = menuDef("Boba Teas", "Matcha Tea Boba")
			expect(Menu.TopMenuSpecial.Items["Matcha Tea Boba"]).to.equal(matcha)
		end)
	end)
end

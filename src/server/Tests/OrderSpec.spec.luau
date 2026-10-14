-- selene: allow(undefined_variable)
--[[
	OrderSpec.spec.luau
	TestEZ tests for OrderSpec: Match, PickTools, FromMenuItem and FromOrderItem.

	Testing strategy
	────────────────
	Match and PickTools are pure: specs and tool attributes are plain tables, so no
	Instances are needed. FromMenuItem / FromOrderItem read the real Menu (it reads
	the authored SelectorModels, as OrderService.spec does), so those cases also
	cover the Menu's ServeItem data. If the Menu cannot load, only the Menu-backed
	cases fail.

	Cases 1-23 are the 23 cases of REVIVAL-001 M1.1 section 4 (case numbers are in
	the test names). The "FromOrderItem" block and the cases marked "extra" cover
	REVIVAL-001 M1.3b and edge rules not in that table.
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

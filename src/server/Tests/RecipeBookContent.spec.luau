-- selene: allow(undefined_variable)
--[[
	RecipeBookContent.spec.luau
	TestEZ tests for the pure Recipe Book string builder (REVIVAL-001 BIG-B1-P3-RECIPEBOOK):
	one block per ORDER_POOL drink, locked "Unlocks at Level N" blocks last.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Content = require(ReplicatedStorage.Shared.UI.Pages.Recipes.Content)

	local function find(text: string, needle: string): number?
		return string.find(text, needle, 1, true)
	end

	local function count(text: string, needle: string): number
		local total, from = 0, 1
		while true do
			local at = string.find(text, needle, from, true)
			if at == nil then
				return total
			end
			total += 1
			from = at + #needle
		end
	end

	describe("Content.build (B1)", function()
		it("level 1 locks the level-2 drinks", function()
			local text = Content.build(nil, 1)
			expect(count(text, "Unlocks at Level 2")).to.equal(2)
			expect(find(text, "<b>Taro Boba</b>") ~= nil).to.equal(true)
			expect(find(text, "Taro Syrup")).to.equal(nil)
		end)

		it("level 2 unlocks them", function()
			local text = Content.build(nil, 2)
			expect(find(text, "3. Taro Syrup") ~= nil).to.equal(true)
			expect(find(text, "3. Strawberry Syrup") ~= nil).to.equal(true)
			expect(find(text, "Unlocks at Level 2")).to.equal(nil)
		end)

		it("nil level reads as 1", function()
			expect(Content.build()).to.equal(Content.build(nil, 1))
		end)

		it("locked blocks come last", function()
			local text = Content.build(nil, 1)
			local brownie = find(text, "Fudge Brownie")
			local taro = find(text, "Taro Boba")
			expect(brownie ~= nil and taro ~= nil and brownie < taro).to.equal(true)
		end)

		it("focus keeps pool order", function()
			local text = Content.build("Custom Boba", 2)
			expect(string.sub(text, 1, #"<b>Classic Milk Tea Boba</b>")).to.equal("<b>Classic Milk Tea Boba</b>")
			local taro = find(text, "Taro Boba")
			local strawberry = find(text, "Strawberry Boba")
			local coffee = find(text, "Regular Coffee")
			expect(taro ~= nil and strawberry ~= nil and coffee ~= nil).to.equal(true)
			expect(taro < strawberry and strawberry < coffee).to.equal(true)
		end)

		-- Grab items now carry one Food Display step (OrderSpec), so the "Grab it from the display." fallback only
		-- prints for an item with no steps; the pastry block shows its pick step instead.
		it("grab items show their display pick step", function()
			local block = '<b>Fudge Brownie</b>\n<font face="DenkOne">1. Fudge Brownie</font>'
			expect(find(Content.build(nil, 1), block) ~= nil).to.equal(true)
		end)

		it("level 1 lists Espresso and Mango Boba locked, in level order", function()
			local text = Content.build(nil, 1)
			expect(count(text, "Unlocks at Level 7")).to.equal(1)
			expect(count(text, "Unlocks at Level 8")).to.equal(1)
			local strawberry = find(text, "<b>Strawberry Boba</b>")
			local espresso = find(text, "<b>Espresso</b>")
			local mango = find(text, "<b>Mango Boba</b>")
			expect(strawberry ~= nil and espresso ~= nil and mango ~= nil).to.equal(true)
			expect(strawberry < espresso and espresso < mango).to.equal(true)
			expect(find(text, "Mango Syrup")).to.equal(nil)
		end)

		it("level 7 unlocks Espresso only", function()
			local text = Content.build(nil, 7)
			expect(find(text, "2. Espresso") ~= nil).to.equal(true)
			expect(count(text, "Unlocks at")).to.equal(1)
			expect(find(text, "Unlocks at Level 8") ~= nil).to.equal(true)
		end)

		it("level 8 unlocks everything", function()
			local text = Content.build(nil, 8)
			expect(find(text, "2. Espresso") ~= nil).to.equal(true)
			expect(find(text, "3. Mango Syrup") ~= nil).to.equal(true)
			expect(find(text, "Unlocks at")).to.equal(nil)
			local strawberry = find(text, "<b>Strawberry Boba</b>")
			local espresso = find(text, "<b>Espresso</b>")
			local mango = find(text, "<b>Mango Boba</b>")
			expect(strawberry ~= nil and espresso ~= nil and mango ~= nil).to.equal(true)
			expect(strawberry < espresso and espresso < mango).to.equal(true)
		end)
	end)
end

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
			expect(find(text, "Unlocks at")).to.equal(nil)
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

		it("grab text stays", function()
			expect(find(Content.build(nil, 1), "Grab it from the display.") ~= nil).to.equal(true)
		end)
	end)
end

--[[
    KitchenRecipes.spec.luau
    Tests for the kitchen tool-name state machine.

    Testing strategy
    ────────────────
    A drink is built by renaming the held tool at each station, and every station
    gates on that name. The patterns are easy to get subtly wrong and a mistake is
    invisible until someone plays the game, so these tests walk the full name chain
    for both Blender paths using the same matcher the runner uses.

    ToolNameMatcher is pure (string in, boolean out) so it needs no Roblox state.
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local ToolNameMatcher = require(Shared.Kitchen.ToolNameMatcher)
	local Recipes = require(Shared.Kitchen.Recipes)

	-- Gates copied from Recipes.luau. If a gate changes there and not here, the
	-- corresponding test fails and points at the drift.
	local FRUITS_FREEZER_GATE = { "#Clear Cup", "!%[Fruit%]" }
	local MILK_GATE = { "#Clear Cup|=Mug", "!%+ Milk" }
	local SYRUP_GATE = { "#Cup %+ Milk" }
	local BLENDER_SMOOTHIE_PATTERN = "#%[Fruit%] %+ Milk"
	local BLENDER_FLAVORED_MILK_PATTERN = "#Syrup"

	describe("ToolNameMatcher", function()
		it("should match exact terms with '='", function()
			expect(ToolNameMatcher.matchesTerm("Mug", "=Mug")).to.equal(true)
			expect(ToolNameMatcher.matchesTerm("Mug + Steamed Milk", "=Mug")).to.equal(false)
		end)

		it("should match patterns with '#'", function()
			expect(ToolNameMatcher.matchesTerm("Small Clear Cup", "#Clear Cup")).to.equal(true)
			expect(ToolNameMatcher.matchesTerm("Small Cup", "#Clear Cup")).to.equal(false)
		end)

		it("should negate with '!'", function()
			expect(ToolNameMatcher.matchesTerm("Small Clear Cup", "!%+ Milk")).to.equal(true)
			expect(ToolNameMatcher.matchesTerm("Small Clear Cup + Milk", "!%+ Milk")).to.equal(false)
		end)

		it("should treat '|' as alternatives", function()
			expect(ToolNameMatcher.matchesEntry("Mug", "#Clear Cup|=Mug")).to.equal(true)
			expect(ToolNameMatcher.matchesEntry("Small Clear Cup", "#Clear Cup|=Mug")).to.equal(true)
			expect(ToolNameMatcher.matchesEntry("Small Cup", "#Clear Cup|=Mug")).to.equal(false)
		end)

		it("should require every entry in matchesAll", function()
			expect(ToolNameMatcher.matchesAll("Small Clear Cup", FRUITS_FREEZER_GATE)).to.equal(true)
			-- already has a fruit, so the freezer must reject it
			expect(ToolNameMatcher.matchesAll("Small Clear Cup + [Fruit]", FRUITS_FREEZER_GATE)).to.equal(false)
		end)
	end)

	describe("smoothie chain", function()
		-- Clear Cup -> Fruits Freezer -> Milk -> Blender
		local afterFreezer = "Small Clear Cup + [Fruit]"
		local afterMilk = "Small Clear Cup + [Fruit] + Milk"

		it("should let a fresh clear cup into the Fruits Freezer", function()
			expect(ToolNameMatcher.matchesAll("Small Clear Cup", FRUITS_FREEZER_GATE)).to.equal(true)
		end)

		it("should let a fruit cup take milk", function()
			expect(ToolNameMatcher.matchesAll(afterFreezer, MILK_GATE)).to.equal(true)
		end)

		it("should route a milked fruit cup to the Blender smoothie branch", function()
			expect(ToolNameMatcher.matchesEntry(afterMilk, BLENDER_SMOOTHIE_PATTERN)).to.equal(true)
		end)

		it("should not route a milked fruit cup to the flavored milk branch", function()
			expect(ToolNameMatcher.matchesEntry(afterMilk, BLENDER_FLAVORED_MILK_PATTERN)).to.equal(false)
		end)

		it("should refuse a second helping of milk", function()
			expect(ToolNameMatcher.matchesAll(afterMilk, MILK_GATE)).to.equal(false)
		end)
	end)

	describe("flavored milk chain", function()
		-- Clear Cup -> Milk -> Syrup -> Blender
		local afterMilk = "Small Clear Cup + Milk"
		local afterSyrup = "Milk + Taro Syrup"

		it("should let a milked cup take syrup", function()
			expect(ToolNameMatcher.matchesAll(afterMilk, SYRUP_GATE)).to.equal(true)
		end)

		it("should route a syruped cup to the Blender flavored milk branch", function()
			expect(ToolNameMatcher.matchesEntry(afterSyrup, BLENDER_FLAVORED_MILK_PATTERN)).to.equal(true)
		end)

		it("should not route a syruped cup to the smoothie branch", function()
			expect(ToolNameMatcher.matchesEntry(afterSyrup, BLENDER_SMOOTHIE_PATTERN)).to.equal(false)
		end)
	end)

	describe("mug chain", function()
		it("should let an empty mug take steamed milk", function()
			expect(ToolNameMatcher.matchesAll("Mug", MILK_GATE)).to.equal(true)
		end)

		it("should refuse a mug that already has steamed milk", function()
			expect(ToolNameMatcher.matchesAll("Mug + Steamed Milk", MILK_GATE)).to.equal(false)
		end)
	end)

	describe("recipe data", function()
		it("should have a garnish and colour for every smoothie", function()
			for smoothieName in Recipes.Smoothies do
				expect(Recipes.SmoothiesGarnish[smoothieName]).to.be.ok()
			end
		end)

		it("should key every smoothie as '<Fruit> Smoothie'", function()
			for smoothieName in Recipes.Smoothies do
				expect(smoothieName:match(" Smoothie$")).to.be.ok()
			end
		end)

		it("should expose a Fruits Freezer and a Lid station", function()
			expect(Recipes.Items["Fruits Freezer"]).to.be.ok()
			-- "Lid" (not "Lids") — must match the model name in the build.
			expect(Recipes.Items["Lid"]).to.be.ok()
		end)
	end)
end

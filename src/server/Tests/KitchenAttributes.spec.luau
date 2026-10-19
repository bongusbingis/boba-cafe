-- selene: allow(undefined_variable)
--[[
	KitchenAttributes.spec.luau
	TestEZ tests for the tool attributes the kitchen stations write (REVIVAL-001
	M1.3c; contract in M1.1 design section 3): Item, Size, Syrup, Tapioca, Iced, Sugar
	and Lid. OrderSpec.Match grades a finished tool from these, never from its name.

	Testing strategy
	────────────────
	The real Recipes data and the real GiveTool / SetToolAttributes /
	ToolNameValidityCheck / ToolAttributeCheck / RenameToolHolding actions run against real Tool and Model
	instances. The player is a plain table ({ Character, Backpack }). A small runner
	walks a recipe's Actions in order and follows SelectFrom branches by a chosen key;
	AnimateRaw and SetToolHoldingProperty are skipped because they change neither
	names nor attributes.

	The giver stations (Clear Cup, Cup, Food Display) clone the real tools from
	ReplicatedStorage.SharedStorage.Tools.Kitchen, so those cases need the place
	content. If a tool is missing the case fails with the recipe's name. Cases that
	start from a hand-made tool need no place content.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Recipes = require(ReplicatedStorage.Shared.Kitchen.Recipes)
	local OrderSpec = require(ReplicatedStorage.Shared.Ordering.OrderSpec)
	local menuLoaded, Menu = pcall(require, ReplicatedStorage.Shared.Ordering.Menu)

	local ActionsFolder = ServerScriptService.Server.Modules.KitchenService.Actions
	local GiveTool = require(ActionsFolder.GiveTool)
	local SetToolAttributes = require(ActionsFolder.SetToolAttributes)
	local actionFunctions = {
		GiveTool = GiveTool,
		SetToolAttributes = SetToolAttributes,
		ToolNameValidityCheck = require(ActionsFolder.ToolNameValidityCheck),
		ToolAttributeCheck = require(ActionsFolder.ToolAttributeCheck),
		RenameToolHolding = require(ActionsFolder.RenameToolHolding),
	}
	-- Actions that change neither a tool's name nor its attributes.
	local SKIPPED_ACTIONS = { AnimateRaw = true, SetToolHoldingProperty = true }

	-- The OrderSpec attribute names. Other attributes (AutoWeld, ...) are not part of the contract.
	local CONTRACT_NAMES = { "Item", "Size", "Syrup", "Tapioca", "Iced", "Sugar", "Lid" }

	-- ──────────────────────────────────────────────────────────────────────
	-- Helpers
	-- ──────────────────────────────────────────────────────────────────────

	local created: { Instance } = {}

	local function makePlayer()
		local character = Instance.new("Model")
		local backpack = Instance.new("Folder")
		table.insert(created, character)
		table.insert(created, backpack)
		return { Character = character, Backpack = backpack }
	end

	-- A hand-made tool held by the player, with optional starting attributes.
	local function hold(player: any, name: string, attributes: { [string]: any }?): Tool
		local tool = Instance.new("Tool")
		tool.Name = name
		for key, value in attributes or {} do
			tool:SetAttribute(key, value)
		end
		tool.Parent = player.Character
		return tool
	end

	local function heldTool(player: any): Tool?
		return player.Character:FindFirstChildWhichIsA("Tool")
	end

	-- The contract attributes of a tool as "Item=Boba, Size=Medium, ..." (sorted by name).
	local function contractString(tool: Instance?): string
		assert(tool, "no tool held")
		local parts = {}
		for _, name in CONTRACT_NAMES do
			local value = tool:GetAttribute(name)
			if value ~= nil then
				table.insert(parts, `{name}={tostring(value)}`)
			end
		end
		table.sort(parts)
		return table.concat(parts, ", ")
	end

	local function runActions(player: any, actions: { any }, choices: { [string]: string }): boolean
		for _, action in actions do
			local actionName = action[1]
			if SKIPPED_ACTIONS[actionName] then
				continue
			end
			if actionName == "SelectFrom" then
				local title = action[2].Title
				local choice = choices[title]
				local branch = action[3][choice]
				assert(branch, `no branch {tostring(choice)} for SelectFrom "{tostring(title)}"`)
				if not runActions(player, branch, choices) then
					return false
				end
				continue
			end
			local actionFunction = actionFunctions[actionName]
			assert(actionFunction, `KitchenAttributes.spec cannot run action {tostring(actionName)}`)
			if not actionFunction(player, nil :: any, table.unpack(action, 2)) then
				return false
			end
		end
		return true
	end

	-- Runs one station. `choices` maps a SelectFrom title to the branch key to take.
	local function station(player: any, recipeName: string, choices: { [string]: string }?): boolean
		local recipe = Recipes.Items[recipeName]
		assert(recipe, `Recipes.Items["{recipeName}"] is missing (is its tool under SharedStorage.Tools.Kitchen?)`)
		return runActions(player, recipe.Actions, choices or {})
	end

	-- The Menu item definition named `itemName`, in any category.
	local function findMenuItem(itemName: string): any
		assert(menuLoaded, "Shared.Ordering.Menu failed to load")
		for _, category in Menu.FoodTable do
			if type(category) == "table" and type(category.Items) == "table" and category.Items[itemName] then
				return category.Items[itemName]
			end
		end
		error(`Menu has no item "{itemName}"`)
	end

	local function collectItemsWritten(actions: { any }, into: { [string]: boolean })
		for _, action in actions do
			if action[1] == "SelectFrom" then
				for _, branch in action[3] do
					collectItemsWritten(branch, into)
				end
			elseif action[1] == "SetToolAttributes" and type(action[2].Item) == "string" then
				into[action[2].Item] = true
			elseif action[1] == "GiveTool" and type(action[3]) == "table" and type(action[3].Item) == "string" then
				into[action[3].Item] = true
			end
		end
	end

	afterEach(function()
		for _, instance in created do
			instance:Destroy()
		end
		table.clear(created)
	end)

	-- ──────────────────────────────────────────────────────────────────────
	-- The three slice items (REVIVAL-001 M1.2 section 9, M1.3c)
	-- ──────────────────────────────────────────────────────────────────────

	describe("slice items", function()
		it("should mark a Medium Classic Milk Tea Boba with Normal tapioca", function()
			local player = makePlayer()
			expect(station(player, "Clear Cup", { ["Clear Cup"] = "Medium" })).to.equal(true)
			expect(station(player, "Milk")).to.equal(true)
			expect(station(player, "Classic Milk Tea Syrup")).to.equal(true)
			expect(station(player, "Normal Tapioca")).to.equal(true)

			expect(contractString(heldTool(player))).to.equal(
				"Item=Boba, Size=Medium, Syrup=Classic Milk Tea, Tapioca=Normal"
			)
			expect(heldTool(player).Name).to.equal("Classic Milk Tea Boba")
		end)

		it("should mark the same boba after the Blender, which writes nothing", function()
			local player = makePlayer()
			station(player, "Clear Cup", { ["Clear Cup"] = "Medium" })
			station(player, "Milk")
			station(player, "Classic Milk Tea Syrup")
			local before = contractString(heldTool(player))
			expect(station(player, "Blender")).to.equal(true)
			expect(contractString(heldTool(player))).to.equal(before)
			expect(station(player, "Normal Tapioca")).to.equal(true)

			expect(contractString(heldTool(player))).to.equal(
				"Item=Boba, Size=Medium, Syrup=Classic Milk Tea, Tapioca=Normal"
			)
		end)

		it("should mark a Small Regular coffee", function()
			local player = makePlayer()
			expect(station(player, "Cup", { Cup = "Small" })).to.equal(true)
			expect(station(player, "Coffee Machine", { ["Coffee Machine"] = "Regular" })).to.equal(true)

			expect(contractString(heldTool(player))).to.equal("Item=Regular, Size=Small")
			expect(heldTool(player).Name).to.equal("Regular")
		end)

		it("should mark a Fudge Brownie", function()
			local player = makePlayer()
			expect(station(player, "Food Display", { ["Food Display"] = "Fudge Brownie" })).to.equal(true)

			expect(contractString(heldTool(player))).to.equal("Item=Fudge Brownie")
			expect(heldTool(player).Name).to.equal("Fudge Brownie")
		end)

		it("should grade all three as Perfect against the specs the Menu derives", function()
			assert(menuLoaded, "Shared.Ordering.Menu failed to load")
			local cases = {
				{
					"Custom Boba",
					{ Size = "Medium", ["Syrup Flavor"] = "Classic Milk Tea", ["Tapioca Flavor"] = "Normal" },
				},
				{ "Regular", { Size = "Small" } },
				{ "Fudge Brownie", {} },
			}
			local players = {}
			for index = 1, 3 do
				players[index] = makePlayer()
			end
			station(players[1], "Clear Cup", { ["Clear Cup"] = "Medium" })
			station(players[1], "Milk")
			station(players[1], "Classic Milk Tea Syrup")
			station(players[1], "Normal Tapioca")
			station(players[2], "Cup", { Cup = "Small" })
			station(players[2], "Coffee Machine", { ["Coffee Machine"] = "Regular" })
			station(players[3], "Food Display", { ["Food Display"] = "Fudge Brownie" })

			for index, case in cases do
				local spec, failedField = OrderSpec.FromMenuItem(findMenuItem(case[1]), case[2])
				expect(failedField).to.equal(nil)
				local grade = OrderSpec.Match(spec, heldTool(players[index]):GetAttributes())
				expect(grade).to.equal("Perfect")
			end
		end)
	end)

	-- ──────────────────────────────────────────────────────────────────────
	-- Other stations
	-- ──────────────────────────────────────────────────────────────────────

	describe("stations", function()
		it("should mark a cup of cold or hot water and keep its size", function()
			local player = makePlayer()
			station(player, "Cup", { Cup = "Large" })
			expect(station(player, "Sink", { Sink = "Cold Water" })).to.equal(true)
			expect(contractString(heldTool(player))).to.equal("Item=Water, Size=Large")

			local other = makePlayer()
			station(other, "Cup", { Cup = "Small" })
			expect(station(other, "Sink", { Sink = "Hot Water" })).to.equal(true)
			expect(contractString(heldTool(other))).to.equal("Item=Water, Size=Small")
		end)

		it("should mark milk, keeping the cup size", function()
			local player = makePlayer()
			hold(player, "Small Clear Cup", { Item = "Clear Cup", Size = "Small" })
			expect(station(player, "Milk")).to.equal(true)
			expect(contractString(heldTool(player))).to.equal("Item=Milk, Size=Small")
		end)

		it("should mark flavored milk with its syrup, for every syrup", function()
			for syrup in Recipes.Syrups do
				local player = makePlayer()
				hold(player, "Medium Clear Cup + Milk", { Item = "Milk", Size = "Medium" })
				expect(station(player, `{syrup} Syrup`)).to.equal(true)
				expect(contractString(heldTool(player))).to.equal(`Item=Flavored Milk, Size=Medium, Syrup={syrup}`)
			end
		end)

		it("should mark every tapioca flavor by its key", function()
			for tapioca in Recipes.Tapioca do
				local player = makePlayer()
				hold(player, "Milk + Taro Syrup", { Item = "Flavored Milk", Size = "Small", Syrup = "Taro" })
				expect(station(player, `{tapioca} Tapioca`)).to.equal(true)
				expect(contractString(heldTool(player))).to.equal(
					`Item=Boba, Size=Small, Syrup=Taro, Tapioca={tapioca}`
				)
			end
		end)

		it("should add Iced and then Sugar to a coffee without touching the rest", function()
			local player = makePlayer()
			hold(player, "Regular", { Item = "Regular", Size = "Small" })
			expect(station(player, "Ice Machine")).to.equal(true)
			expect(contractString(heldTool(player))).to.equal("Iced=true, Item=Regular, Size=Small")
			expect(station(player, "Sugar")).to.equal(true)
			expect(contractString(heldTool(player))).to.equal("Iced=true, Item=Regular, Size=Small, Sugar=true")
		end)

		it("should mark a tea from the Water cup, keeping the size", function()
			local player = makePlayer()
			hold(player, "Medium Cold Water", { Item = "Water", Size = "Medium" })
			expect(station(player, "Green Tea Powder")).to.equal(true)
			expect(contractString(heldTool(player))).to.equal("Item=Green Tea, Size=Medium")
		end)

		it("should mark hot chocolate in a mug, plain and flavored", function()
			local plain = makePlayer()
			hold(plain, "Mug + Steamed Milk", { Item = "Milk", Size = "Mug" })
			expect(station(plain, "Hot Chocolate Powder")).to.equal(true)
			expect(contractString(heldTool(plain))).to.equal("Item=Hot Chocolate, Size=Mug")

			local caramel = makePlayer()
			hold(caramel, "Mug + Steamed Milk", { Item = "Milk", Size = "Mug" })
			expect(station(caramel, "Caramel Hot Chocolate Powder")).to.equal(true)
			expect(contractString(heldTool(caramel))).to.equal("Item=Caramel Hot Chocolate, Size=Mug")
		end)

		it("should mark a mug with Size=Mug and Item=Mug", function()
			if not Recipes.Items["Mug"] then
				error('Recipes.Items["Mug"] is missing (is Tools.Kitchen.Mug under SharedStorage?)')
			end
			local player = makePlayer()
			expect(station(player, "Mug")).to.equal(true)
			expect(contractString(heldTool(player))).to.equal("Item=Mug, Size=Mug")
		end)

		it("should add Lid", function()
			local player = makePlayer()
			hold(player, "Regular", { Item = "Regular", Size = "Small" })
			expect(station(player, "Lids")).to.equal(true)
			expect(contractString(heldTool(player))).to.equal("Item=Regular, Lid=true, Size=Small")
		end)

		it("should give every grab item its own name as Item", function()
			local grabbed = 0
			for _, stationName in { "Food Display", "Ice Cream Freezer" } do
				local recipe = Recipes.Items[stationName]
				if recipe then
					for itemName in recipe.Actions[1][3] do
						local player = makePlayer()
						expect(station(player, stationName, { [stationName] = itemName })).to.equal(true)
						expect(contractString(heldTool(player))).to.equal(`Item={itemName}`)
						grabbed += 1
					end
				end
			end
			expect(grabbed > 0).to.equal(true)
		end)
	end)

	-- ──────────────────────────────────────────────────────────────────────
	-- A failed gate leaves the tool unmarked
	-- ──────────────────────────────────────────────────────────────────────

	describe("a refused station", function()
		-- { station, held tool name, held attributes, SelectFrom choices }
		local refused = {
			{ "Normal Tapioca", "Medium Clear Cup + Milk", { Item = "Milk", Size = "Medium" } },
			{ "Taro Syrup", "Medium Clear Cup", { Item = "Clear Cup", Size = "Medium" } },
			{ "Milk", "Regular", { Item = "Regular", Size = "Small" } },
			{ "Ice Machine", "Small Cup", { Item = "Cup", Size = "Small" } },
			{ "Caramel Hot Chocolate Powder", "Small Cup", { Item = "Cup", Size = "Small" } },
			{ "Green Tea Powder", "Regular", { Item = "Regular", Size = "Small" } },
			{ "Blender", "Medium Clear Cup + Milk", { Item = "Milk", Size = "Medium" } },
			{ "Sink", "Mug + Steamed Milk", { Item = "Milk", Size = "Mug" }, { Sink = "Cold Water" } },
			{
				"Coffee Machine",
				"Medium Clear Cup",
				{ Item = "Clear Cup", Size = "Medium" },
				{ ["Coffee Machine"] = "Regular" },
			},
		}

		for _, case in refused do
			it(`should leave the tool unmarked: {case[1]} on "{case[2]}"`, function()
				local player = makePlayer()
				local tool = hold(player, case[2], case[3])
				local before = contractString(tool)
				expect(station(player, case[1], case[4])).to.equal(false)
				expect(contractString(tool)).to.equal(before)
				expect(tool.Name).to.equal(case[2])
			end)
		end

		it("should leave a tool that has no attributes with none", function()
			local player = makePlayer()
			local tool = hold(player, "Fudge Brownie")
			expect(station(player, "Normal Tapioca")).to.equal(false)
			expect(contractString(tool)).to.equal("")
		end)
	end)

	-- ──────────────────────────────────────────────────────────────────────
	-- Actions
	-- ──────────────────────────────────────────────────────────────────────

	describe("SetToolAttributes", function()
		it("should set literal attributes on the held tool", function()
			local player = makePlayer()
			local tool = hold(player, "Anything")
			expect(SetToolAttributes(player, nil :: any, { Item = "Milk", Iced = true })).to.equal(true)
			expect(tool:GetAttribute("Item")).to.equal("Milk")
			expect(tool:GetAttribute("Iced")).to.equal(true)
		end)

		it("should return false when no tool is held", function()
			local player = makePlayer()
			expect(SetToolAttributes(player, nil :: any, { Item = "Milk" })).to.equal(false)
		end)

		it("should set nothing when one value is not a literal", function()
			local player = makePlayer()
			local tool = hold(player, "Anything")
			expect(SetToolAttributes(player, nil :: any, { Item = "Milk", Bad = {} })).to.equal(false)
			expect(tool:GetAttribute("Item")).to.equal(nil)
		end)
	end)

	describe("GiveTool", function()
		it("should default Item to the cloned tool's name and leave the source untouched", function()
			local source = Instance.new("Tool")
			source.Name = "Vanilla Macaron"
			table.insert(created, source)
			local player = makePlayer()

			expect(GiveTool(player, nil :: any, source)).to.equal(true)
			expect(contractString(heldTool(player))).to.equal("Item=Vanilla Macaron")
			expect(source:GetAttribute("Item")).to.equal(nil)
		end)

		it("should apply the given attributes over the default Item", function()
			local source = Instance.new("Tool")
			source.Name = "Small Clear Cup"
			table.insert(created, source)
			local player = makePlayer()

			expect(GiveTool(player, nil :: any, source, { Item = "Clear Cup", Size = "Small" })).to.equal(true)
			expect(contractString(heldTool(player))).to.equal("Item=Clear Cup, Size=Small")
			expect(heldTool(player).Name).to.equal("Small Clear Cup")
		end)

		it("should keep the marks on the tool it puts in the backpack", function()
			local player = makePlayer()
			hold(player, "Regular", { Item = "Regular", Size = "Small" })
			local source = Instance.new("Tool")
			source.Name = "Fudge Brownie"
			table.insert(created, source)

			expect(GiveTool(player, nil :: any, source)).to.equal(true)
			expect(contractString(heldTool(player))).to.equal("Item=Fudge Brownie")
			expect(contractString(player.Backpack:FindFirstChild("Regular"))).to.equal("Item=Regular, Size=Small")
		end)

		it("should refuse bad attributes before it moves the held tool", function()
			local player = makePlayer()
			local tool = hold(player, "Regular", { Item = "Regular" })
			local source = Instance.new("Tool")
			source.Name = "Fudge Brownie"
			table.insert(created, source)

			expect(GiveTool(player, nil :: any, source, { Item = "Fudge Brownie", Bad = {} })).to.equal(false)
			expect(tool.Parent).to.equal(player.Character)
			expect(#player.Backpack:GetChildren()).to.equal(0)
		end)
	end)

	-- ──────────────────────────────────────────────────────────────────────
	-- Consistency with the Menu
	-- ──────────────────────────────────────────────────────────────────────

	describe("Menu consistency", function()
		it("should write an Item that is a Menu serve item, apart from the raw Cup and Mug", function()
			assert(menuLoaded, "Shared.Ordering.Menu failed to load")
			local menuItems: { [string]: boolean } = {}
			for _, category in Menu.FoodTable do
				if type(category) == "table" and type(category.Items) == "table" then
					for _, def in category.Items do
						menuItems[def.ServeItem or def.ItemName] = true
					end
				end
			end

			local written: { [string]: boolean } = {}
			for _, recipe in Recipes.Items do
				collectItemsWritten(recipe.Actions, written)
			end
			-- "Cup" is the unfilled cup that coffee and water start from, and "Mug" the unfilled mug.
			written["Cup"] = nil
			written["Mug"] = nil

			local count = 0
			for itemName in written do
				count += 1
				expect(`{itemName}:{tostring(menuItems[itemName])}`).to.equal(`{itemName}:true`)
			end
			expect(count > 0).to.equal(true)
		end)

		-- Not asserted: the other syrups. Recipes.Syrups has Watermelon and Dragon Fruit, which
		-- the Menu does not offer, and the Menu offers Almond, Avocado, Banana, Blueberry,
		-- Honeycomb, Mint, Orange and Peach, which have no syrup station. That is a Menu and
		-- launch-menu question (REVIVAL-001 M1.3c evidence), not a rule this spec can pick.
		it("should use tapioca keys and the slice syrup that the Custom Boba offers", function()
			local def = findMenuItem("Custom Boba")
			expect(def.RequiredSelection["Syrup Flavor"]["Classic Milk Tea"] ~= nil).to.equal(true)
			expect(Recipes.Syrups["Classic Milk Tea"] ~= nil).to.equal(true)
			for tapioca in Recipes.Tapioca do
				expect(`{tapioca}:{tostring(def.RequiredSelection["Tapioca Flavor"][tapioca] ~= nil)}`).to.equal(
					`{tapioca}:true`
				)
			end
		end)
	end)
end

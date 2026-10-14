-- selene: allow(undefined_variable)
--[[
	BobaRecipe.spec.luau
	TestEZ tests for the boba name chain: Cup -> Milk -> Syrup -> (Blender) -> Tapioca.

	Testing strategy
	────────────────
	The real Recipes data and the real ToolNameValidityCheck / RenameToolHolding
	actions are used. The player is a plain table holding one fake Tool (a table with
	a Name), so no Studio instances are needed. Only the two name-related actions run;
	property and sound actions are skipped.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Recipes = require(ReplicatedStorage.Shared.Kitchen.Recipes)
	local Actions = ServerScriptService.Server.Modules.KitchenService.Actions
	local ToolNameValidityCheck = require(Actions.ToolNameValidityCheck)
	local RenameToolHolding = require(Actions.RenameToolHolding)

	local function makePlayer(toolName: string)
		local tool = { Name = toolName }
		local character = {}
		function character:FindFirstChildWhichIsA(_className: string)
			return tool
		end
		return { Character = character }, tool
	end

	-- Runs a recipe's name actions. Returns false when the validity check refuses.
	local function apply(recipeName: string, player: any): boolean
		local recipe = Recipes.Items[recipeName]
		for _, action in recipe.Actions do
			if action[1] == "ToolNameValidityCheck" then
				if not ToolNameValidityCheck(player, nil :: any, action[2]) then
					return false
				end
			elseif action[1] == "RenameToolHolding" then
				RenameToolHolding(player, nil :: any, action[2])
			end
		end
		return true
	end

	local function makeBoba(syrup: string, tapioca: string, blend: boolean): (boolean, string)
		local player, tool = makePlayer("Small Clear Cup + Milk")
		assert(apply(syrup .. " Syrup", player), "syrup step refused")
		if blend then
			assert(apply("Blender", player), "blender step refused")
		end
		local ok = apply(tapioca .. " Tapioca", player)
		return ok, tool.Name
	end

	describe("Recipes.Syrups", function()
		it("should produce '[Syrup] Boba' for every syrup, with and without the blender", function()
			for syrup in Recipes.Syrups do
				for _, blend in { false, true } do
					local ok, name = makeBoba(syrup, "Normal", blend)
					expect(ok).to.equal(true)
					expect(name).to.equal(syrup .. " Boba")
				end
			end
		end)

		it("should accept every tapioca flavor", function()
			for tapioca in Recipes.Tapioca do
				local ok, name = makeBoba("Taro", tapioca, false)
				expect(ok).to.equal(true)
				expect(name).to.equal("Taro Boba")
			end
		end)
	end)

	describe("Tapioca step", function()
		it("should refuse a cup that has milk but no syrup", function()
			local player = makePlayer("Small Clear Cup + Milk")
			expect(apply("Normal Tapioca", player)).to.equal(false)
		end)

		it("should refuse a mug of steamed milk", function()
			local player = makePlayer("Mug + Steamed Milk")
			expect(apply("Normal Tapioca", player)).to.equal(false)
		end)

		it("should keep a sugar suffix", function()
			local player, tool = makePlayer("Milk + Taro Syrup + Sugar")
			expect(apply("Normal Tapioca", player)).to.equal(true)
			expect(tool.Name).to.equal("Taro Boba + Sugar")
		end)
	end)
end

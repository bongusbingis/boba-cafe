-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	BobaBalls.spec.luau
	TestEZ tests for BobaBalls mesh wiring in clear cups:
	- When tapioca is added to a boba drink, BobaBalls transparency is set to 0 and recolored.
	- SetToolHoldingProperty finds BobaBalls as a child or descendant (including SpecialMesh parent parts).
	- Recipes definition includes BobaBalls actions for every tapioca flavor.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Recipes = require(ReplicatedStorage.Shared.Kitchen.Recipes)
	local Actions = ServerScriptService.Server.Modules.KitchenService.Actions
	local SetToolHoldingProperty = require(Actions.SetToolHoldingProperty)
	local SetToolAttributes = require(Actions.SetToolAttributes)
	local GiveTool = require(Actions.GiveTool)

	local function makePlayerWithTool(tool: Tool)
		local character = Instance.new("Model")
		tool.Parent = character
		return {
			Character = character,
			Backpack = Instance.new("Folder"),
		} :: any
	end

	describe("Recipes tapioca actions for BobaBalls", function()
		it("includes actions to set BobaBalls Color and Transparency to 0 for every tapioca flavor", function()
			for flavor, expectedColor in Recipes.Tapioca do
				local recipeName = flavor .. " Tapioca"
				local recipe = Recipes.Items[recipeName]
				expect(recipe).to.be.ok()

				local hasBobaColor = false
				local hasBobaTransparency = false
				for _, action in recipe.Actions do
					if action[1] == "SetToolHoldingProperty" and action[2] == "BobaBalls" then
						if action[3] == "Color" and action[4] == expectedColor then
							hasBobaColor = true
						elseif action[3] == "Transparency" and action[4] == 0 then
							hasBobaTransparency = true
						end
					end
				end

				expect(hasBobaColor).to.equal(true)
				expect(hasBobaTransparency).to.equal(true)
			end
		end)
	end)

	describe("SetToolHoldingProperty on BobaBalls", function()
		it("recolors BobaBalls and sets transparency to 0 on a direct child part", function()
			local tool = Instance.new("Tool")
			local bobaBalls = Instance.new("Part")
			bobaBalls.Name = "BobaBalls"
			bobaBalls.Transparency = 1
			bobaBalls.Color = Color3.new(0, 0, 0)
			bobaBalls.Parent = tool

			local player = makePlayerWithTool(tool)
			local testColor = Color3.fromRGB(214, 94, 100) -- Strawberry

			local ok1 = SetToolHoldingProperty(player, nil :: any, "BobaBalls", "Transparency", 0)
			local ok2 = SetToolHoldingProperty(player, nil :: any, "BobaBalls", "Color", testColor)

			expect(ok1).to.equal(true)
			expect(ok2).to.equal(true)
			expect(bobaBalls.Transparency).to.equal(0)
			expect(bobaBalls.Color).to.equal(testColor)
		end)

		it("finds BobaBalls as a descendant inside a Handle or Model", function()
			local tool = Instance.new("Tool")
			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Parent = tool

			local bobaBalls = Instance.new("Part")
			bobaBalls.Name = "BobaBalls"
			bobaBalls.Transparency = 1
			bobaBalls.Color = Color3.new(0, 0, 0)
			bobaBalls.Parent = handle

			local player = makePlayerWithTool(tool)
			local testColor = Color3.fromRGB(183, 150, 227) -- Mystic Burst

			SetToolHoldingProperty(player, nil :: any, "BobaBalls", "Transparency", 0)
			SetToolHoldingProperty(player, nil :: any, "BobaBalls", "Color", testColor)

			expect(bobaBalls.Transparency).to.equal(0)
			expect(bobaBalls.Color).to.equal(testColor)
		end)

		it("properly targets the parent BasePart when BobaBalls is a SpecialMesh", function()
			local tool = Instance.new("Tool")
			local part = Instance.new("Part")
			part.Name = "BobaBallsPart"
			part.Transparency = 1
			part.Color = Color3.new(0, 0, 0)
			part.Parent = tool

			local mesh = Instance.new("SpecialMesh")
			mesh.Name = "BobaBalls"
			mesh.Parent = part

			local player = makePlayerWithTool(tool)
			local testColor = Color3.fromRGB(245, 240, 174) -- Banana Blast

			SetToolHoldingProperty(player, nil :: any, "BobaBalls", "Transparency", 0)
			SetToolHoldingProperty(player, nil :: any, "BobaBalls", "Color", testColor)

			expect(part.Transparency).to.equal(0)
			expect(part.Color).to.equal(testColor)
		end)
	end)

	describe("SetToolAttributes with Tapioca", function()
		it("automatically ensures BobaBalls is visible and recolored when Tapioca attribute is set", function()
			local tool = Instance.new("Tool")
			local bobaBalls = Instance.new("Part")
			bobaBalls.Name = "BobaBalls"
			bobaBalls.Transparency = 1
			bobaBalls.Color = Color3.new(0, 0, 0)
			bobaBalls.Parent = tool

			local player = makePlayerWithTool(tool)
			SetToolAttributes(player, nil :: any, { Item = "Boba", Tapioca = "Normal" })

			expect(tool:GetAttribute("Tapioca")).to.equal("Normal")
			expect(bobaBalls.Transparency).to.equal(0)
			expect(bobaBalls.Color).to.equal(Recipes.Tapioca["Normal"])
		end)
	end)

	describe("GiveTool with cups containing BobaBalls", function()
		it("initializes BobaBalls transparency to 1 (hidden) when given an unmade cup", function()
			local template = Instance.new("Tool")
			template.Name = "Medium Clear Cup"
			local bobaBalls = Instance.new("Part")
			bobaBalls.Name = "BobaBalls"
			bobaBalls.Transparency = 0 -- was not 1 in template
			bobaBalls.Parent = template

			local character = Instance.new("Model")
			local player = {
				Character = character,
				Backpack = Instance.new("Folder"),
			} :: any

			local ok = GiveTool(player, nil :: any, template, { Item = "Clear Cup", Size = "Medium" })
			expect(ok).to.equal(true)

			local given = character:FindFirstChildWhichIsA("Tool")
			expect(given).to.be.ok()
			local givenBoba = given:FindFirstChild("BobaBalls", true) :: BasePart
			expect(givenBoba).to.be.ok()
			expect(givenBoba.Transparency).to.equal(1)
		end)
	end)
end

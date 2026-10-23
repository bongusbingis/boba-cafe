-- TestEZ injects describe/it/expect/beforeEach/afterEach/afterAll as globals.
--# selene: allow(undefined_variable)
--[[
	BobaPhone.spec.luau
	TestEZ tests for the Boba Phone request mapping (REVIVAL-001 BOBA-PHONE
	section 6, pure): the launch filter, the Select/Options defaults, the
	3-item cap, the server request shape, and the Tool clone preparation.
	Written, not run (TestEZ belongs to Jack/Studio, DEC-019). The Tool grant
	itself is a Studio check.
]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local BuildOrderRequest = require(ReplicatedStorage.Shared.UI.Pages.BobaPhone.BuildOrderRequest)
	local menuLoaded, Menu = pcall(require, ReplicatedStorage.Shared.Ordering.Menu)
	local orderSpecLoaded, OrderSpec = pcall(require, ReplicatedStorage.Shared.Ordering.OrderSpec)
	local serviceLoaded, BobaPhoneService = pcall(require, ServerScriptService.Server.Modules.BobaPhoneService)

	local function needMenu()
		assert(menuLoaded, "Shared.Ordering.Menu failed to load: " .. tostring(Menu))
	end

	local function launchTable()
		needMenu()
		return BuildOrderRequest.launchFoodTable(Menu)
	end

	describe("launchFoodTable", function()
		it("keeps only IsLaunchItem items", function()
			local food = launchTable()
			expect(food["Smoothies"]).to.equal(nil)
			expect(food["Teas"]).to.equal(nil)
			expect(food["Pastries"]).to.be.ok()
			local pastries = {}
			for itemKey in food["Pastries"].Items do
				table.insert(pastries, itemKey)
			end
			table.sort(pastries)
			expect(#pastries).to.equal(1)
			expect(pastries[1]).to.equal("Fudge Brownie")
			expect(food["Coffees"].Items["Espresso"]).to.be.ok()
		end)

		it("keeps the launch categories and drops TopMenuSpecial", function()
			local food = launchTable()
			expect(food["Boba Teas"].Items["Custom Boba"]).to.be.ok()
			expect(food["Boba Teas"].Items["Matcha Tea Boba"]).to.equal(nil)
			expect(food["TopMenuSpecial"]).to.equal(nil)
		end)

		it("filters Custom Boba Syrup Flavor to the launch choices", function()
			needMenu()
			local food = launchTable()
			local groups = food["Boba Teas"].Items["Custom Boba"].RequiredSelection
			local filtered = BuildOrderRequest.launchOptions(Menu, "Syrup Flavor", groups["Syrup Flavor"])
			local got = {}
			for optionKey in filtered do
				table.insert(got, optionKey)
			end
			table.sort(got)
			local want = {}
			for _, optionKey in Menu.LaunchChoices["Syrup Flavor"] do
				table.insert(want, optionKey)
			end
			table.sort(want)
			expect(#got).to.equal(#want)
			for i, optionKey in want do
				expect(got[i]).to.equal(optionKey)
			end
		end)

		it("leaves Taro, Espresso and Mango launchable (no level locks, D3)", function()
			needMenu()
			expect(Menu.IsLaunchItem("Boba Teas", "Custom Boba", { ["Syrup Flavor"] = "Taro" })).to.equal(true)
			expect(Menu.IsLaunchItem("Coffees", "Espresso")).to.equal(true)
			expect(Menu.IsLaunchItem("Boba Teas", "Custom Boba", { ["Syrup Flavor"] = "Mango" })).to.equal(true)
			local food = launchTable()
			expect(food["Coffees"].Items["Espresso"]).to.be.ok()
			expect(food["Boba Teas"].Items["Custom Boba"].RequiredSelection["Syrup Flavor"]["Taro"]).to.be.ok()
			expect(food["Boba Teas"].Items["Custom Boba"].RequiredSelection["Syrup Flavor"]["Mango"]).to.be.ok()
		end)
	end)

	describe("defaultInfoFor", function()
		it("gives Espresso Size Small with Iced and Sugar off", function()
			needMenu()
			local info = BuildOrderRequest.defaultInfoFor(Menu.FoodTable["Coffees"].Items["Espresso"])
			expect(info["Size"]).to.equal("Small")
			expect(info["Iced"]).to.equal(false)
			expect(info["Sugar"]).to.equal(false)
		end)

		it("gives Custom Boba Size Small only", function()
			needMenu()
			local info = BuildOrderRequest.defaultInfoFor(Menu.FoodTable["Boba Teas"].Items["Custom Boba"])
			expect(info["Size"]).to.equal("Small")
			expect(info["Iced"]).to.equal(nil)
		end)
	end)

	describe("cart", function()
		it("appends at most MAX_ITEMS entries and returns a new cart", function()
			needMenu()
			local itemData = Menu.FoodTable["Pastries"].Items["Fudge Brownie"]
			local cart = {}
			for _ = 1, 4 do
				cart = BuildOrderRequest.appendCapped(
					cart,
					BuildOrderRequest.cartEntry("Pastries", "Fudge Brownie", itemData, {})
				)
			end
			expect(#cart).to.equal(3)
			expect(BuildOrderRequest.MAX_ITEMS).to.equal(3)
		end)

		it("toRequest drops DefaultInfo and keeps Category, Item, CustomInfo", function()
			needMenu()
			local itemData = Menu.FoodTable["Coffees"].Items["Espresso"]
			local info = BuildOrderRequest.defaultInfoFor(itemData)
			local cart = { BuildOrderRequest.cartEntry("Coffees", "Espresso", itemData, info) }
			local request = BuildOrderRequest.toRequest(cart)
			expect(#request).to.equal(1)
			expect(request[1].Category).to.equal("Coffees")
			expect(request[1].Item).to.equal("Espresso")
			expect(request[1].CustomInfo["Size"]).to.equal("Small")
			expect(request[1].DefaultInfo).to.equal(nil)
		end)
	end)

	describe("round trip", function()
		it("phone-built requests resolve with OrderSpec.FromOrderItem", function()
			needMenu()
			assert(orderSpecLoaded, "Shared.Ordering.OrderSpec failed to load: " .. tostring(OrderSpec))
			local bobaData = Menu.FoodTable["Boba Teas"].Items["Custom Boba"]
			local bobaInfo = BuildOrderRequest.defaultInfoFor(bobaData)
			bobaInfo["Size"] = "Medium"
			bobaInfo["Syrup Flavor"] = "Taro"
			bobaInfo["Tapioca Flavor"] = "Normal"
			local espressoData = Menu.FoodTable["Coffees"].Items["Espresso"]
			local brownieData = Menu.FoodTable["Pastries"].Items["Fudge Brownie"]
			local cart = {
				BuildOrderRequest.cartEntry("Boba Teas", "Custom Boba", bobaData, bobaInfo),
				BuildOrderRequest.cartEntry(
					"Coffees",
					"Espresso",
					espressoData,
					BuildOrderRequest.defaultInfoFor(espressoData)
				),
				BuildOrderRequest.cartEntry(
					"Pastries",
					"Fudge Brownie",
					brownieData,
					BuildOrderRequest.defaultInfoFor(brownieData)
				),
			}
			local request = BuildOrderRequest.toRequest(cart)
			for _, orderItem in request do
				local spec, reason = OrderSpec.FromOrderItem(orderItem)
				assert(spec ~= nil, "FromOrderItem rejected " .. orderItem.Item .. ": " .. tostring(reason))
				expect(reason).to.equal(nil)
			end
		end)
	end)

	describe("prepareClone", function()
		it("destroys LocalScripts and marks the clone", function()
			assert(serviceLoaded, "BobaPhoneService failed to load: " .. tostring(BobaPhoneService))
			local tool = Instance.new("Tool")
			tool.Name = "Boba Phone"
			local legacy = Instance.new("LocalScript")
			legacy.Name = "Toggle"
			legacy.Parent = tool
			local nested = Instance.new("Folder")
			nested.Parent = tool
			local nestedScript = Instance.new("LocalScript")
			nestedScript.Parent = nested
			BobaPhoneService.prepareClone(tool)
			expect(tool:FindFirstChildWhichIsA("LocalScript", true)).to.equal(nil)
			expect(tool:GetAttribute("BobaPhone")).to.equal(true)
			expect(tool:GetAttribute("BuiltBy")).to.equal("Muse")
			expect(nested.Parent).to.equal(tool)
			tool:Destroy()
		end)
	end)
end

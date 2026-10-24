-- selene: allow(undefined_variable)
--[[
	RestockService.spec.luau
	TestEZ tests for Restocking system, stock configs, Unlimited Stock pass, and TrashCan discard.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local PassCatalog = require(ReplicatedStorage.Shared.Configuration.PassCatalog)
	local KitchenConfig = require(ReplicatedStorage.Shared.Configuration.KitchenConfig)
	local perkService = require(ServerScriptService.Server.Modules.PerkService)
	local kitchenService = require(ServerScriptService.Server.Modules.KitchenService)
	local progressionService = require(ServerScriptService.Server.Modules.ProgressionService)
	local trashService = require(ServerScriptService.Server.Modules.TrashService)

	local UNLIMITED_STOCK_PASS = 43707849

	local function makePlayer(userId: number): Player
		local folder = Instance.new("Folder")
		folder.Name = "TestPlayer_" .. userId
		local player = folder :: any
		player.UserId = userId
		player.Name = folder.Name

		local char = Instance.new("Model")
		char.Name = "Character"
		local humanoid = Instance.new("Humanoid")
		local animator = Instance.new("Animator")
		animator.Parent = humanoid
		humanoid.Parent = char
		char.Parent = folder
		player.Character = char

		local attributes = {}
		player.GetAttribute = function(_self, key: string)
			return attributes[key]
		end
		player.SetAttribute = function(_self, key: string, val: any)
			attributes[key] = val
		end

		return player
	end

	describe("Unlimited Stock pass configuration", function()
		it("should be defined in PassCatalog with ID 43707849", function()
			local entry = PassCatalog[UNLIMITED_STOCK_PASS]
			expect(entry).to.be.ok()
			expect(entry.Name).to.equal("Unlimited Stock")
			expect(table.find(entry.Perks, "UnlimitedStock")).to.be.ok()
			expect(entry.Listed).to.equal(true)
		end)

		it("should be resolved by PerkService:HasPerk", function()
			local player = makePlayer(1001)
			local ownedPasses = {}
			local origHasPass = perkService._hasPass
			perkService._hasPass = function(_self, _p, passId)
				return ownedPasses[passId] == true
			end

			expect(perkService:HasPerk(player, "UnlimitedStock")).to.equal(false)

			ownedPasses[UNLIMITED_STOCK_PASS] = true
			expect(perkService:HasPerk(player, "UnlimitedStock")).to.equal(true)

			perkService._hasPass = origHasPass
		end)
	end)

	describe("KitchenConfig Stock capacities", function()
		it("should return correct default stocks for all station types", function()
			expect(KitchenConfig.GetDefaultStock("Classic Milk Tea Syrup")).to.equal(4)
			expect(KitchenConfig.GetDefaultStock("Normal Tapioca")).to.equal(5)
			expect(KitchenConfig.GetDefaultStock("Food Display")).to.equal(10)
			expect(KitchenConfig.GetDefaultStock("Fruits Freezer")).to.equal(10)
			expect(KitchenConfig.GetDefaultStock("Ice Cream Freezer")).to.equal(10)
			expect(KitchenConfig.GetDefaultStock("Coffee Machine")).to.equal(3)
			expect(KitchenConfig.GetDefaultStock("Blender")).to.equal(3)
			expect(KitchenConfig.GetDefaultStock("Cup")).to.equal(8)
			expect(KitchenConfig.GetDefaultStock("Clear Cup")).to.equal(8)
			expect(KitchenConfig.GetDefaultStock("Mug")).to.equal(5)
			expect(KitchenConfig.GetDefaultStock("Milk")).to.equal(5)
			expect(KitchenConfig.GetDefaultStock("Sugar")).to.equal(5)
			expect(KitchenConfig.GetDefaultStock("Ice Machine")).to.equal(5)
			expect(KitchenConfig.GetDefaultStock("Green Tea Powder")).to.equal(5)
		end)
	end)

	describe("KitchenService Restocking Box flow", function()
		it("should give and throw away restock box", function()
			local player = makePlayer(2001)

			kitchenService:GiveRestockBox(player)
			expect(player:GetAttribute("Restocking")).to.equal(true)
			expect(player.Character:FindFirstChild("Box")).to.be.ok()

			kitchenService:ThrowAwayRestockBox(player)
			expect(player:GetAttribute("Restocking")).to.equal(nil)
			expect(player.Character:FindFirstChild("Box")).to.equal(nil)
		end)

		it("should replenish stock and award XP on RestockStation", function()
			local player = makePlayer(2002)
			kitchenService:GiveRestockBox(player)

			local model = Instance.new("Model")
			model.Name = "Normal Tapioca"
			local prompt = Instance.new("ProximityPrompt")
			prompt.Parent = model
			prompt:SetAttribute("DefaultStock", 5)
			prompt:SetAttribute("CurrentStock", 2)

			local xpAwarded = 0
			local origAddXp = progressionService.AddXp
			progressionService.AddXp = function(_self, p, amount)
				if p == player then
					xpAwarded += amount
				end
				return amount
			end

			local success = kitchenService:RestockStation(player, model, prompt)
			expect(success).to.equal(true)
			expect(prompt:GetAttribute("CurrentStock")).to.equal(5)
			expect(player:GetAttribute("Restocking")).to.equal(nil)
			expect(player.Character:FindFirstChild("Box")).to.equal(nil)
			expect(xpAwarded).to.equal(KitchenConfig.RESTOCK_XP_AWARD)

			-- Refuses to restock if station is already full
			kitchenService:GiveRestockBox(player)
			local secondSuccess = kitchenService:RestockStation(player, model, prompt)
			expect(secondSuccess).to.equal(false)

			progressionService.AddXp = origAddXp
		end)
	end)

	describe("TrashService Restock Box discard", function()
		it("should discard restock box when player is in restocking mode", function()
			local player = makePlayer(3001)
			kitchenService:GiveRestockBox(player)
			expect(player:GetAttribute("Restocking")).to.equal(true)

			local canPart = Instance.new("Part")
			trashService:_onTriggered(player, canPart)

			expect(player:GetAttribute("Restocking")).to.equal(nil)
			expect(player.Character:FindFirstChild("Box")).to.equal(nil)
		end)
	end)
end

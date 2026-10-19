-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	TreasureHuntService.spec.luau
	Unit tests for TreasureHuntConfig and TreasureHuntService (REVIVAL-001 M4-TREASURE-CHESTS).
]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local TreasureHuntConfig = require(ReplicatedStorage.Shared.Configuration.TreasureHuntConfig)
	local TreasureHuntService = require(ServerScriptService.Server.Modules.TreasureHuntService) :: any

	describe("TreasureHuntConfig.RollReward", function()
		it("always rolls BobaBucks within MIN_BOBABUCKS and MAX_BOBABUCKS", function()
			local rng = Random.new(12345)
			for _ = 1, 100 do
				local reward = TreasureHuntConfig.RollReward(rng)
				expect(reward.BobaBucks >= TreasureHuntConfig.MIN_BOBABUCKS).to.equal(true)
				expect(reward.BobaBucks <= TreasureHuntConfig.MAX_BOBABUCKS).to.equal(true)
			end
		end)

		it("awards only valid capsule names when a capsule is rolled", function()
			local rng = Random.new(67890)
			local capsuleCount = 0
			for _ = 1, 500 do
				local reward = TreasureHuntConfig.RollReward(rng)
				if reward.Capsule ~= nil then
					capsuleCount += 1
					local valid = reward.Capsule == "Regular Pet Capsule" or reward.Capsule == "Nametag Capsule"
					expect(valid).to.equal(true)
				end
			end
			expect(capsuleCount > 20).to.equal(true)
			expect(capsuleCount < 150).to.equal(true)
		end)

		it("supports deterministic pseudo-random source", function()
			local fakeRng = {
				NextInteger = function(_self, min, _max)
					return min
				end,
				NextNumber = function(_self)
					return 0.05 -- <= CAPSULE_CHANCE (0.15)
				end,
			} :: any

			local reward = TreasureHuntConfig.RollReward(fakeRng)
			expect(reward.BobaBucks).to.equal(TreasureHuntConfig.MIN_BOBABUCKS)
			expect(reward.Capsule ~= nil).to.equal(true)
		end)
	end)

	describe("Node selection", function()
		local testNodes: { BasePart } = {}

		beforeEach(function()
			testNodes = {}
			for i = 1, 6 do
				local part = Instance.new("Part")
				part.Name = "ChestNode_" .. i
				part.Size = Vector3.new(4, 1, 4)
				part.Position = Vector3.new(i * 10, 0, 0)
				table.insert(testNodes, part)
			end

			TreasureHuntService._nodes = {}
			TreasureHuntService._occupiedNodes = {}
			TreasureHuntService._activeChests = {}
			TreasureHuntService._chestToNode = {}
			TreasureHuntService._nodeToChest = {}
			TreasureHuntService._claimedChests = {}
			TreasureHuntService._started = true

			TreasureHuntService:InitNodes(testNodes)
		end)

		afterEach(function()
			for chest in TreasureHuntService._activeChests do
				chest:Destroy()
			end
			for _, part in testNodes do
				part:Destroy()
			end
			TreasureHuntService._nodes = {}
			TreasureHuntService._occupiedNodes = {}
			TreasureHuntService._activeChests = {}
			TreasureHuntService._chestToNode = {}
			TreasureHuntService._nodeToChest = {}
			TreasureHuntService._claimedChests = {}
			TreasureHuntService._started = false
		end)

		it("returns all nodes when none are occupied", function()
			local available = TreasureHuntService:GetAvailableNodes()
			expect(#available).to.equal(6)
		end)

		it("excludes occupied nodes in _occupiedNodes table", function()
			TreasureHuntService._occupiedNodes[testNodes[1]] = true
			TreasureHuntService._occupiedNodes[testNodes[3]] = true

			local available = TreasureHuntService:GetAvailableNodes()
			expect(#available).to.equal(4)
			expect(table.find(available, testNodes[1])).to.equal(nil)
			expect(table.find(available, testNodes[3])).to.equal(nil)
		end)

		it("excludes nodes with Occupied BoolValue set to true", function()
			local boolVal = Instance.new("BoolValue")
			boolVal.Name = "Occupied"
			boolVal.Value = true
			boolVal.Parent = testNodes[2]

			local available = TreasureHuntService:GetAvailableNodes()
			expect(#available).to.equal(5)
			expect(table.find(available, testNodes[2])).to.equal(nil)
		end)

		it("spawns chests up to MAX_ACTIVE_CHESTS capacity", function()
			TreasureHuntService:SpawnInitialChests()
			local activeCount = TreasureHuntService:GetActiveChestCount()
			expect(activeCount).to.equal(TreasureHuntConfig.MAX_ACTIVE_CHESTS)

			local extra = TreasureHuntService:SpawnNextChest()
			expect(extra).to.equal(nil)
			expect(TreasureHuntService:GetActiveChestCount()).to.equal(TreasureHuntConfig.MAX_ACTIVE_CHESTS)
		end)
	end)

	describe("Distance validation and claims", function()
		local node: BasePart
		local chest: Instance
		local fakePlayer: any
		local rootPart: BasePart

		local mockCurrencyCalls: { { player: any, currencyType: string, amount: number, reason: string? } } = {}
		local mockStatCalls: { { player: any, stat: string, amount: number? } } = {}
		local mockBadgeCalls: { { player: any, badgeId: number } } = {}
		local mockInventoryCalls: { { player: any, itemType: string, itemName: string } } = {}

		beforeEach(function()
			mockCurrencyCalls = {}
			mockStatCalls = {}
			mockBadgeCalls = {}
			mockInventoryCalls = {}

			TreasureHuntService._getService = function(_self, name: string)
				if name == "CurrencyService" then
					return {
						Modify = function(_s, p, ctype, amt, rsn)
							table.insert(
								mockCurrencyCalls,
								{ player = p, currencyType = ctype, amount = amt, reason = rsn }
							)
						end,
					}
				elseif name == "StatisticsService" then
					return {
						IncrementStat = function(_s, p, stat, amt)
							table.insert(mockStatCalls, { player = p, stat = stat, amount = amt })
						end,
					}
				elseif name == "BadgeService" then
					return {
						AwardBadge = function(_s, p, bid)
							table.insert(mockBadgeCalls, { player = p, badgeId = bid })
						end,
					}
				end
				return nil
			end

			TreasureHuntService._inventoryServer = {
				AddItem = function(_s, p, itype, iname)
					table.insert(mockInventoryCalls, { player = p, itemType = itype, itemName = iname })
				end,
			}

			node = Instance.new("Part")
			node.Position = Vector3.new(0, 0, 0)
			TreasureHuntService._nodes = { node }
			TreasureHuntService._occupiedNodes = {}
			TreasureHuntService._activeChests = {}
			TreasureHuntService._chestToNode = {}
			TreasureHuntService._nodeToChest = {}
			TreasureHuntService._claimedChests = {}
			TreasureHuntService._started = true

			chest = TreasureHuntService:SpawnChestAtNode(node)

			rootPart = Instance.new("Part")
			rootPart.Name = "HumanoidRootPart"
			rootPart.Position = Vector3.new(0, 0, 0)

			local character = Instance.new("Model")
			rootPart.Parent = character

			fakePlayer = {
				Name = "TestPlayer",
				UserId = 123456,
				Character = character,
			}
		end)

		afterEach(function()
			if chest and chest.Parent then
				chest:Destroy()
			end
			if node and node.Parent then
				node:Destroy()
			end
			if fakePlayer.Character then
				fakePlayer.Character:Destroy()
			end
			TreasureHuntService._getService = function(_self, name: string)
				return require(ServerScriptService.Server.Modules[name])
			end
			TreasureHuntService._inventoryServer = nil
			TreasureHuntService._randomSource = Random.new()
		end)

		it("rejects triggers when player is beyond maximum activation distance", function()
			rootPart.Position = Vector3.new(0, 0, 25)

			local success = TreasureHuntService:ClaimChest(fakePlayer, chest)
			expect(success).to.equal(false)
			expect(#mockCurrencyCalls).to.equal(0)
			expect(#mockStatCalls).to.equal(0)
			expect(#mockBadgeCalls).to.equal(0)
			expect(chest.Parent ~= nil).to.equal(true)
		end)

		it("accepts triggers when player is within range and awards currency, stats, and badge", function()
			rootPart.Position = Vector3.new(0, 0, 5)

			local success = TreasureHuntService:ClaimChest(fakePlayer, chest)
			expect(success).to.equal(true)
			expect(#mockCurrencyCalls).to.equal(1)
			expect(mockCurrencyCalls[1].currencyType).to.equal("BobaBucks")
			expect(mockCurrencyCalls[1].amount >= TreasureHuntConfig.MIN_BOBABUCKS).to.equal(true)
			expect(mockCurrencyCalls[1].reason).to.equal("TreasureChest")

			expect(#mockStatCalls).to.equal(1)
			expect(mockStatCalls[1].stat).to.equal("TreasureChestsFound")
			expect(mockStatCalls[1].amount).to.equal(1)

			expect(#mockBadgeCalls).to.equal(1)
			expect(mockBadgeCalls[1].badgeId).to.equal(TreasureHuntConfig.BADGE_ID)

			expect(chest.Parent).to.equal(nil)
			expect(TreasureHuntService._occupiedNodes[node]).to.equal(nil)
		end)

		it("awards a capsule when rolled", function()
			TreasureHuntService._randomSource = {
				NextInteger = function(_self, min, _max)
					return min
				end,
				NextNumber = function(_self)
					return 0.05 -- guarantees capsule drop
				end,
			} :: any

			rootPart.Position = Vector3.new(0, 0, 0)
			local success = TreasureHuntService:ClaimChest(fakePlayer, chest)
			expect(success).to.equal(true)
			expect(#mockInventoryCalls).to.equal(1)
			expect(mockInventoryCalls[1].player).to.equal(fakePlayer)
			expect(mockInventoryCalls[1].itemType).to.equal("Capsules")
			expect(mockInventoryCalls[1].itemName ~= nil).to.equal(true)
		end)

		it("prevents duplicate claims on the same chest", function()
			rootPart.Position = Vector3.new(0, 0, 2)

			local first = TreasureHuntService:ClaimChest(fakePlayer, chest)
			local second = TreasureHuntService:ClaimChest(fakePlayer, chest)

			expect(first).to.equal(true)
			expect(second).to.equal(false)
			expect(#mockCurrencyCalls).to.equal(1)
		end)
	end)
end

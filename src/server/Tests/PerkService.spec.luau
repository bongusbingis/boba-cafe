-- selene: allow(undefined_variable)
--[[
	PerkService.spec.luau
	TestEZ tests for PassCatalog, Perks, PerkService and the XP perk in ProgressionService.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Knit = require(ReplicatedStorage.Packages.Knit)
	local PassCatalog = require(ReplicatedStorage.Shared.Configuration.PassCatalog)
	local PerkConfig = require(ReplicatedStorage.Shared.Configuration.Perks)
	local service = require(ServerScriptService.Server.Modules.PerkService)
	local progression = require(ServerScriptService.Server.Modules.ProgressionService)

	local BARISTA = 6202153
	local SENIOR_BARISTA = 6202144
	local KITCHEN_LEADER = 15243046

	local function makePlayer(userId: number)
		return { UserId = userId, Name = "Player_" .. userId }
	end

	local ownedPasses: { [number]: boolean }
	local originalHasPass = service._hasPass

	beforeEach(function()
		ownedPasses = {}
		service._hasPass = function(_self, _player, passId)
			return ownedPasses[passId] == true
		end
	end)

	afterEach(function()
		service._hasPass = originalHasPass
	end)

	describe("PassCatalog", function()
		it("should not contain deferred passes", function()
			for _, deferredId in { 7564248, 7564221, 8022138, 43707849 } do
				expect(PassCatalog[deferredId]).to.equal(nil)
			end
		end)

		it("should map Barista to the 25% family and Kitchen Leader to 50%", function()
			expect(table.find(PassCatalog[BARISTA].Perks, "TipBoost25")).to.be.ok()
			expect(table.find(PassCatalog[BARISTA].Perks, "XpBoost25")).to.be.ok()
			expect(table.find(PassCatalog[KITCHEN_LEADER].Perks, "TipBoost50")).to.be.ok()
			expect(table.find(PassCatalog[KITCHEN_LEADER].Perks, "XpBoost50")).to.be.ok()
		end)

		it("should carry display data, perks, and sale flags in one entry", function()
			local rainbow = PassCatalog[12385796]
			expect(rainbow.Name).to.equal("Rainbow Pack")
			expect(table.find(rainbow.Perks, "RainbowPack")).to.be.ok()
			expect(rainbow.Description).to.equal("Stand out with a rainbow nametag, emoji, and trail!")
			expect(rainbow.Listed).to.equal(true)
			expect(rainbow.Legacy).to.equal(false)

			local barista = PassCatalog[BARISTA]
			expect(barista.Description).to.be.ok()
			expect(barista.Icon).to.be.ok()
			expect(barista.Rank).to.equal(8)
		end)

		it("should keep display-only passes delisted with empty perks", function()
			for _, passId in { 29083693, 219651161 } do
				local entry = PassCatalog[passId]
				expect(entry).to.be.ok()
				expect(#entry.Perks).to.equal(0)
				expect(entry.Listed).to.equal(false)
			end
		end)

		it("should shape every entry with Name, Perks, Listed, and Legacy", function()
			local count = 0
			for _, entry in PassCatalog do
				count += 1
				expect(typeof(entry.Name)).to.equal("string")
				expect(typeof(entry.Perks)).to.equal("table")
				expect(typeof(entry.Listed)).to.equal("boolean")
				expect(typeof(entry.Legacy)).to.equal("boolean")
			end
			expect(count > 0).to.equal(true)
		end)
	end)

	describe("PerkService", function()
		it("should return 0 with no passes", function()
			local player = makePlayer(1)
			expect(service:GetFamilyBonus(player, "Tip")).to.equal(0)
			expect(service:HasPerk(player, "TipBoost25")).to.equal(false)
		end)

		it("should give an owner of an unlisted pass its perks", function()
			local player = makePlayer(2)
			ownedPasses[SENIOR_BARISTA] = true
			expect(PassCatalog[SENIOR_BARISTA].Listed).to.equal(false)
			expect(service:HasPerk(player, "XpBoost25")).to.equal(true)
			expect(service:GetFamilyBonus(player, "Xp")).to.equal(0.25)
		end)

		it("should take the highest value in a family, not the sum", function()
			local player = makePlayer(3)
			ownedPasses[BARISTA] = true
			ownedPasses[KITCHEN_LEADER] = true
			expect(service:GetFamilyBonus(player, "Tip")).to.equal(0.5)
			expect(service:GetFamilyBonus(player, "Xp")).to.equal(0.5)
		end)
	end)

	describe("Pet tip bonus table", function()
		it("should hold the approved values", function()
			expect(PerkConfig.PetTipBonus.Basic).to.equal(0.02)
			expect(PerkConfig.PetTipBonus.Rare).to.equal(0.04)
			expect(PerkConfig.PetTipBonus.Epic).to.equal(0.07)
			expect(PerkConfig.PetTipBonus.Legendary).to.equal(0.10)
		end)

		it("should give 0 for an unknown tier", function()
			expect(PerkConfig.PetTipBonus["Mythic"]).to.equal(nil)
			expect(PerkConfig.PetTipBonus["Uncommon"]).to.equal(nil)
		end)
	end)

	describe("ProgressionService XP perk", function()
		local originalGetService = Knit.GetService

		afterEach(function()
			Knit.GetService = originalGetService
		end)

		it("should multiply serve XP by 1 + the Xp family bonus", function()
			local stored = {}
			local proxy = { Data = { Level = 1, XP = 0 } }
			function proxy:SetValue(path, value)
				stored[path[1]] = value
			end
			local fakeData = {
				GetDataAsync = function()
					local promise = {}
					function promise:andThen(fn)
						fn(proxy)
						return self
					end
					function promise:catch()
						return self
					end
					return promise
				end,
			}
			local fakePerks = {
				GetFamilyBonus = function(_, _player, family)
					return if family == "Xp" then 0.5 else 0
				end,
			}
			Knit.GetService = function(name)
				if name == "DataService" then
					return fakeData
				elseif name == "PerkService" then
					return fakePerks
				end
				return originalGetService(name)
			end

			progression._state[makePlayer(9) :: any] = nil
			local player = makePlayer(9) :: any
			local granted = progression:AddXp(player, 20)
			expect(stored.XP).to.equal(30)
			expect(granted).to.equal(30)
			expect(progression:AddXp(player, 0)).to.equal(0)
			progression._state[player] = nil
			progression._shiftXp[player] = nil
		end)
	end)
	describe("Tip bonus", function()
		local originalGetService = Knit.GetService
		local petService = require(ServerScriptService.Server.Modules.PetService) :: any

		afterEach(function()
			Knit.GetService = originalGetService
			petService._equipped[501] = nil
		end)

		it("should return the best equipped pet tier bonus", function()
			local player = makePlayer(501) :: any
			expect(petService:GetBestTipBonus(player)).to.equal(0)
			petService._equipped[501] = { { Tier = "Basic" }, { Tier = "Epic" }, { Tier = "Rare" } }
			expect(petService:GetBestTipBonus(player)).to.equal(0.07)
			for tier, value in { Basic = 0.02, Rare = 0.04, Epic = 0.07, Legendary = 0.10 } do
				petService._equipped[501] = { { Tier = tier } }
				expect(petService:GetBestTipBonus(player)).to.equal(value)
			end
			petService._equipped[501] = { { Tier = "Uncommon" }, { Tier = "Mystery" } }
			expect(petService:GetBestTipBonus(player)).to.equal(0)
		end)

		it("should take the max of pass and pet, not the sum", function()
			local player = makePlayer(501) :: any
			Knit.GetService = function(name)
				if name == "PetService" then
					return {
						GetBestTipBonus = function()
							return 0.10
						end,
					}
				end
				return originalGetService(name)
			end
			expect(service:GetTipBonus(player)).to.equal(0.10)
			ownedPasses[BARISTA] = true
			expect(service:GetTipBonus(player)).to.equal(0.25)
			ownedPasses[KITCHEN_LEADER] = true
			expect(service:GetTipBonus(player)).to.equal(0.5)
		end)
	end)

	describe("Storage multiplier (Double Storage)", function()
		local DOUBLE_STORAGE = 14067346

		it("should be 1 with no refresh", function()
			expect(service:GetStorageMultiplier(makePlayer(701) :: any)).to.equal(1)
		end)

		it("should be 2 for an owner, and 1 again after the pass is released", function()
			local player = { UserId = 702, Name = "Player_702", Parent = {} } :: any
			ownedPasses[DOUBLE_STORAGE] = true
			service:RefreshStorageMultiplier(player)
			expect(service:GetStorageMultiplier(player)).to.equal(PerkConfig.StorageMultiplier)
			expect(service:GetStorageMultiplier(player)).to.equal(2)
			ownedPasses[DOUBLE_STORAGE] = nil
			service:RefreshStorageMultiplier(player)
			expect(service:GetStorageMultiplier(player)).to.equal(1)
			service:PlayerRemoving(player)
		end)

		it("should clear the entry on PlayerRemoving", function()
			local player = { UserId = 703, Name = "Player_703", Parent = {} } :: any
			ownedPasses[DOUBLE_STORAGE] = true
			service:RefreshStorageMultiplier(player)
			service:PlayerRemoving(player)
			expect(service._storageMultiplier[player]).to.equal(nil)
			expect(service:GetStorageMultiplier(player)).to.equal(1)
		end)

		it("should not write an entry for a departed player", function()
			local player = { UserId = 704, Name = "Player_704", Parent = nil } :: any
			ownedPasses[DOUBLE_STORAGE] = true
			service:RefreshStorageMultiplier(player)
			expect(service._storageMultiplier[player]).to.equal(nil)
		end)
	end)

	describe("Tip remainder carry", function()
		it("should carry the fraction and pay whole BB only", function()
			local player = makePlayer(601) :: any
			-- 2% of 10 BB = 0.2 per serve: the 5th serve pays 1 BB.
			local total = 0
			for i = 1, 5 do
				local extra = service:TakeTipExtra(player, 10, 0.02)
				if i < 5 then
					expect(extra).to.equal(0)
				end
				total += extra
			end
			expect(total).to.equal(1)
			expect(service:TakeTipExtra(player, 10, 0.02)).to.equal(0)
			service:PlayerRemoving(player)
			expect(service._tipRemainder[player]).to.equal(nil)
		end)

		it("should pay floor of a large boost and keep the rest", function()
			local player = makePlayer(602) :: any
			expect(service:TakeTipExtra(player, 15, 0.5)).to.equal(7)
			expect(service:TakeTipExtra(player, 15, 0.5)).to.equal(8)
			expect(service:TakeTipExtra(player, 15, 0)).to.equal(0)
			service:PlayerRemoving(player)
		end)
	end)
end

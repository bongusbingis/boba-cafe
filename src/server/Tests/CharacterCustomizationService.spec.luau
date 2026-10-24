-- selene: allow(undefined_variable)
--[[
	CharacterCustomizationService.spec.luau
	Unit tests for uniform & costume equipping, clock-in mandate enforcement, and costume grants.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Packages = ReplicatedStorage:WaitForChild("Packages")

	local Knit = require(Packages.Knit)
	local CharacterCustomizationService = require(ServerScriptService.Server.Modules.CharacterCustomizationService)
	local GamepassUtil = require(ReplicatedStorage.Shared.Utility.GamepassUtil)

	local STAR_EMPLOYEE_PASS_ID = 219650999

	local function makeFakePlayer(userId: number): Player
		local folder = Instance.new("Folder")
		folder.Name = "TestPlayer_" .. userId
		local player = folder :: any
		player.UserId = userId
		player.Name = folder.Name
		player.DisplayName = "CustomizationTester"

		local char = Instance.new("Model")
		char.Name = "Character"
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = char
		char.PrimaryPart = root
		char.Parent = workspace
		player.Character = char

		return player
	end

	describe("CharacterCustomizationService", function()
		local fakePlayer: Player
		local fakeProfile: any
		local isClockedIn = false
		local ownsStarEmployee = false
		local originalPlayerOwns: any
		local originalGetData: any

		beforeEach(function()
			fakePlayer = makeFakePlayer(888801)
			fakeProfile = {
				Data = {
					Character = {
						EquippedUniform = "Default",
						OwnedCostumes = {},
						EquippedCostume = nil,
					},
				},
			}

			isClockedIn = false
			ownsStarEmployee = false

			originalPlayerOwns = GamepassUtil.PlayerOwnsPassAsync;
			(GamepassUtil :: any).PlayerOwnsPassAsync = function(_self, _player, passId)
				if passId == STAR_EMPLOYEE_PASS_ID then
					return ownsStarEmployee
				end
				return false
			end

			CharacterCustomizationService._shift = {
				IsClockedIn = function(_self, _p)
					return isClockedIn
				end,
			}

			-- Mock DataService in Knit
			local mockDataService = {
				GetDataAsync = function(_self, _player)
					return {
						timeout = function(self)
							return self
						end,
						await = function(_self)
							return true, fakeProfile
						end,
					}
				end,
				GetProfile = function(_self, _player)
					return fakeProfile
				end,
			}
			originalGetData = Knit.GetService
			Knit.GetService = function(name: string): any
				if name == "DataService" then
					return mockDataService
				elseif name == "ShiftService" then
					return CharacterCustomizationService._shift
				elseif name == "UniformService" then
					return {
						_apply = function() end,
						_restore = function() end,
					}
				end
				return originalGetData(name)
			end
		end)

		afterEach(function()
			(GamepassUtil :: any).PlayerOwnsPassAsync = originalPlayerOwns
			Knit.GetService = originalGetData
			if fakePlayer.Character then
				fakePlayer.Character:Destroy()
			end
			fakePlayer:Destroy()
		end)

		it("should return the default character customization state", function()
			local state = CharacterCustomizationService:GetCharacterState(fakePlayer)
			expect(state.EquippedUniform).to.equal("Default")
			expect(state.EquippedCostume).to.equal(nil)
			expect(state.OwnedCostumes).to.be.ok()
		end)

		it("should equip Default uniform successfully", function()
			fakeProfile.Data.Character.EquippedUniform = nil
			local ok, err = CharacterCustomizationService:EquipUniform(fakePlayer, "Default")
			expect(ok).to.equal(true)
			expect(err).to.equal(nil)
			expect(fakeProfile.Data.Character.EquippedUniform).to.equal("Default")
		end)

		it("should reject equipping StarEmployee uniform if gamepass is not owned", function()
			ownsStarEmployee = false
			local ok, err = CharacterCustomizationService:EquipUniform(fakePlayer, "StarEmployee")
			expect(ok).to.equal(false)
			expect(err).to.equal("GamepassRequired")
		end)

		it("should allow equipping StarEmployee uniform if gamepass is owned", function()
			ownsStarEmployee = true
			local ok, err = CharacterCustomizationService:EquipUniform(fakePlayer, "StarEmployee")
			expect(ok).to.equal(true)
			expect(err).to.equal(nil)
			expect(fakeProfile.Data.Character.EquippedUniform).to.equal("StarEmployee")
		end)

		it("should block unequipping uniform while clocked in", function()
			isClockedIn = true
			local ok, err = CharacterCustomizationService:EquipUniform(fakePlayer, nil)
			expect(ok).to.equal(false)
			expect(err).to.equal("UniformMandatoryWhileClockedIn")
			expect(fakeProfile.Data.Character.EquippedUniform).to.equal("Default")
		end)

		it("should allow unequipping uniform when not clocked in", function()
			isClockedIn = false
			local ok, err = CharacterCustomizationService:EquipUniform(fakePlayer, nil)
			expect(ok).to.equal(true)
			expect(err).to.equal(nil)
			expect(fakeProfile.Data.Character.EquippedUniform).to.equal(nil)
		end)

		it("should reject equipping unowned costume", function()
			local ok, err = CharacterCustomizationService:EquipCostume(fakePlayer, "BobaCostume")
			expect(ok).to.equal(false)
			expect(err).to.equal("CostumeNotOwned")
			expect(fakeProfile.Data.Character.EquippedCostume).to.equal(nil)
		end)

		it("should grant costume and allow equipping it", function()
			local grantOk, grantErr = CharacterCustomizationService:GrantCostume(fakePlayer, "BobaCostume")
			expect(grantOk).to.equal(true)
			expect(grantErr).to.equal(nil)
			expect(fakeProfile.Data.Character.OwnedCostumes["BobaCostume"]).to.equal(true)

			local equipOk, equipErr = CharacterCustomizationService:EquipCostume(fakePlayer, "BobaCostume")
			expect(equipOk).to.equal(true)
			expect(equipErr).to.equal(nil)
			expect(fakeProfile.Data.Character.EquippedCostume).to.equal("BobaCostume")

			-- Unequip costume
			local unequipOk = CharacterCustomizationService:EquipCostume(fakePlayer, nil)
			expect(unequipOk).to.equal(true)
			expect(fakeProfile.Data.Character.EquippedCostume).to.equal(nil)
		end)
	end)
end

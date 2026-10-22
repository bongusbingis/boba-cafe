-- selene: allow(undefined_variable)
--[[
	UniformService.spec.luau
	Tests for UniformService uniform resolution and application.
--]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local UniformService = require(ServerScriptService.Server.Modules.UniformService)
	local GamepassUtil = require(ReplicatedStorage.Shared.Utility.GamepassUtil)

	local STAR_EMPLOYEE = 219650999

	describe("UniformService", function()
		it("should resolve Default and StarEmployee uniform templates from SharedStorage.Uniforms", function()
			local defaultShirt = UniformService:_template("Default", "Shirt")
			local defaultPants = UniformService:_template("Default", "Pants")
			local starShirt = UniformService:_template("StarEmployee", "Shirt")
			local starPants = UniformService:_template("StarEmployee", "Pants")

			expect(defaultShirt).to.be.ok()
			expect(defaultPants).to.be.ok()
			expect(starShirt).to.be.ok()
			expect(starPants).to.be.ok()
		end)

		it("should apply Default uniform when clocked in without Star Employee", function()
			local fakeChar = Instance.new("Model")
			local shirt = Instance.new("Shirt")
			shirt.ShirtTemplate = "rbxassetid://1111"
			shirt.Parent = fakeChar

			local pants = Instance.new("Pants")
			pants.PantsTemplate = "rbxassetid://2222"
			pants.Parent = fakeChar

			local fakePlayer = {
				Character = fakeChar,
				UserId = 999901,
			}

			local isClockedIn = true
			UniformService._shift = {
				IsClockedIn = function(_self, _p)
					return isClockedIn
				end,
			}

			local originalPlayerOwns = GamepassUtil.PlayerOwnsPassAsync;
			(GamepassUtil :: any).PlayerOwnsPassAsync = function(_self, _player, _passId)
				return false
			end

			UniformService:_apply(fakePlayer :: any)

			local defaultShirt = UniformService:_template("Default", "Shirt")
			local defaultPants = UniformService:_template("Default", "Pants")

			expect(shirt.ShirtTemplate).to.equal(defaultShirt)
			expect(pants.PantsTemplate).to.equal(defaultPants)

			-- Restores on clock out
			UniformService:_restore(fakePlayer :: any)
			expect(shirt.ShirtTemplate).to.equal("rbxassetid://1111")
			expect(pants.PantsTemplate).to.equal("rbxassetid://2222")
;
			(GamepassUtil :: any).PlayerOwnsPassAsync = originalPlayerOwns
			fakeChar:Destroy()
		end)

		it("should apply StarEmployee uniform when clocked in with Star Employee", function()
			local fakeChar = Instance.new("Model")
			local shirt = Instance.new("Shirt")
			shirt.ShirtTemplate = "rbxassetid://1111"
			shirt.Parent = fakeChar

			local pants = Instance.new("Pants")
			pants.PantsTemplate = "rbxassetid://2222"
			pants.Parent = fakeChar

			local fakePlayer = {
				Character = fakeChar,
				UserId = 999902,
			}

			local isClockedIn = true
			UniformService._shift = {
				IsClockedIn = function(_self, _p)
					return isClockedIn
				end,
			}

			local originalPlayerOwns = GamepassUtil.PlayerOwnsPassAsync;
			(GamepassUtil :: any).PlayerOwnsPassAsync = function(_self, _player, passId)
				return passId == STAR_EMPLOYEE
			end

			UniformService:_apply(fakePlayer :: any)

			local starShirt = UniformService:_template("StarEmployee", "Shirt")
			local starPants = UniformService:_template("StarEmployee", "Pants")

			expect(shirt.ShirtTemplate).to.equal(starShirt)
			expect(pants.PantsTemplate).to.equal(starPants)

			-- Restores on clock out
			UniformService:_restore(fakePlayer :: any)
			expect(shirt.ShirtTemplate).to.equal("rbxassetid://1111")
			expect(pants.PantsTemplate).to.equal("rbxassetid://2222")
;
			(GamepassUtil :: any).PlayerOwnsPassAsync = originalPlayerOwns
			fakeChar:Destroy()
		end)

		it("should leave the outfit alone for Uniform Remover owners with the toggle on", function()
			local fakeChar = Instance.new("Model")
			local shirt = Instance.new("Shirt")
			shirt.ShirtTemplate = "rbxassetid://1111"
			shirt.Parent = fakeChar

			local fakePlayer = {
				Character = fakeChar,
				UserId = 999903,
			}

			UniformService._shift = {
				IsClockedIn = function(_self, _p)
					return true
				end,
			}
			local keeps = true
			UniformService._passSettings = {
				IsUniformRemoverActive = function(_self, _p)
					return keeps
				end,
			}

			UniformService:_apply(fakePlayer :: any)
			expect(shirt.ShirtTemplate).to.equal("rbxassetid://1111")

			-- Toggle off: the cafe uniform applies again.
			keeps = false
			local originalPlayerOwns = GamepassUtil.PlayerOwnsPassAsync;
			(GamepassUtil :: any).PlayerOwnsPassAsync = function()
				return false
			end
			UniformService:_apply(fakePlayer :: any)
			expect(shirt.ShirtTemplate).to.equal(UniformService:_template("Default", "Shirt"))

			UniformService:_restore(fakePlayer :: any);
			(GamepassUtil :: any).PlayerOwnsPassAsync = originalPlayerOwns
			UniformService._passSettings = nil
			fakeChar:Destroy()
		end)
	end)
end

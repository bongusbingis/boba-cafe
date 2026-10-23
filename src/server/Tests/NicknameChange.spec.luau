-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	NicknameChange.spec.luau
	Unit tests for RP Nickname Change paywall, validation, and pending cache.
]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")

	local ProductIds = require(ReplicatedStorage.Shared.Configuration.ProductIds)
	local CosmeticsService = require(ServerScriptService.Server.Modules.CosmeticsService) :: any

	describe("Product ID Configuration", function()
		it("has ChangeNickname configured as 1152995517", function()
			expect(ProductIds.ChangeNickname).to.equal(1152995517)
		end)
	end)

	describe("Pending Nickname Cache", function()
		local fakePlayer = { UserId = 999999123, Name = "TestPlayer" } :: any

		afterEach(function()
			CosmeticsService:ClearPendingNickname(fakePlayer)
		end)

		it("stores and retrieves pending nickname", function()
			expect(CosmeticsService:GetPendingNickname(fakePlayer)).to.equal(nil)

			CosmeticsService:SetPendingNickname(fakePlayer, "BobaMaster")
			expect(CosmeticsService:GetPendingNickname(fakePlayer)).to.equal("BobaMaster")

			CosmeticsService:ClearPendingNickname(fakePlayer)
			expect(CosmeticsService:GetPendingNickname(fakePlayer)).to.equal(nil)
		end)
	end)

	describe("Input Validation", function()
		local fakePlayer = { UserId = 999999456, Name = "TestPlayer2" } :: any

		it("rejects non-string input", function()
			local res = CosmeticsService:RequestNicknameChange(fakePlayer, 12345)
			expect(res.Success).to.equal(false)
			expect(res.Error).to.equal("Invalid nickname input.")
		end)

		it("rejects empty or whitespace-only nicknames", function()
			local res = CosmeticsService:RequestNicknameChange(fakePlayer, "   ")
			expect(res.Success).to.equal(false)
			expect(res.Error).to.equal("Nickname cannot be empty.")
		end)

		it("rejects nicknames longer than 15 characters", function()
			local res = CosmeticsService:RequestNicknameChange(fakePlayer, "ThisNameIsWayTooLongForBoba")
			expect(res.Success).to.equal(false)
			expect(res.Error).to.equal("Nickname must be 15 characters or less.")
		end)
	end)
end

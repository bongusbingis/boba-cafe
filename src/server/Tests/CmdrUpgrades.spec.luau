-- TestEZ injects describe/it/expect as globals.
--# selene: allow(undefined_variable)
--[[
	CmdrUpgrades.spec.luau
	Tests for the Upgrades & Ratings Cmdr commands (SetUpgrade, SetRating, ResetUpgrades).
]]

return function()
	local ServerScriptService = game:GetService("ServerScriptService")
	local Workspace = game:GetService("Workspace")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local CmdrFolder = ServerScriptService.Server.Cmdr
	local UpgradesFolder = CmdrFolder.Commands.Upgrades

	local SetUpgradeDef = require(UpgradesFolder.SetUpgrade) :: any
	local SetUpgradeServer = require(UpgradesFolder.SetUpgradeServer) :: any
	local SetRatingDef = require(UpgradesFolder.SetRating) :: any
	local SetRatingServer = require(UpgradesFolder.SetRatingServer) :: any
	local ResetUpgradesDef = require(UpgradesFolder.ResetUpgrades) :: any
	local ResetUpgradesServer = require(UpgradesFolder.ResetUpgradesServer) :: any

	local CafeUpgradeConfig = require(ReplicatedStorage.Shared.Configuration.CafeUpgradeConfig)

	local okUpg, CafeUpgradeService = pcall(function()
		return require(ServerScriptService.Server.Modules.CafeUpgradeService) :: any
	end)
	local okRat, CafeRatingService = pcall(function()
		return require(ServerScriptService.Server.Modules.CafeRatingService) :: any
	end)

	local mockContext = { Executor = nil }

	describe("Command Definitions", function()
		it("SetUpgrade has valid structure", function()
			expect(SetUpgradeDef.Name).to.equal("set-upgrade")
			expect(SetUpgradeDef.Group).to.equal("Upgrades")
			expect(typeof(SetUpgradeDef.Description)).to.equal("string")
			expect(#SetUpgradeDef.Args).to.equal(2)
			expect(SetUpgradeDef.Args[1].Type).to.equal("upgradeType")
			expect(SetUpgradeDef.Args[2].Type).to.equal("integer")
		end)

		it("SetRating has valid structure", function()
			expect(SetRatingDef.Name).to.equal("set-rating")
			expect(SetRatingDef.Group).to.equal("Upgrades")
			expect(typeof(SetRatingDef.Description)).to.equal("string")
			expect(#SetRatingDef.Args).to.equal(1)
			expect(SetRatingDef.Args[1].Type).to.equal("number")
		end)

		it("ResetUpgrades has valid structure", function()
			expect(ResetUpgradesDef.Name).to.equal("reset-upgrades")
			expect(ResetUpgradesDef.Group).to.equal("Upgrades")
			expect(typeof(ResetUpgradesDef.Description)).to.equal("string")
			expect(#ResetUpgradesDef.Args).to.equal(0)
		end)
	end)

	describe("SetUpgradeServer", function()
		it("rejects unknown upgrades", function()
			local result = SetUpgradeServer(mockContext, "InvalidUpgrade", 1)
			expect(string.find(result, "Unknown upgrade") ~= nil).to.equal(true)
		end)

		it("rejects negative levels", function()
			local result = SetUpgradeServer(mockContext, "Plants", -1)
			expect(string.find(result, "Invalid level") ~= nil).to.equal(true)
		end)

		it("rejects levels exceeding max", function()
			local result = SetUpgradeServer(mockContext, "Plants", 99)
			expect(string.find(result, "Invalid level") ~= nil).to.equal(true)
		end)

		it("sets level and attributes for valid input", function()
			if not okUpg or not CafeUpgradeService then
				return
			end
			local result = SetUpgradeServer(mockContext, "TipJar", 2)
			expect(result).to.equal("Set upgrade TipJar to level 2.")
			expect(CafeUpgradeService._levels["TipJar"]).to.equal(2)
			expect(Workspace:GetAttribute(CafeUpgradeConfig.TIP_JAR_LEVEL_ATTRIBUTE)).to.equal(2)
		end)
	end)

	describe("ResetUpgradesServer", function()
		it("resets all upgrades and TipJar attribute to 0", function()
			if not okUpg or not CafeUpgradeService then
				return
			end
			SetUpgradeServer(mockContext, "Plants", 1)
			SetUpgradeServer(mockContext, "TipJar", 1)
			local result = ResetUpgradesServer(mockContext)
			expect(result).to.equal("All cafe upgrades reset to level 0.")
			expect(CafeUpgradeService._levels["Plants"]).to.equal(0)
			expect(CafeUpgradeService._levels["TipJar"]).to.equal(0)
			expect(Workspace:GetAttribute(CafeUpgradeConfig.TIP_JAR_LEVEL_ATTRIBUTE)).to.equal(0)
		end)
	end)

	describe("SetRatingServer", function()
		it("sets rating and workspace attribute from stars", function()
			if not okRat or not CafeRatingService then
				return
			end
			local result = SetRatingServer(mockContext, 4.5)
			expect(result).to.equal("Cafe rating set to 4.5 stars.")
			expect(CafeRatingService._rating).to.equal(90)
			expect(Workspace:GetAttribute("CafeRating")).to.equal(90)
		end)

		it("sets rating from 0-100 percentage", function()
			if not okRat or not CafeRatingService then
				return
			end
			local result = SetRatingServer(mockContext, 80)
			expect(result).to.equal("Cafe rating set to 4.0 stars.")
			expect(CafeRatingService._rating).to.equal(80)
			expect(Workspace:GetAttribute("CafeRating")).to.equal(80)
		end)
	end)
end

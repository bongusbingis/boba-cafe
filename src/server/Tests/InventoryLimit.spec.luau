-- selene: allow(undefined_variable)
--[[
	InventoryLimit.spec.luau
	Pure TestEZ cases for Utility.GetInventoryLimit and the Double Storage multiplier
	(REVIVAL-001 M3-REM-D, DEC-028 E20, DEC-042).
--]]

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Utility = require(ReplicatedStorage.Shared.Inventory.Utility)
	local InventoryLimits = require(ReplicatedStorage.Shared.Configuration.InventoryLimits)

	describe("GetInventoryLimit", function()
		it("should return the base Storage limit with no multiplier", function()
			expect(Utility.GetInventoryLimit("Storage", "Capsules")).to.equal(InventoryLimits.Storage.Capsules)
		end)

		it("should double Storage with multiplier 2", function()
			for _, itemType in { "Nametags", "Pets", "Particles", "Capsules" } do
				expect(Utility.GetInventoryLimit("Storage", itemType :: any, 2)).to.equal(
					InventoryLimits.Storage[itemType] * 2
				)
			end
		end)

		it("should never multiply Equipped", function()
			expect(Utility.GetInventoryLimit("Equipped", "Pets", 2)).to.equal(InventoryLimits.Equipped.Pets)
			expect(Utility.GetInventoryLimit("Equipped", "Particles", 2)).to.equal(InventoryLimits.Equipped.Particles)
		end)

		it("should ignore a multiplier below 1 or a non-number", function()
			local base = InventoryLimits.Storage.Capsules
			expect(Utility.GetInventoryLimit("Storage", "Capsules", 0.5)).to.equal(base)
			expect(Utility.GetInventoryLimit("Storage", "Capsules", 0)).to.equal(base)
			expect(Utility.GetInventoryLimit("Storage", "Capsules", "2" :: any)).to.equal(base)
		end)
	end)
end

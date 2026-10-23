--!strict
--[[
	StarterBundleReceipts.luau
	Receipt actions for the one-time Starter Bundle (SEASON-PASS, 2026-10-23).
	Plain module (not a Knit service). ProcessReceipt.server.luau merges BuildActions() into its
	ProductActionMap, so the bundle uses the same PurchaseId dedupe and save-before-PurchaseGranted
	path as every other product. Contents are PROPOSED (Jack); the grant is applied to the loaded
	profile synchronously, mirroring BobaBuckReceipts.

	Contents: StarterBundleConfig.BOBA_BUCKS Boba Bucks (reason "StarterBundle",
	excluded from the MostBobaBucks leaderboard) + StarterBundleConfig.CAPSULES
	written directly into the profile (the ProgressionService._onLevelUp direct-write
	pattern) + StarterBundleClaimed flag.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductIds = require(ReplicatedStorage:WaitForChild("Shared").Configuration.ProductIds)
local StarterBundleConfig = require(ReplicatedStorage:WaitForChild("Shared").Configuration.StarterBundleConfig)

local StarterBundleReceipts = {}

export type Action = {
	Name: string,
	Grant: (player: Player, receiptInfo: { [string]: any }, playerData: any) -> (boolean, string?),
}

StarterBundleReceipts.REASON = "StarterBundle"

--- Resolves CurrencyService. Indirection so specs can substitute a fake without starting Knit.
function StarterBundleReceipts._getCurrencyService(): any
	local Knit = require(ReplicatedStorage:WaitForChild("Packages").Knit)
	return Knit.GetService("CurrencyService")
end

--- True when `productId` is the configured Starter Bundle product.
function StarterBundleReceipts.IsStarterBundle(productId: number): boolean
	return ProductIds.StarterBundle ~= nil and productId == ProductIds.StarterBundle
end

local function grant(player: Player, receiptInfo: { [string]: any }, playerData: any): (boolean, string?)
	if not StarterBundleReceipts.IsStarterBundle(receiptInfo.ProductId) then
		return false, "not the Starter Bundle"
	end
	if typeof(playerData.Currency) ~= "table" or typeof(playerData.Currency.BobaBucks) ~= "number" then
		return false, "no BobaBucks balance"
	end
	if
		typeof(playerData.Inventory) ~= "table"
		or typeof(playerData.Inventory.Items) ~= "table"
		or typeof(playerData.Inventory.Items.Capsules) ~= "table"
	then
		return false, "no Capsules inventory"
	end
	-- Applied synchronously to the loaded profile; ProcessReceipt records the receipt right after this returns.
	StarterBundleReceipts._getCurrencyService()
		:ApplyLoaded(player, playerData, "BobaBucks", StarterBundleConfig.BOBA_BUCKS, StarterBundleReceipts.REASON)
	for _, capsuleName in StarterBundleConfig.CAPSULES do
		playerData:SetValue({ "Inventory", "Items", "Capsules", HttpService:GenerateGUID(false) }, {
			Name = capsuleName,
			StackCount = 1,
			Properties = { RandomSource = "Paid" },
		})
	end
	playerData:SetValue({ "StarterBundleClaimed" }, true)
	return true
end

--- One action for the configured bundle product, or none while the ID is nil (inert).
function StarterBundleReceipts.BuildActions(): { [number]: Action }
	local productId = ProductIds.StarterBundle
	if typeof(productId) ~= "number" then
		return {}
	end
	return {
		[productId] = { Name = "Starter Bundle", Grant = grant },
	}
end

return StarterBundleReceipts

--!strict
--[[
	BobaBuckReceipts.luau
	Receipt actions for the Robux Boba Bucks packs (PRODUCT-WIRE, Jack 2026-10-21).
	Plain module (not a Knit service). ProcessReceipt.server.luau merges BuildActions() into its
	ProductActionMap, so packs use the same PurchaseId dedupe and save-before-PurchaseGranted path as
	every other product. Credits go through CurrencyService:ApplyLoaded (reason "RobuxPack"), which updates the
	replicated profile (HUD) and stats but is excluded from the MostBobaBucks leaderboard.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductIds = require(ReplicatedStorage:WaitForChild("Shared").Configuration.ProductIds)

local BobaBuckReceipts = {}

export type Action = {
	Name: string,
	Grant: (player: Player, receiptInfo: { [string]: any }, playerData: any) -> (boolean, string?),
}

BobaBuckReceipts.REASON = "RobuxPack"

-- ProductIds.BobaBucks key -> Boba Bucks granted. The amount is the pack size in the key name.
BobaBuckReceipts.PACKS = {
	{ Key = "Pack50", Amount = 50 },
	{ Key = "Pack150", Amount = 150 },
	{ Key = "Pack500", Amount = 500 },
	{ Key = "Pack1000", Amount = 1000 },
	{ Key = "Pack5000", Amount = 5000 },
}

--- Resolves CurrencyService. Indirection so specs can substitute a fake without starting Knit.
function BobaBuckReceipts._getCurrencyService(): any
	local Knit = require(ReplicatedStorage:WaitForChild("Packages").Knit)
	return Knit.GetService("CurrencyService")
end

--- Boba Bucks granted for `productId`, or nil if it is not a pack product.
function BobaBuckReceipts.GetAmount(productId: number): number?
	for _, pack in BobaBuckReceipts.PACKS do
		if (ProductIds.BobaBucks :: any)[pack.Key] == productId then
			return pack.Amount
		end
	end
	return nil
end

local function grant(player: Player, receiptInfo: { [string]: any }, playerData: any): (boolean, string?)
	local amount = BobaBuckReceipts.GetAmount(receiptInfo.ProductId)
	if amount == nil then
		return false, "not a Boba Bucks pack"
	end
	if typeof(playerData.Currency) ~= "table" or typeof(playerData.Currency.BobaBucks) ~= "number" then
		return false, "no BobaBucks balance"
	end
	-- Applied synchronously to the loaded profile; ProcessReceipt records the receipt right after this returns.
	BobaBuckReceipts._getCurrencyService():ApplyLoaded(player, playerData, "BobaBucks", amount, BobaBuckReceipts.REASON)
	return true
end

--- One action per configured pack product, keyed by ProductId. Packs without an ID are skipped.
function BobaBuckReceipts.BuildActions(): { [number]: Action }
	local actions: { [number]: Action } = {}
	for _, pack in BobaBuckReceipts.PACKS do
		local productId = (ProductIds.BobaBucks :: any)[pack.Key]
		if typeof(productId) == "number" then
			actions[productId] = { Name = `Boba Bucks {pack.Amount}`, Grant = grant }
		end
	end
	return actions
end

return BobaBuckReceipts

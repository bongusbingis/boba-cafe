--!strict
--[[
	DonationReceipts.luau
	Receipt actions for the Donate! board's developer products (REVIVAL-001 DONATIONS, Jack 2026-10-21).
	Plain module (not a Knit service). ProcessReceipt.server.luau merges BuildActions() into its
	ProductActionMap, so donations use the same PurchaseId dedupe and save-before-PurchaseGranted path as
	every other product.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductIds = require(ReplicatedStorage:WaitForChild("Shared").Configuration.ProductIds)

local DonationReceipts = {}

export type Action = {
	Name: string,
	-- Applies the grant to the profile. Must not yield. Returns true only once the data is in the profile.
	Grant: (player: Player, receiptInfo: { [string]: any }, playerData: any) -> (boolean, string?),
	-- Runs once, only after the receipt is answered PurchaseGranted.
	OnGranted: (player: Player, receiptInfo: { [string]: any }) -> (),
}

--- Robux tier configured for `productId`, or nil if it is not a donation product.
function DonationReceipts.GetTierRobux(productId: number): number?
	for _, donation in ProductIds.Donations do
		if donation.ProductId == productId then
			return donation.Robux
		end
	end
	return nil
end

--- Robux to record for a receipt: CurrencySpent when Roblox reports a positive Robux amount, else the tier.
function DonationReceipts.GetReceiptRobux(receiptInfo: { [string]: any }): number?
	local tier = DonationReceipts.GetTierRobux(receiptInfo.ProductId)
	if tier == nil then
		return nil
	end
	local spent = receiptInfo.CurrencySpent
	if
		typeof(spent) == "number"
		and spent > 0
		and (receiptInfo.CurrencyType == nil or receiptInfo.CurrencyType == Enum.CurrencyType.Robux)
	then
		return math.floor(spent)
	end
	return tier
end

--- Resolves LeaderboardService. Indirection so specs can substitute a fake without starting Knit.
function DonationReceipts._getLeaderboardService(): any
	local Knit = require(ReplicatedStorage:WaitForChild("Packages").Knit)
	return Knit.GetService("LeaderboardService")
end

local function grant(_player: Player, receiptInfo: { [string]: any }, playerData: any): (boolean, string?)
	local robux = DonationReceipts.GetReceiptRobux(receiptInfo)
	if robux == nil then
		return false, "not a donation product"
	end
	local current = if typeof(playerData.RobuxDonated) == "number" then playerData.RobuxDonated else 0
	playerData:SetValue({ "RobuxDonated" }, current + robux)
	return true
end

local function onGranted(player: Player, receiptInfo: { [string]: any })
	local robux = DonationReceipts.GetReceiptRobux(receiptInfo)
	if robux == nil or robux <= 0 then
		return
	end
	local ok, err = pcall(function()
		DonationReceipts._getLeaderboardService():CreditDonation(player, robux)
	end)
	if not ok then
		warn(`[DonationReceipts] Top Donators credit failed for {player.UserId}: {err}`)
	end
end

--- One action per donation product, keyed by ProductId.
function DonationReceipts.BuildActions(): { [number]: Action }
	local actions: { [number]: Action } = {}
	for _, donation in ProductIds.Donations do
		actions[donation.ProductId] = {
			Name = `Donation {donation.Robux}`,
			Grant = grant,
			OnGranted = onGranted,
		}
	end
	return actions
end

return DonationReceipts

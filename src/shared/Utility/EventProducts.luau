--!strict
--[[
	EventProducts
	Client helper for the two server-wide event developer products (Boba Party, Rush Hour).
	Shared by the Shop Currency tab, the Cafe Rating meter dialog and the in-world product
	board. Prices are always live from Marketplace metadata (DEC-026), never hardcoded.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductIds = require(ReplicatedStorage:WaitForChild("Shared").Configuration.ProductIds)

export type Product = {
	Key: "BobaParty" | "RushHour",
	Name: string,
	Blurb: string,
	Id: number?,
}

local EventProducts = {}

EventProducts.Products = {
	{ Key = "BobaParty", Name = "Boba Party", Blurb = "10 min Rush for everyone", Id = ProductIds.BobaParty },
	{ Key = "RushHour", Name = "Rush Hour", Blurb = "2 min Rush for everyone", Id = ProductIds.RushHour },
} :: { Product }

--- True while the post-party cooldown runs (a party can still be extended while it is active).
function EventProducts.partyOnCooldown(): boolean
	local endsAt = workspace:GetAttribute("BobaPartyCooldownEndsAt")
	return typeof(endsAt) == "number" and workspace:GetServerTimeNow() < endsAt
end

--- True when the product can be bought right now.
function EventProducts.available(product: Product): boolean
	if product.Id == nil then
		return false
	end
	if product.Key == "BobaParty" then
		return workspace:GetAttribute("BobaParty") == true or not EventProducts.partyOnCooldown()
	end
	return true
end

--- Yields. Live Robux price per product Key as a string; missing when unavailable.
function EventProducts.fetchPrices(): { [string]: string }
	local prices = {}
	for _, product in EventProducts.Products do
		if product.Id ~= nil then
			local id = product.Id
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Product)
			end)
			if ok and typeof(info) == "table" and info.PriceInRobux ~= nil then
				prices[product.Key] = tostring(info.PriceInRobux)
			end
		end
	end
	return prices
end

function EventProducts.prompt(product: Product)
	if product.Id ~= nil and EventProducts.available(product) then
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.Id)
	end
end

return EventProducts

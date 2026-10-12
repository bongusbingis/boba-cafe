---> services
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local Gamepasses = require(Shared.Configuration.Gamepasses)

---> module declaration
local ClientProductsController = Knit.CreateController({
	Name = "ClientProductsController",
	InfoCache = {},
})

---> private
local LocalPlayer = Players.LocalPlayer

---> public

--[=[
	Cached product info lookup. Prices and icons are identical for every player, so one
	fetch per id serves the whole session; this is what keeps shop pages from hammering
	MarketplaceService as the player scrolls.

	Returns nil when the lookup fails, so callers can fall back to configured text.
]=]
function ClientProductsController:GetInfoAsync(id: number, isProduct: boolean?)
	local cacheKey = `{id}_{isProduct and "p" or "g"}`

	local cached = self.InfoCache[cacheKey]
	if cached ~= nil then
		-- false marks a previously failed lookup; do not retry every call.
		return cached or nil
	end

	local infoType = if isProduct then Enum.InfoType.Product else Enum.InfoType.GamePass

	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, infoType)
	end)

	self.InfoCache[cacheKey] = ok and info or false
	return ok and info or nil
end

--- Prompts a game pass purchase.
function ClientProductsController:PromptPass(passId: number)
	if typeof(passId) ~= "number" or passId <= 0 then
		return
	end
	MarketplaceService:PromptGamePassPurchase(LocalPlayer, passId)
end

--- Prompts a developer product purchase.
function ClientProductsController:PromptProduct(productId: number)
	if typeof(productId) ~= "number" or productId <= 0 then
		return
	end
	MarketplaceService:PromptProductPurchase(LocalPlayer, productId)
end

--- Resolves a configured pass by name, so callers do not embed ids.
function ClientProductsController:PromptPassByName(passName: string)
	for passId, definition in Gamepasses do
		if definition.Name == passName then
			self:PromptPass(passId)
			return
		end
	end

	warn(`[ClientProductsController] Unknown game pass '{passName}'.`)
end

---> lifecycle

function ClientProductsController:KnitStart()
	-- A completed purchase invalidates nothing about price/icon, but ownership-derived
	-- UI needs to know; re-broadcast locally so pages can refresh.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_player, passId, wasPurchased)
		if wasPurchased then
			self.InfoCache[`{passId}_g`] = nil
		end
	end)
end

return ClientProductsController

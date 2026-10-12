--[[
    Module: ProductsService
    Description: Boba Bucks purchase engine.

    Prices are NOT held here — they live on the item definitions in
    Shared.Configuration.InventoryItemDefinitions (Capsules.Price, Nametags.Price),
    alongside CanBeSold and OffSale. This service owns the transaction: validation,
    confirmation, granting and payment.

    Ordering matters. The item is granted BEFORE currency is deducted, and the balance
    is re-checked after the player confirms, so a slow dialog cannot be used to spend
    the same Boba Bucks twice.
--]]

---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Config = Shared:WaitForChild("Configuration")

local Knit = require(Packages.Knit)
local Inventory = require(Shared.Inventory)
local InventoryItemDefinitions = require(Config.InventoryItemDefinitions)
local InventoryLimits = require(Config.InventoryLimits)

---> module declaration
local ProductsService = Knit.CreateService({
    Name = "ProductsService",
    Client = {},
})

---> constants
local CONFIRM_YES = "Yes"
local PURCHASE_COLOR = Color3.fromRGB(151, 190, 135)
local ERROR_COLOR = Color3.fromRGB(253, 102, 102)

-- Item types that can be bought directly with Boba Bucks. Pets and Particles are
-- deliberately absent: they are obtained by opening capsules, not bought outright.
local PURCHASABLE_TYPES = {
    Capsules = true,
    Nametags = true,
}

---> private
local purchaseDebounce: { [number]: boolean } = {}

local function getDialogService()
    return Knit.GetService("DialogService")
end

-- Definition prices are display strings (" 150", "150"). Returns nil when unpriced.
local function parsePrice(rawPrice: any): number?
    if typeof(rawPrice) == "number" then
        return rawPrice
    end

    if typeof(rawPrice) ~= "string" then
        return nil
    end

    return tonumber((rawPrice:gsub("%s", "")))
end

local function notify(player: Player, title: string, description: string)
    getDialogService():Notify(player, {
        Title = title,
        Description = description,
        Image = "",
    })
end

-- Inventory:Filter returns (matches, count).
local function countItems(inventory): number
    local _, count = inventory:Filter(function()
        return true
    end)
    return count
end

---> public

--[=[
    Attempts to buy `itemName` of `itemType` for the definition's Boba Bucks price.
    Returns true only when the item was granted and paid for.
]=]
function ProductsService:PurchaseItem(player: Player, itemType: string, itemName: string): boolean
    if purchaseDebounce[player.UserId] then
        return false
    end
    purchaseDebounce[player.UserId] = true

    local function finish(result: boolean): boolean
        purchaseDebounce[player.UserId] = nil
        return result
    end

    if not PURCHASABLE_TYPES[itemType] then
        warn(string.format("[ProductsService] '%s' is not a purchasable item type.", tostring(itemType)))
        return finish(false)
    end

    local definitions = InventoryItemDefinitions[itemType]
    local itemDef = definitions and definitions[itemName]

    if not itemDef then
        warn(string.format("[ProductsService] Unknown item '%s' in '%s'.", tostring(itemName), tostring(itemType)))
        notify(player, "An error occurred!", "That item does not exist.")
        return finish(false)
    end

    if not itemDef.CanBeSold or itemDef.OffSale then
        notify(player, "Not for sale", `"{itemName}" is not currently available for purchase.`)
        return finish(false)
    end

    local price = parsePrice(itemDef.Price)
    if not price then
        warn(string.format("[ProductsService] '%s' has no usable price.", itemName))
        notify(player, "An error occurred!", "That item has no price set.")
        return finish(false)
    end

    local dataService = Knit.GetService("DataService")
    local gotData, playerData = dataService:GetDataAsync(player):await()
    if not gotData or not playerData then
        notify(player, "An error occurred!", "Your data could not be loaded. Please try again.")
        return finish(false)
    end

    -- GetDataAsync resolves a proxy whose table IS profile.Data (the Replica sits on
    -- __index), so currency is read directly — same as CurrencyService does.
    local balance = playerData.Currency.BobaBucks
    if balance < price then
        notify(
            player,
            "Not enough Boba Bucks!",
            `You need {price - math.floor(balance)} more Boba Bucks to purchase "{itemName}".`)
        return finish(false)
    end

    -- Storage is capped per item type in the new inventory, unlike the old shared pool.
    local gotInventory, inventory = Inventory:GetPlayerInventoryAsync(player, itemType):await()
    if not gotInventory or not inventory then
        notify(player, "An error occurred!", "Your inventory could not be loaded.")
        return finish(false)
    end

    local storageLimit = InventoryLimits.Storage[itemType]
    if storageLimit and countItems(inventory) >= storageLimit then
        notify(
            player,
            "Not enough storage!",
            `Your {itemType} storage is full ({storageLimit}). Sell something to make room.`)
        return finish(false)
    end

    local confirmed, choice = getDialogService()
        :CreateDialog(player, "ButtonPrompt", {
            Title = "Purchase Confirmation",
            Text = `Are you sure you want to purchase [{itemName}] for {price} Boba Bucks?`,
            Buttons = {
                { Text = CONFIRM_YES, Color = PURCHASE_COLOR },
                { Text = "Cancel", Color = ERROR_COLOR },
            },
        })
        :await()

    if not confirmed or choice ~= CONFIRM_YES then
        return finish(false)
    end

    -- Re-read the balance: the confirmation dialog is open for an unbounded time.
    local stillGotData, freshData = dataService:GetDataAsync(player):await()
    if not stillGotData or not freshData or freshData.Currency.BobaBucks < price then
        notify(player, "An error occurred!", "You no longer have enough Boba Bucks.")
        return finish(false)
    end

    local granted = inventory:Insert({ Name = itemName, Tier = itemDef.Tier })
    if not granted then
        notify(
            player,
            "An error occurred!",
            "Your purchase could not be completed. No Boba Bucks were taken.")
        return finish(false)
    end

    Knit.GetService("CurrencyService"):Modify(player, "BobaBucks", -price)

    notify(player, "Purchase successful!", `You purchased [{itemName}]! It is now in your inventory.`)

    return finish(true)
end

---> client

function ProductsService.Client:PurchaseItem(player: Player, itemType: string, itemName: string): boolean
    if typeof(itemType) ~= "string" or typeof(itemName) ~= "string" then
        return false
    end

    return self.Server:PurchaseItem(player, itemType, itemName)
end

function ProductsService.Client:GetPurchasableItems(_player: Player, itemType: string)
    if not PURCHASABLE_TYPES[itemType] then
        return {}
    end

    local results = {}
    for itemName, itemDef in InventoryItemDefinitions[itemType] do
        local price = parsePrice(itemDef.Price)
        if itemDef.CanBeSold and not itemDef.OffSale and price then
            results[itemName] = {
                Name = itemName,
                Price = price,
                Tier = itemDef.Tier,
                Image = itemDef.Image,
            }
        end
    end

    return results
end

return ProductsService

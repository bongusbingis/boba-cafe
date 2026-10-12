--[[
    Module: GamepassBenefitsService
    Description: Grants the items that game passes unlock, on join and on purchase.

    Benefits that belong to another system live with that system instead — the Points
    multiplier is in CurrencyService, faster walking is in SettingsService, and the
    Instant Brew speed-up is in the kitchen's Animate action. This service only handles
    passes whose benefit is "you own this item now".
--]]

---> services
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local Inventory = require(Shared.Inventory)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local InventoryItemDefinitions = require(Shared.Configuration.InventoryItemDefinitions)

---> module declaration
local GamepassBenefitsService = Knit.CreateService({
    Name = "GamepassBenefitsService",
})

---> constants

-- Passes that grant an inventory item outright. The item must exist in the matching
-- InventoryItemDefinitions table.
local ITEM_GRANTS = {
    { PassId = 12385781, ItemType = "Nametags", ItemName = "VIP" },
}

---> private

--- Grants `itemName` unless the player already has it. Idempotent, so it is safe to
--- run on every join as well as on purchase.
function GamepassBenefitsService:_grantItem(player: Player, itemType: string, itemName: string)
    local definitions = InventoryItemDefinitions[itemType]
    if not definitions or not definitions[itemName] then
        warn(string.format("[GamepassBenefitsService] Unknown item '%s' in '%s'.", itemName, itemType))
        return
    end

    Inventory:GetPlayerInventoryAsync(player, itemType)
        :andThen(function(inventory)
            local _, existing = inventory:Filter(function(item)
                return item.Name == itemName
            end)

            if existing > 0 then
                return
            end

            inventory:Insert({ Name = itemName, Tier = definitions[itemName].Tier })
        end)
        :catch(function(err)
            warn(string.format("[GamepassBenefitsService] Failed to grant '%s' to %s:", itemName, player.Name), err)
        end)
end

function GamepassBenefitsService:_syncPlayer(player: Player)
    for _, grant in ITEM_GRANTS do
        if GamepassUtil:PlayerOwnsPassAsync(player, grant.PassId) then
            self:_grantItem(player, grant.ItemType, grant.ItemName)
        end
    end
end

---> lifecycle

function GamepassBenefitsService:PlayerAdded(player: Player)
    task.spawn(function()
        self:_syncPlayer(player)
    end)
end

function GamepassBenefitsService:KnitStart()
    -- Grant immediately on purchase rather than making the player rejoin.
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
        if not wasPurchased then
            return
        end

        -- The ownership cache was populated before this purchase, so refresh it or the
        -- grant below would see the pass as unowned.
        GamepassUtil:GrantPassToCache(player, passId)

        for _, grant in ITEM_GRANTS do
            if grant.PassId == passId then
                self:_grantItem(player, grant.ItemType, grant.ItemName)
            end
        end
    end)
end

return GamepassBenefitsService

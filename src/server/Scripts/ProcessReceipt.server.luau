---> services
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

---> networking
local GetPurchases = ReplicatedStorage:WaitForChild("Networking"):WaitForChild("GetPurchases")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)

---> constants
local HATCH_DURATION_SECONDS = require(Shared.Configuration.CapsuleConfig).PET_HATCH_DURATION
local SKIP_HATCH_PRODUCT_ID = 1143554452

---> lifecycle
local ProductPurchaseDatastore = DataStoreService:GetDataStore("ProductPurchaseDatastore_0001")

--- [number]: {string, (Player, ReceiptInfo) -> boolean, boolean?}
--- Maps productId to array consisting of (productName, callback function, includePlayerData)

type PendingHatch = {
    CapsuleName: string,   -- definition name of the capsule that was used
    TimeAccumulated: number, -- active-play seconds accumulated so far
}

local ProductActionMap = {
    [SKIP_HATCH_PRODUCT_ID] = {"Skip Hatch", function(_, _, playerData)
        local hatchingPet = playerData.HatchingPet
        if hatchingPet and hatchingPet ~= false then
            playerData:SetValue({ "HatchingPet" }, {
                CapsuleName = hatchingPet.CapsuleName,
                TimeAccumulated = HATCH_DURATION_SECONDS - 5,
            })
        end
        return true
    end, true},
}

MarketplaceService.ProcessReceipt = function(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local action = ProductActionMap[receiptInfo.ProductId]
    if action then
        local name = action[1]
        local f = action[2]
        local includePlayerData = action[3]
        local playerData = nil

        if includePlayerData then
            local dataService = Knit.GetService("DataService")
            local _, _playerData = dataService:GetDataAsync(player):await()
            playerData = _playerData
        end


        local success, res = pcall(f, player, receiptInfo, playerData)
        if not success then
            warn("Error processing purchase for product " .. receiptInfo.ProductId .. ": " .. tostring(res))
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        if res ~= true then
            warn("Purchase action for product", receiptInfo.ProductId, "did not return true, got:", res)
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end

        ProductPurchaseDatastore:UpdateAsync(player.UserId, function(old)
            if not old then
                old = {}
            end
            table.insert(old, {
                ProductName = name,
                ProductId = receiptInfo.ProductId,
                Timestamp = os.time(),
            })
            return old
        end)

        return Enum.ProductPurchaseDecision.PurchaseGranted
    else
        warn("No action defined for product " .. receiptInfo.ProductId)
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end
end

---> GetPurchases remote function
-- Per-player cooldown prevents clients from spamming DataStore reads.
local FETCH_COOLDOWN_SECONDS = 10
local fetchLastTime: { [number]: number } = {}

Players.PlayerRemoving:Connect(function(player)
    fetchLastTime[player.UserId] = nil
end)

GetPurchases.OnServerInvoke = function(player: Player)
    local userId = player.UserId
    local now = os.clock()

    if fetchLastTime[userId] and (now - fetchLastTime[userId]) < FETCH_COOLDOWN_SECONDS then
        return nil
    end
    fetchLastTime[userId] = now

    local ok, data = pcall(function()
        return ProductPurchaseDatastore:GetAsync(userId)
    end)

    if not ok then
        warn("[GetPurchases] DataStore error for", player.Name, ":", data)
        return nil
    end

    return data or {}
end

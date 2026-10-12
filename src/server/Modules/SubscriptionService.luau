--[[
    Module: SubscriptionService
    Description: Timed subscriptions (currently Celebrity).

    Definitions are data in SubscriptionsConfig; this owns the state. Expiry is checked
    against an os.time() deadline rather than tracked with timers, so a subscription
    cannot get stuck active because a task was lost or the server restarted.

    Other systems ask :IsActive() rather than reading the profile directly.
--]]

---> services
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local SubscriptionsConfig = require(Shared.Configuration.SubscriptionsConfig)

---> module declaration
local SubscriptionService = Knit.CreateService({
    Name = "SubscriptionService",
    Client = {
        --- Fired when a subscription starts or is extended.
        SubscriptionChanged = Knit.CreateSignal(),
    },
})

---> private

local function getData(player: Player)
    local ok, playerData = Knit.GetService("DataService"):GetDataAsync(player):await()
    if not ok then
        return nil
    end
    return playerData
end

---> public

--- Seconds remaining, or 0 when not held / expired.
function SubscriptionService:GetRemaining(player: Player, name: string): number
    if not SubscriptionsConfig.exists(name) then
        return 0
    end

    local playerData = getData(player)
    if not playerData then
        return 0
    end

    local entry = playerData.Subscriptions and playerData.Subscriptions[name]
    if not entry then
        return 0
    end

    return math.max(0, (entry.Expire or 0) - os.time())
end

function SubscriptionService:IsActive(player: Player, name: string): boolean
    return self:GetRemaining(player, name) > 0
end

--[=[
    Adds `seconds` to a subscription.

    Calendar subscriptions extend from the existing expiry when still active, so buying
    a second month before the first runs out gives two full months rather than
    overwriting. Duration subscriptions always extend from now.
]=]
function SubscriptionService:AddTime(player: Player, name: string, seconds: number): boolean
    local definition = SubscriptionsConfig.Subscriptions[name]
    if not definition then
        warn(string.format("[SubscriptionService] Unknown subscription '%s'.", tostring(name)))
        return false
    end

    if typeof(seconds) ~= "number" or seconds <= 0 then
        return false
    end

    local playerData = getData(player)
    if not playerData then
        return false
    end

    local subscriptions = playerData.Subscriptions or {}
    local current = subscriptions[name] and subscriptions[name].Expire or 0
    local now = os.time()

    local base = if definition.Kind == "Calendar" and current > now then current else now

    subscriptions[name] = { Expire = base + seconds }
    playerData:SetValue({ "Subscriptions" }, subscriptions)

    self.Client.SubscriptionChanged:Fire(player, {
        Name = name,
        Expire = subscriptions[name].Expire,
    })

    Knit.GetService("DialogService"):Notify(player, {
        Title = `{definition.DisplayName} Active`,
        Description = "Thanks for your support! Rejoin if any perks do not appear straight away.",
        Image = "",
    })

    return true
end

--- Grants the one-time Premium trial, or prompts the purchase when not a member.
--- Returns true when the trial was granted.
function SubscriptionService:ClaimPremiumTrial(player: Player, name: string): boolean
    local definition = SubscriptionsConfig.Subscriptions[name]
    if not definition or not definition.PremiumTrial then
        return false
    end

    if player.MembershipType ~= Enum.MembershipType.Premium then
        pcall(function()
            MarketplaceService:PromptPremiumPurchase(player)
        end)
        return false
    end

    local playerData = getData(player)
    if not playerData then
        return false
    end

    -- The trial is once per account, tracked by a redeemed-code style marker so it
    -- cannot be farmed by letting the subscription lapse.
    local marker = `PremiumTrial_{name}`
    local redeemed = playerData.RedeemedCodes or {}

    if redeemed[marker] then
        Knit.GetService("DialogService"):Notify(player, {
            Title = "Already Claimed",
            Description = "You have already used your Premium trial for this subscription.",
            Image = "",
        })
        return false
    end

    redeemed[marker] = true
    playerData:SetValue({ "RedeemedCodes" }, redeemed)

    return self:AddTime(player, name, SubscriptionsConfig.PREMIUM_TRIAL_SECONDS)
end

--- Applies whatever subscription a developer product grants. Returns true when handled,
--- so ProcessReceipt can tell subscription products from other products.
function SubscriptionService:HandleProductPurchase(player: Player, productId: number): boolean
    local name, seconds = SubscriptionsConfig.getProductGrant(productId)
    if not name or not seconds then
        return false
    end

    return self:AddTime(player, name, seconds)
end

---> client

function SubscriptionService.Client:GetRemaining(player: Player, name: string): number
    if typeof(name) ~= "string" then
        return 0
    end
    return self.Server:GetRemaining(player, name)
end

function SubscriptionService.Client:IsActive(player: Player, name: string): boolean
    if typeof(name) ~= "string" then
        return false
    end
    return self.Server:IsActive(player, name)
end

function SubscriptionService.Client:ClaimPremiumTrial(player: Player, name: string): boolean
    if typeof(name) ~= "string" then
        return false
    end
    return self.Server:ClaimPremiumTrial(player, name)
end

return SubscriptionService

--[[
    Module: DailyRewardsService
    Description: Daily login streak. Players claim one entry from
    DailyRewardsConfig.CYCLE per day; missing a day resets the streak to the start.

    The claim is entirely server-authoritative — the client only asks, and every
    eligibility check happens here.
--]]

---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Config = Shared:WaitForChild("Configuration")

local Knit = require(Packages.Knit)
local Inventory = require(Shared.Inventory)
local DailyStreak = require(Shared.Utility.DailyStreak)
local DailyRewardsConfig = require(Config.DailyRewardsConfig)
local InventoryItemDefinitions = require(Config.InventoryItemDefinitions)

---> module declaration
local DailyRewardsService = Knit.CreateService({
    Name = "DailyRewardsService",
    Client = {
        RewardClaimed = Knit.CreateSignal(),
    },
})

---> state

-- Guards against a player double-claiming by spamming the remote while the first claim
-- is still yielding on the inventory write.
local claiming: { [number]: boolean } = {}

---> private

--- Streak arithmetic lives in Shared.Utility.DailyStreak so it can be tested without a
--- Roblox runtime; this just supplies the rules from config.
local function evaluate(rewards: { CurrentDay: number, TotalDays: number, LastClaimed: number })
    return DailyStreak.evaluate({
        CurrentDay = rewards.CurrentDay,
        LastClaimed = rewards.LastClaimed,
    }, {
        CycleLength = #DailyRewardsConfig.CYCLE,
        ClaimInterval = DailyRewardsConfig.CLAIM_INTERVAL,
        StreakGrace = DailyRewardsConfig.STREAK_GRACE,
    }, os.time())
end

local function grantReward(player: Player, grant): boolean
    if grant.Type == "Currency" then
        Knit.GetService("CurrencyService"):Modify(player, grant.Currency, grant.Amount)
        return true
    end

    if grant.Type == "Item" then
        local definitions = InventoryItemDefinitions[grant.ItemType]
        local itemDef = definitions and definitions[grant.ItemName]

        if not itemDef then
            warn(string.format(
                "[DailyRewardsService] Reward item '%s' missing from %s definitions.",
                tostring(grant.ItemName), tostring(grant.ItemType)
            ))
            return false
        end

        local ok, inventory = Inventory:GetPlayerInventoryAsync(player, grant.ItemType):await()
        if not ok or not inventory then
            return false
        end

        -- Insert enforces the storage cap itself and returns nil when full.
        return inventory:Insert({ Name = grant.ItemName, Tier = itemDef.Tier }) ~= nil
    end

    warn(string.format("[DailyRewardsService] Unknown grant type '%s'.", tostring(grant.Type)))
    return false
end

---> public

--- Streak state for the Rewards page.
function DailyRewardsService:GetState(player: Player)
    local ok, playerData = Knit.GetService("DataService"):GetDataAsync(player):await()
    if not ok or not playerData then
        return nil
    end

    local rewards = playerData.DailyRewards
    local state = evaluate(rewards)

    return {
        CurrentDay = rewards.CurrentDay,
        TotalDays = rewards.TotalDays,
        NextDay = state.NextDay,
        CanClaim = state.CanClaim,
        SecondsRemaining = state.SecondsRemaining,
        StreakReset = state.StreakReset,
        Cycle = DailyRewardsConfig.CYCLE,
    }
end

--- Claims today's reward. Returns (success, message).
function DailyRewardsService:Claim(player: Player): (boolean, string)
    if claiming[player.UserId] then
        return false, "A claim is already in progress."
    end
    claiming[player.UserId] = true

    local function finish(success: boolean, message: string)
        claiming[player.UserId] = nil
        return success, message
    end

    local ok, playerData = Knit.GetService("DataService"):GetDataAsync(player):await()
    if not ok or not playerData then
        return finish(false, "Your data could not be loaded.")
    end

    local rewards = playerData.DailyRewards
    local state = evaluate(rewards)

    if not state.CanClaim then
        local hours = math.ceil(state.SecondsRemaining / 3600)
        return finish(false, `Come back in {hours} hour{hours == 1 and "" or "s"}.`)
    end

    local entry = DailyRewardsConfig.CYCLE[state.NextDay]
    if not entry then
        warn(string.format("[DailyRewardsService] No cycle entry at index %d.", state.NextDay))
        return finish(false, "That reward is unavailable.")
    end

    -- Grant first: if it fails (full inventory, say) nothing is consumed and the player
    -- can retry, rather than burning the day on a reward they never received.
    if not grantReward(player, entry.Grant) then
        return finish(false, "Your reward could not be granted. Check you have inventory space.")
    end

    playerData:SetValue({ "DailyRewards", "CurrentDay" }, state.NextDay)
    playerData:SetValue({ "DailyRewards", "TotalDays" }, (rewards.TotalDays or 0) + 1)
    playerData:SetValue({ "DailyRewards", "LastClaimed" }, os.time())

    self.Client.RewardClaimed:Fire(player, {
        Day = state.NextDay,
        Label = entry.Label,
        Description = entry.Description,
        Icon = entry.Icon,
        StreakReset = state.StreakReset,
    })

    return finish(true, `Claimed day {state.NextDay}: {entry.Label}!`)
end

---> client

function DailyRewardsService.Client:GetState(player: Player)
    return self.Server:GetState(player)
end

function DailyRewardsService.Client:Claim(player: Player): (boolean, string)
    local success, message = self.Server:Claim(player)

    Knit.GetService("DialogService"):Notify(player, {
        Title = success and "Daily Reward" or "Not yet!",
        Description = message,
        Image = "",
    })

    return success, message
end

---> lifecycle

function DailyRewardsService:PlayerRemoving(player: Player)
    claiming[player.UserId] = nil
end

return DailyRewardsService

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Config = Shared:WaitForChild("Configuration")

local Knit = require(Packages.Knit)
local ProfileTemplate = require(Config.ProfileTemplate)
local GamepassUtil = require(Shared.Utility.GamepassUtil)

---> constants

-- Passes that multiply earned Points. Multipliers are additive on top of the base 1x,
-- so owning both VIP and Star Employee earns 5x, matching V4.
local POINTS_MULTIPLIER_PASSES = {
    { Name = "VIP", Bonus = 2 },
    { Name = "Star Employee", Bonus = 2 },
}

---> module declaration
local CurrencyService = Knit.CreateService({
    Name = "CurrencyService",

    --- Server-wide, time-limited Points bonus shared by every player. Set by
    --- SpillService when the cafe reaches 100% cleanliness, and readable by the HUD.
    --- Amount is the bonus added to the multiplier, not the multiplier itself, so it
    --- stacks additively with game pass bonuses. Duration is an os.time() deadline;
    --- 0 means inactive.
    GlobalMulti = {
        Amount = 0,
        Duration = 0,
    },
})

---> private

--- The active server-wide bonus, or 0 when none is running or it has expired. Reading
--- the deadline rather than relying on a timer means a cancelled or missed task.delay
--- cannot leave the boost stuck on.
function CurrencyService:_getGlobalBonus(): number
    local multi = self.GlobalMulti

    if multi.Duration <= 0 or os.time() >= multi.Duration then
        return 0
    end

    return multi.Amount
end

--- Total Points multiplier: base 1x, plus game pass bonuses, plus any server-wide
--- bonus. Only applied to Points the player earns; spending and BobaBucks are never
--- scaled.
function CurrencyService:_getPointsMultiplier(player: Player): number
    local multiplier = 1

    for _, pass in POINTS_MULTIPLIER_PASSES do
        -- Confirm the pass is still configured first: Modify runs on every reward, and
        -- PlayerOwnsPassAsync warns on unknown passes, which would flood the log.
        local definition = GamepassUtil:GetPassData(pass.Name)
        if definition and GamepassUtil:PlayerOwnsPassAsync(player, pass.Name) then
            multiplier += pass.Bonus
        end
    end

    return multiplier + self:_getGlobalBonus()
end

---> client

--- Lets the HUD show the active cafe-wide bonus and when it ends.
function CurrencyService.Client:GetGlobalMulti()
    local multi = self.Server.GlobalMulti
    local active = self.Server:_getGlobalBonus() > 0

    return {
        Active = active,
        Amount = active and multi.Amount or 0,
        EndsAt = active and multi.Duration or 0,
    }
end

---> public

function CurrencyService:Modify(player: Player, type: "BobaBucks" | "Points", amount: number)
    if not ProfileTemplate.Currency[type] then
        warn(`Invalid currency type: {type}`)
        return
    end

    if amount == 0 then
        warn("Amount must be non-zero")
        return
    end
    
    Knit.GetService("DataService"):GetDataAsync(player):andThen(function(playerData)
        local current = playerData.Currency[type]
        if not current then
            warn(`Player {player.Name} does not have currency type: {type}`)
            return
        end

        -- Pass multipliers apply to Points the player earns only. Deductions are left
        -- untouched, otherwise owning VIP would make everything cost more.
        if type == "Points" and amount > 0 then
            amount = math.floor(amount * self:_getPointsMultiplier(player))
        end

        if type == "BobaBucks" then
            local statisticsService = Knit.GetService("StatisticsService")
            local statToIncrement = amount > 0 and "BobaBucksEarned" or "BobaBucksSpent"
            statisticsService:IncrementStat(player, statToIncrement, math.abs(amount))
        end
 
        playerData:SetValue({ "Currency", type }, current + amount)
    end)
end

return CurrencyService
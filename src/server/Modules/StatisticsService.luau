---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

---> service declaration
local StatisticsService = Knit.CreateService({
    Name = "StatisticsService",
})

--- Increments a named statistic for a player by the given amount (default 1).
--- Silently warns and returns if statName does not exist in the player's Statistics table.
function StatisticsService:IncrementStat(player: Player, statName: string, amount: number?)
    Knit.GetService("DataService"):GetDataAsync(player):andThen(function(playerData)
        local current = playerData.Statistics[statName]
        if current == nil then
            warn(`[StatisticsService] Unknown stat "{statName}" for player {player.Name}`)
            return
        end
        playerData:SetValue({ "Statistics", statName }, current + (amount or 1))
    end)
end

return StatisticsService

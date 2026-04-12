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

---> module declaration
local CurrencyService = Knit.CreateService({
    Name = "CurrencyService",
})

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

        if type == "BobaBucks" then
            local statisticsService = Knit.GetService("StatisticsService")
            local statToIncrement = amount > 0 and "BobaBucksEarned" or "BobaBucksSpent"
            statisticsService:IncrementStat(player, statToIncrement, math.abs(amount))
        end
 
        playerData:SetValue({ "Currency", type }, current + amount)
    end)
end

return CurrencyService
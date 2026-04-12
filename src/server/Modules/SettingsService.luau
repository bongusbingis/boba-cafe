---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared   = ReplicatedStorage:WaitForChild("Shared")
local Config   = Shared:WaitForChild("Configuration")

local Knit      = require(Packages.Knit)
local RankUtil  = require(Shared.Utility.RankUtil)

---> config (shared — contains no secrets)
local SettingsConfig = require(Config.SettingsConfig)

---> build a flat key → setting definition lookup for O(1) validation
local settingsByKey: { [string]: typeof(SettingsConfig[1].Settings[1]) } = {}
for _, category in ipairs(SettingsConfig) do
    for _, setting in ipairs(category.Settings) do
        settingsByKey[setting.Key] = setting
    end
end

---> service declaration
local SettingsService = Knit.CreateService({
    Name = "SettingsService",
    Client = {
        --- Updates a single boolean setting for the calling player.
        --- Returns (success: boolean, message: string).
        SetSetting = function(self, player: Player, key: string, value: any)
            return self.Server:_setSetting(player, key, value)
        end,
    },
})

function SettingsService:_setSetting(player: Player, key: string, value: any)
    -- Type guard: only boolean values are valid
    if typeof(value) ~= "boolean" then
        return false, "Invalid value."
    end

    -- Reject unknown keys and non-toggle settings (action settings have no stored state)
    local def = settingsByKey[key]
    if not def or def.Type == "Action" then
        return false, "Unknown setting."
    end

    -- Rank gate: check if setting requires a minimum rank
    if def.MinRank then
        local rank = RankUtil:GetRankAsync(player)
        if rank < def.MinRank then
            return false, "You don't have the required rank to change this setting."
        end
    end

    -- Persist via DataService
    Knit.GetService("DataService"):GetDataAsync(player):andThen(function(playerData)
        local current = playerData.Settings or {}
        current[key] = value
        playerData:SetValue({ "Settings" }, current)
    end):catch(function(err)
        warn("[SettingsService] Failed to save setting for", player.Name, err)
    end)

    return true, "OK"
end

return SettingsService

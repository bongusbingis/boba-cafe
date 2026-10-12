---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared   = ReplicatedStorage:WaitForChild("Shared")
local Config   = Shared:WaitForChild("Configuration")

local Knit      = require(Packages.Knit)
local RankUtil  = require(Shared.Utility.RankUtil)
local GamepassUtil = require(Shared.Utility.GamepassUtil)

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

---> constants

-- "Faster Walk Speed" pass advertises a 90% increase over the Roblox default.
local FASTER_WALK_SPEED_PASS_ID = 12385742
local DEFAULT_WALK_SPEED = 16
local FAST_WALK_SPEED = DEFAULT_WALK_SPEED * 1.9

---> private

--- Applies the walk speed implied by the player's setting plus pass ownership.
--- Safe to call when the character is absent; it simply does nothing.
function SettingsService:_applyWalkSpeed(player: Player)
    local character = player.Character
    local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
    if not humanoid then
        return
    end

    Knit.GetService("DataService"):GetDataAsync(player):andThen(function(playerData)
        local enabled = playerData.Settings and playerData.Settings.FasterWalkSpeed
        if not enabled then
            humanoid.WalkSpeed = DEFAULT_WALK_SPEED
            return
        end

        -- Re-check ownership rather than trusting stored state: the setting persists
        -- across sessions but pass ownership can be revoked or refunded.
        if GamepassUtil:PlayerOwnsPassAsync(player, FASTER_WALK_SPEED_PASS_ID) then
            humanoid.WalkSpeed = FAST_WALK_SPEED
        else
            humanoid.WalkSpeed = DEFAULT_WALK_SPEED
        end
    end):catch(function(err)
        warn("[SettingsService] Failed to apply walk speed for", player.Name, err)
    end)
end

---> lifecycle

function SettingsService:PlayerAdded(player: Player)
    player.CharacterAdded:Connect(function()
        self:_applyWalkSpeed(player)
    end)

    if player.Character then
        self:_applyWalkSpeed(player)
    end
end

---> public

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

    -- Game pass gate. Without this a client could enable a pass-gated setting it does
    -- not own; the UI hides these but the remote is callable directly. Only enabling is
    -- gated, so a player who loses access can still turn the setting off.
    if def.GamepassId and value == true then
        if not GamepassUtil:PlayerOwnsPassAsync(player, def.GamepassId) then
            return false, "You don't own the game pass required for this setting."
        end
    end

    -- Persist via DataService
    Knit.GetService("DataService"):GetDataAsync(player):andThen(function(playerData)
        local current = playerData.Settings or {}
        current[key] = value
        playerData:SetValue({ "Settings" }, current)

        if key == "FasterWalkSpeed" then
            self:_applyWalkSpeed(player)
        end
    end):catch(function(err)
        warn("[SettingsService] Failed to save setting for", player.Name, err)
    end)

    return true, "OK"
end

return SettingsService

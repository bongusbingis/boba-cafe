--[[
    Module: ToolNameValidityCheck
    Description: Action that validates the player's held tool name against a list of prerequisites.
    Matching rules live in Shared.Kitchen.ToolNameMatcher so the runner's Branch dispatch
    uses exactly the same syntax.
--]]

---> Requires

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ToolNameMatcher = require(ReplicatedStorage.Shared.Kitchen.ToolNameMatcher)

---> Helpers

local function getHeldTool(player: Player): Tool?
    return (player.Character and player.Character:FindFirstChildWhichIsA("Tool"))
end

---> Action

local function ToolNameValidityCheck(player: Player, _actionModel: Model, prerequisiteNames: { string }): boolean
    local tool = getHeldTool(player)
    if not tool then
        return false
    end

    return ToolNameMatcher.matchesAll(tool.Name, prerequisiteNames)
end

return ToolNameValidityCheck

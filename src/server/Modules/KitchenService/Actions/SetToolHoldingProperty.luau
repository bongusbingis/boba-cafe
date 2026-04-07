--[[
    Module: SetToolHoldingProperty
    Description: Action that sets a property on a named child of the player's held tool.
--]]

---> Helpers

local function getHeldTool(player: Player): Tool?
    return (player.Character and player.Character:FindFirstChildWhichIsA("Tool"))
end

---> Action

local function SetToolHoldingProperty(player: Player, actionModel: Model, instanceName: string, propertyName: string, newValue: any): boolean
    local tool = getHeldTool(player)
    if not tool then
        return false
    end

    local child = tool:FindFirstChild(instanceName)
    if not child then
        return true
    end

    if typeof(newValue) == "function" then
        newValue = newValue(child, actionModel)
    end

    (child :: any)[propertyName] = newValue
    return true
end

return SetToolHoldingProperty

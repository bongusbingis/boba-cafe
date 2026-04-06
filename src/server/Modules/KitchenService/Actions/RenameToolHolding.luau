--[[
    Module: RenameToolHolding
    Description: Action that renames the tool the player is currently holding.
--]]

---> Helpers

local function getHeldTool(player: Player): Tool?
    return (player.Character and player.Character:FindFirstChildWhichIsA("Tool"))
end

---> Action

local function RenameToolHolding(player: Player, newName: string): boolean
    local tool = getHeldTool(player)
    if not tool then
        return false
    end

    tool.Name = newName
    return true
end

return RenameToolHolding

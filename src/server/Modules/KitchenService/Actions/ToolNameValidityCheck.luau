--[[
    Module: ToolNameValidityCheck
    Description: Action that validates the player's held tool name against a list of prerequisites.
--]]

---> Helpers

local function getHeldTool(player: Player): Tool?
    return (player.Character and player.Character:FindFirstChildWhichIsA("Tool"))
end

---> Action

local function ToolNameValidityCheck(player: Player, prerequisiteNames: { string }): boolean
    local tool = getHeldTool(player)
    if not tool then
        return false
    end

    local toolName = tool.Name

    for _, entry in prerequisiteNames do
        if entry:sub(1, 1) == "!" then
            local pattern = entry:sub(2)
            if toolName:match(pattern) then
                return false
            end
        elseif entry:find("|") then
            local matched = false
            for part in entry:gmatch("[^|]+") do
                if toolName:match(part) then
                    matched = true
                    break
                end
            end
            if not matched then
                return false
            end
        else
            if not toolName:match(entry) then
                return false
            end
        end
    end

    return true
end

return ToolNameValidityCheck

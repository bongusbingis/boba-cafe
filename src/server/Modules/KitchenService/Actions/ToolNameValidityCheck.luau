--[[
    Module: ToolNameValidityCheck
    Description: Action that validates the player's held tool name against a list of prerequisites.
--]]

---> Helpers

local function getHeldTool(player: Player): Tool?
    return (player.Character and player.Character:FindFirstChildWhichIsA("Tool"))
end

---> Helpers (continued)

-- Evaluates a single term (no | separator) against a tool name.
-- Prefixes: "!" = must NOT match, "#" = must match (pattern), bare = exact equality.
local function matchesTerm(toolName: string, term: string): boolean
    if term:sub(1, 1) == "!" then
        return not toolName:match(term:sub(2))
    elseif term:sub(1, 1) == "#" then
        print(toolName, term:sub(2))
        return toolName:match(term:sub(2)) ~= nil
    elseif term:sub(1, 1) == "=" then
        return toolName == term:sub(2)
    else
        warn(string.format("[ToolNameValidityCheck] Unrecognized term prefix in '%s'", term))
        return toolName == term
    end
end

---> Action

local function ToolNameValidityCheck(player: Player, _actionModel: Model, prerequisiteNames: { string }): boolean
    local tool = getHeldTool(player)
    if not tool then
        return false
    end

    local toolName = tool.Name

    for _, entry in prerequisiteNames do
        if entry:find("|") then
            local matched = false
            for term in entry:gmatch("[^|]+") do
                if matchesTerm(toolName, term) then
                    matched = true
                    break
                end
            end
            if not matched then
                return false
            end
        else
            if not matchesTerm(toolName, entry) then
                return false
            end
        end
    end

    return true
end

return ToolNameValidityCheck

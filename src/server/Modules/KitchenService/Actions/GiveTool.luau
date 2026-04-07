--[[
    Module: GiveTool
    Description: Action that clones a tool and equips it to the player's character.
--]]

---> Helpers

local function getHeldTool(player: Player): Tool?
    return (player.Character and player.Character:FindFirstChildWhichIsA("Tool"))
end

---> Action

local function GiveTool(player: Player, _actionModel: Model, toolToClone: Tool): boolean
    local character = player.Character
    if not character then
        return false
    end

    local held = getHeldTool(player)
    if held then
        held.Parent = player.Backpack
    end

    local clone = toolToClone:Clone()

    local autoWeld = clone:GetAttribute("AutoWeld")
    if autoWeld == true or autoWeld == nil then
        local handle = clone:FindFirstChild("Handle") :: BasePart?
        if handle then
            for _, part in clone:GetDescendants() do
                if part:IsA("BasePart") and part ~= handle then
                    local weld = Instance.new("WeldConstraint")
                    weld.Part0 = handle
                    weld.Part1 = part :: BasePart
                    weld.Parent = handle
                end
            end
        end
    end

    for _, part in clone:GetDescendants() do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = false
        end
    end

    clone.Parent = character
    return true
end

return GiveTool

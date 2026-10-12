--[[
    Module: SmoothieLiquid
    Description: Action that blends the fruit in the player's held cup into a smoothie —
    recolours the liquid, removes the whole fruit, welds a garnish slice to the rim, and
    renames the tool. The rename lives here because this is the only step that knows which
    fruit the cup was tagged with by AddFruit.
--]]

---> Requires

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Recipes = require(ReplicatedStorage.Shared.Kitchen.Recipes)

---> Assets

local SelectorModels = ReplicatedStorage:WaitForChild("SelectorModels")
local FruitSlices = SelectorModels:WaitForChild("Fruits Slices")

---> Constants

local FRUIT_TAG_NAME = "Fruit"
local FRUIT_MODEL_NAME = "FruitModel"
local GARNISH_MODEL_NAME = "GarnishModel"
local SMOOTHIE_MATERIAL = Enum.Material.Sand

---> Helpers

local function getHeldTool(player: Player): Tool?
    return (player.Character and player.Character:FindFirstChildWhichIsA("Tool"))
end

---> Action

local function SmoothieLiquid(player: Player, _actionModel: Model): boolean
    local tool = getHeldTool(player)
    if not tool then
        return false
    end

    local tag = tool:FindFirstChild(FRUIT_TAG_NAME)
    if not tag or not tag:IsA("StringValue") then
        return false
    end

    local liquid = tool:FindFirstChild("Liquid")
    if not liquid or not liquid:IsA("BasePart") then
        return false
    end

    local smoothieName = tag.Value .. " Smoothie"

    local color = Recipes.Smoothies[smoothieName]
    if not color then
        warn(string.format("[SmoothieLiquid] No smoothie colour for '%s'.", smoothieName))
        return false
    end

    liquid.Color = color
    liquid.Material = SMOOTHIE_MATERIAL

    -- "<Size> Clear Cup + [Fruit] + Milk" --> "<Size> Strawberry Smoothie".
    -- Size is preserved so orders can still validate Small/Medium/Large.
    local size = tool.Name:match("^(%a+) ")
    tool.Name = if size then string.format("%s %s", size, smoothieName) else smoothieName

    -- The whole fruit is consumed by blending.
    local fruitModel = tool:FindFirstChild(FRUIT_MODEL_NAME)
    if fruitModel then
        fruitModel:Destroy()
    end

    local garnishName = Recipes.SmoothiesGarnish[smoothieName]
    local rim = tool:FindFirstChild("Slice")
    if not garnishName or not rim or not rim:IsA("BasePart") then
        -- Colour change already applied; a missing garnish is cosmetic only.
        return true
    end

    local template = FruitSlices:FindFirstChild(garnishName)
    if not template or not template:IsA("Model") then
        warn(string.format("[SmoothieLiquid] No garnish model named '%s'.", garnishName))
        return true
    end

    local existing = tool:FindFirstChild(GARNISH_MODEL_NAME)
    if existing then
        existing:Destroy()
    end

    local model = template:Clone()
    model.Name = GARNISH_MODEL_NAME

    local primaryPart = model.PrimaryPart
    if not primaryPart then
        model:Destroy()
        warn(string.format("[SmoothieLiquid] Garnish model '%s' has no PrimaryPart.", garnishName))
        return true
    end

    model:PivotTo(rim.CFrame)
    model.Parent = tool

    local weld = Instance.new("Weld")
    weld.Part0 = rim
    weld.Part1 = primaryPart
    local offset = CFrame.new(rim.Position)
    weld.C0 = rim.CFrame:Inverse() * offset
    weld.C1 = primaryPart.CFrame:Inverse() * offset
    weld.Parent = primaryPart

    primaryPart.Anchored = false
    primaryPart.Transparency = 1

    return true
end

return SmoothieLiquid

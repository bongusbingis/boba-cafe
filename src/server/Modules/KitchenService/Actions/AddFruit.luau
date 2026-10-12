--[[
    Module: AddFruit
    Description: Action that drops a fruit into the player's held cup, tagging the
    tool with the fruit name so the Blender can later resolve which smoothie to make.
--]]

---> Requires

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> Assets

local SelectorModels = ReplicatedStorage:WaitForChild("SelectorModels")
local FruitCups = SelectorModels:WaitForChild("Fruits Cups")

---> Constants

local FRUIT_TAG_NAME = "Fruit"
local FRUIT_MODEL_NAME = "FruitModel"

---> Helpers

local function getHeldTool(player: Player): Tool?
    return (player.Character and player.Character:FindFirstChildWhichIsA("Tool"))
end

---> Action

local function AddFruit(player: Player, _actionModel: Model, fruitName: string): boolean
    local tool = getHeldTool(player)
    if not tool then
        return false
    end

    local anchor = tool:FindFirstChild("Bottom")
    if not anchor or not anchor:IsA("BasePart") then
        return false
    end

    local template = FruitCups:FindFirstChild(fruitName)
    if not template or not template:IsA("Model") then
        warn(string.format("[AddFruit] No fruit model named '%s'.", fruitName))
        return false
    end

    -- A cup only ever holds one fruit; replace whatever was there.
    local existing = tool:FindFirstChild(FRUIT_MODEL_NAME)
    if existing then
        existing:Destroy()
    end

    local tag = tool:FindFirstChild(FRUIT_TAG_NAME)
    if not tag or not tag:IsA("StringValue") then
        tag = Instance.new("StringValue")
        tag.Name = FRUIT_TAG_NAME
        tag.Parent = tool
    end
    (tag :: StringValue).Value = fruitName

    local model = template:Clone()
    model.Name = FRUIT_MODEL_NAME

    local primaryPart = model.PrimaryPart
    if not primaryPart then
        model:Destroy()
        warn(string.format("[AddFruit] Fruit model '%s' has no PrimaryPart.", fruitName))
        return false
    end

    -- Random yaw so stacked fruit does not look identical between cups.
    model:PivotTo(anchor.CFrame * CFrame.Angles(math.rad(90), math.rad(math.random(-180, 180)), 0))
    model.Parent = tool

    local weld = Instance.new("Weld")
    weld.Part0 = anchor
    weld.Part1 = primaryPart
    local offset = CFrame.new(anchor.Position)
    weld.C0 = anchor.CFrame:Inverse() * offset
    weld.C1 = primaryPart.CFrame:Inverse() * offset
    weld.Parent = primaryPart

    primaryPart.Anchored = false
    primaryPart.Transparency = 1

    return true
end

return AddFruit

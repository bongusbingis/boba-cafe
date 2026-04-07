--[[
    Module: PromptBuilder
    Description: Creates and destroys ProximityPrompts on kitchen models.
--]]

---> Requires

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local KitchenTypes = require(ReplicatedStorage.Shared.Kitchen.KitchenTypes)
local KitchenConfig = require(ReplicatedStorage.Shared.Configuration.KitchenConfig)

---> Types

type PromptConfig = KitchenTypes.PromptConfig

---> Module

local PromptBuilder = {}

---> Functions

function PromptBuilder.Attach(model: Model, config: PromptConfig, callback: (Player) -> ()): ProximityPrompt
    local cf, _ = model:GetBoundingBox()

    local part = Instance.new("Part")
    part.Size = Vector3.one * 0.1
    part.CFrame = cf
    part.CanCollide = false
    part.Anchored = true
    part.Transparency = 1
    part.Parent = model

    model.PrimaryPart = part

    local holdDuration = config.HoldDuration or 3
    if RunService:IsStudio() then
        holdDuration = 0.1
    end

    local prompt = Instance.new("ProximityPrompt")
    -- prompt.Style = Enum.ProximityPromptStyle.Custom
    prompt.ObjectText = config.Label
    prompt.ActionText = config.ActionText
    prompt.RequiresLineOfSight = false
    prompt.HoldDuration = holdDuration
    prompt.MaxActivationDistance = KitchenConfig.PROMPT_DISTANCE
    prompt.Parent = part

    prompt.Triggered:Connect(callback)

    return prompt
end

function PromptBuilder.Detach(model: Model)
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("ProximityPrompt") then
            local parent = descendant.Parent
            descendant:Destroy()
            if parent and parent ~= model then
                parent:Destroy()
            end
            break
        end
    end
end

return PromptBuilder

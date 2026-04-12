--[[
    Module: KitchenService
    Description: Knit service that manages kitchen interaction prompts and action execution.
--]]

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local SelectorModels = ReplicatedStorage:WaitForChild("SelectorModels")

---> Requires

local Knit = require(Packages.Knit)
local ActionRegistry = require(script.ActionRegistry)
local InteractionRunner = require(script.InteractionRunner)
local PromptBuilder = require(script.PromptBuilder)
local Recipes = require(ReplicatedStorage.Shared.Kitchen.Recipes)
local KitchenConfig = require(ReplicatedStorage.Shared.Configuration.KitchenConfig)
local KitchenTypes = require(ReplicatedStorage.Shared.Kitchen.KitchenTypes)
local RankUtil = require(ReplicatedStorage.Shared.Utility.RankUtil)

---> Types

type RecipeData = KitchenTypes.RecipeData

---> Service

local KitchenService = Knit.CreateService({
    Name = "KitchenService",
    Client = {
        InteractionFailed = Knit.CreateSignal(),
    },
    _runner = nil :: any,
    _registry = nil :: any,
    _prompts = {} :: { [string]: { ProximityPrompt } },
})

---> Private

function KitchenService:_spawnSyrupDispensers()
    local Kitchen = workspace.Assets.Kitchen
    local numSyrups = 0
    for _ in Recipes.Syrups do
        numSyrups += 1
    end

    for _, syrupsArea: Part in Kitchen.Syrups:GetChildren() do
        local n = 0
        for name: string, color: Color3 in Recipes.Syrups do
            n += 1
            local syrupDispenser = SelectorModels.Kitchen.SyrupDispenser:Clone()
            local dispenserPosition = ((syrupsArea.Size.X / (numSyrups + 1)) * n) - syrupsArea.Size.X / 2
            syrupDispenser:PivotTo(syrupsArea.CFrame * CFrame.new(dispenserPosition, 0, 0))
            syrupDispenser.Name = name .. " Syrup"
            syrupDispenser.Liquid.Color = color
            syrupDispenser.Rim.Color = color
            syrupDispenser.Parent = Kitchen.Syrups
        end
    end
end

function KitchenService:_getMatchingModels(itemName: string): { Model }
    local results = {}
    local kitchenFolder = workspace.Assets.Kitchen
    for _, descendant in kitchenFolder:GetDescendants() do
        if descendant:IsA("Model") and descendant.Name == itemName then
            table.insert(results, descendant)
        end
    end
    return results
end

---> Lifecycle

function KitchenService:KnitInit()
    local registry = ActionRegistry
    registry.Load(script.Actions)
    self._registry = registry

    self._runner = InteractionRunner.new(registry, function(player: Player, reason: string)
        self.Client.InteractionFailed:Fire(player, reason)
    end)
end

function KitchenService:KnitStart()
    self:_spawnSyrupDispensers()

    for itemName, recipeData: RecipeData in Recipes.Items do
        local models = self:_getMatchingModels(itemName)
        self._prompts[itemName] = {}

        for _, model in models do
            local prompt = PromptBuilder.Attach(
                model,
                { Label = itemName, ActionText = "Interact", HoldDuration = recipeData.HoldDuration },
                function(player: Player)
                    if not RankUtil:CanEnterKitchen(player) then
                        return
                    end

                    local primaryPart = model.PrimaryPart
                    if not primaryPart then
                        return
                    end

                    local character = player.Character
                    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                    if not rootPart then
                        return
                    end

                    local distance = (rootPart.Position - primaryPart.Position).Magnitude
                    if distance > KitchenConfig.MAX_INTERACTION_DISTANCE then
                        return
                    end

                    self._runner:Run(player, recipeData, model)
                end
            )

            table.insert(self._prompts[itemName], prompt)
        end
    end
end

---> Public

function KitchenService:SetItemEnabled(itemName: string, enabled: boolean)
    local prompts = self._prompts[itemName]
    if not prompts then
        return
    end

    for _, prompt in prompts do
        prompt.Enabled = enabled
    end
end

return KitchenService

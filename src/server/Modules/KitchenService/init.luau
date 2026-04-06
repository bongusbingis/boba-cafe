--[[
    Module: KitchenService
    Description: Knit service that manages kitchen interaction prompts and action execution.
--]]

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Packages = ReplicatedStorage:WaitForChild("Packages")

---> Requires

local Knit = require(Packages.Knit)
local ActionRegistry = require(script.ActionRegistry)
local InteractionRunner = require(script.InteractionRunner)
local PromptBuilder = require(script.PromptBuilder)
local Recipes = require(ReplicatedStorage.Shared.Kitchen.Recipes)
local KitchenConfig = require(ReplicatedStorage.Shared.Configuration.KitchenConfig)
local KitchenTypes = require(ReplicatedStorage.Shared.Kitchen.KitchenTypes)
local RankUtil = require(ReplicatedStorage.Shared.Wrappers.RankUtil)

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

function KitchenService:_getMatchingModels(itemName: string): { Model }
    local results = {}
    local kitchenFolder = Workspace.Assets.Kitchen
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
    for itemName, recipeData: RecipeData in Recipes.Items do
        local models = self:_getMatchingModels(itemName)
        self._prompts[itemName] = {}

        for _, model in models do
            local prompt = PromptBuilder.Attach(
                model,
                { Label = itemName, ActionText = "Interact" },
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

                    self._runner:Run(player, recipeData)
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

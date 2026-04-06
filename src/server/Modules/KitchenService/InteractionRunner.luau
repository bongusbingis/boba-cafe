--[[
    Module: InteractionRunner
    Description: Runs recipe action sequences for players with per-player debouncing.
--]]

---> Requires

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KitchenTypes = require(ReplicatedStorage.Shared.Kitchen.KitchenTypes)
local KitchenConfig = require(ReplicatedStorage.Shared.Configuration.KitchenConfig)

---> Types

type ActionData = KitchenTypes.ActionData
type RecipeData = KitchenTypes.RecipeData
type InteractionResult = KitchenTypes.InteractionResult

type ActionRegistry = {
    Get: (self: any, name: string) -> KitchenTypes.ActionFn?,
    Has: (self: any, name: string) -> boolean,
    Load: (self: any, folder: Folder) -> (),
}

type InteractionRunner = {
    _debounces: { [Player]: boolean },
    _registry: ActionRegistry,
    _onFailure: (player: Player, reason: string) -> (),
    Run: (self: InteractionRunner, player: Player, recipeData: RecipeData) -> (),
    _runSequence: (self: InteractionRunner, player: Player, actions: { ActionData }) -> InteractionResult,
}

---> Module

local InteractionRunner = {}
InteractionRunner.__index = InteractionRunner

---> Constructor

function InteractionRunner.new(
    registry: ActionRegistry,
    onFailure: (player: Player, reason: string) -> ()
): InteractionRunner
    return setmetatable({
        _debounces = {},
        _registry = registry,
        _onFailure = onFailure,
    }, InteractionRunner) :: any
end

---> Private

function InteractionRunner:_runSequence(player: Player, actions: { ActionData }): InteractionResult
    for _, actionData in actions do
        local actionName = actionData[1] :: string
        local actionFn = self._registry:Get(actionName)

        if not actionFn then
            warn(string.format("[InteractionRunner] Unknown action: '%s'", actionName))
            return { Success = false, Error = "Unknown action: " .. actionName }
        end

        local ok = actionFn(player, table.unpack(actionData, 2))
        if not ok then
            return { Success = false, Error = actionName .. " rejected" }
        end
    end

    return { Success = true }
end

---> Public

function InteractionRunner:Run(player: Player, recipeData: RecipeData)
    if self._debounces[player] then
        return
    end

    self._debounces[player] = true

    task.spawn(function()
        local result = self:_runSequence(player, recipeData.Actions)

        if not result.Success then
            self._onFailure(player, result.Error :: string)
        end

        task.wait(KitchenConfig.INTERACTION_COOLDOWN)
        self._debounces[player] = nil
    end)
end

return InteractionRunner

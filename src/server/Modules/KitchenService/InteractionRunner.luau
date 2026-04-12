--[[
    Module: InteractionRunner
    Description: Runs recipe action sequences for players with per-player debouncing.
--]]

---> Requires

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)
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
    Run: (self: InteractionRunner, player: Player, recipeData: RecipeData, model: Model) -> (),
    _runSequence: (self: InteractionRunner, player: Player, model: Model, actions: { ActionData }) -> InteractionResult,
    _runSelectFrom: (self: InteractionRunner, player: Player, model: Model, actionData: ActionData) -> InteractionResult,
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

function InteractionRunner:_runSelectFrom(player: Player, model: Model, actionData: ActionData): InteractionResult
    local promptConfig = actionData[2] :: {
        Title: string?,
        Text: string?,
        Buttons: { { Text: string } }?,
        DialogType: string?,
        Items: { { Name: string, Model: Instance?, Color: Color3?, IsTip: boolean? } }?,
    }
    local branchMap = actionData[3] :: { [string]: { ActionData } }

    local DialogService = Knit.GetService("DialogService")
    local choice: string? = nil

    if promptConfig.DialogType == "PromptSelection" then
        local promptItems = promptConfig.Items or {}
        local okPrompt, selectedIndex = DialogService:CreatePromptSelection(player, promptItems, {
            Title = promptConfig.Title,
            Text = promptConfig.Text,
        }):await()

        if not okPrompt or selectedIndex == nil then
            return { Success = true }
        end

        if typeof(selectedIndex) ~= "number" then
            warn(string.format("[InteractionRunner] PromptSelection returned invalid index: %s", tostring(selectedIndex)))
            return { Success = false, Error = "SelectFrom: invalid prompt selection" }
        end

        local selectedItem = promptItems[selectedIndex]
        if selectedItem and typeof(selectedItem.Name) == "string" and selectedItem.Name ~= "" then
            choice = selectedItem.Name
        elseif promptConfig.Buttons and promptConfig.Buttons[selectedIndex] then
            choice = promptConfig.Buttons[selectedIndex].Text
        end

        if not choice then
            warn(string.format("[InteractionRunner] PromptSelection: no option for index '%s'", tostring(selectedIndex)))
            return { Success = false, Error = "SelectFrom: missing prompt option" }
        end
    else
        local okPrompt, actionChoice = DialogService:CreateDialog(player, "ActionPrompt", promptConfig):await()

        if not okPrompt or actionChoice == nil or actionChoice == "Close" then
            return { Success = true }
        end

        if typeof(actionChoice) ~= "string" then
            warn(string.format("[InteractionRunner] ActionPrompt returned invalid choice: %s", tostring(actionChoice)))
            return { Success = false, Error = "SelectFrom: invalid choice" }
        end

        choice = actionChoice
    end

    local branch = branchMap[choice]
    if not branch then
        warn(string.format("[InteractionRunner] SelectFrom: no branch for choice '%s'", tostring(choice)))
        return { Success = false, Error = "SelectFrom: invalid choice" }
    end

    return self:_runSequence(player, model, branch)
end

function InteractionRunner:_runSequence(player: Player, model: Model, actions: { ActionData }): InteractionResult
    for _, actionData in actions do
        local actionName = actionData[1] :: string

        if actionName == "SelectFrom" then
            local result = self:_runSelectFrom(player, model, actionData)
            if not result.Success then
                return result
            end
            continue
        end

        local actionFn = self._registry.Get(actionName)

        if not actionFn then
            warn(string.format("[InteractionRunner] Unknown action: '%s'", actionName))
            return { Success = false, Error = "Unknown action: " .. actionName }
        end

        local ok = actionFn(player, model, table.unpack(actionData, 2))
        if not ok then
            return { Success = false, Error = actionName .. " rejected" }
        end
    end

    return { Success = true }
end

---> Public

function InteractionRunner:Run(player: Player, recipeData: RecipeData, model: Model)
    if self._debounces[player] then
        return
    end

    self._debounces[player] = true

    task.spawn(function()
        local result = self:_runSequence(player, model, recipeData.Actions)

        if not result.Success then
            self._onFailure(player, result.Error :: string)
        end

        task.wait(KitchenConfig.INTERACTION_COOLDOWN)
        self._debounces[player] = nil
    end)
end

return InteractionRunner

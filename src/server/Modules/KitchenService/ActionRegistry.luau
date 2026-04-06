--[[
    Module: ActionRegistry
    Description: Loads and stores kitchen action functions by name for runtime lookup.
--]]

---> Requires

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KitchenTypes = require(ReplicatedStorage.Shared.Kitchen.KitchenTypes)

---> Types

type ActionFn = KitchenTypes.ActionFn

---> State

local _actions: { [string]: ActionFn } = {}

---> Registry

local ActionRegistry = {}

function ActionRegistry.Load(actionsFolder: Folder)
    for _, child in actionsFolder:GetChildren() do
        local action = require(child)
        if typeof(action) == "function" then
            _actions[child.Name] = action
        else
            warn(string.format("[ActionRegistry] Module '%s' did not return a function — skipped.", child.Name))
        end
    end
end

function ActionRegistry.Get(name: string): ActionFn?
    return _actions[name]
end

function ActionRegistry.Has(name: string): boolean
    return _actions[name] ~= nil
end

return ActionRegistry

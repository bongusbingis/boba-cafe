--[[
    Module: Recipes
    Description: Pure data definitions mapping recipe names to their ordered action lists.

    WARNING: This file must never contain server logic, RemoteEvent calls,
    or any code that has side effects. It is intended to be safe for
    replication to the client. Keep it as plain data only.
--]]

---> Services

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> Assets

local SharedStorage = ReplicatedStorage:WaitForChild("SharedStorage")
local Tools = SharedStorage.Tools
local Animations = SharedStorage.Animations.Kitchen

---> Recipes

local Recipes = {}

Recipes.Items = {
    ["Cup"] = {
        Actions = {
            { "AnimateRaw", Animations.Grab_01, true },
            { "GiveTool", Tools.Kitchen["Cup"] },
        },
    },
    ["Tea Cup"] = {
        Actions = {
            { "AnimateRaw", Animations.Grab_01, true },
            { "GiveTool", Tools.Kitchen["Tea Cup"] },
        },
    },
    ["Lids"] = {
        Actions = {
            { "ToolNameValidityCheck", { "Cup|Milk Tea|Soda", "!Tea Cup" } },
            { "SetToolHoldingProperty", "Lid", "Transparency", 0.25 },
        },
    },
    ["Straws"] = {
        Actions = {
            { "ToolNameValidityCheck", { "Cup|Milk Tea|Soda", "!Tea Cup" } },
            { "SetToolHoldingProperty", "Straw", "Transparency", 0 },
        },
    },
    ["Milk Tea"] = {
        Actions = {
            { "ToolNameValidityCheck", { "Cup", "!Milk Tea", "!Tea Cup" } },
            { "SetToolHoldingProperty", "Liquid", "Transparency", 0 },
            { "SetToolHoldingProperty", "Boba", "Transparency", 0 },
            { "RenameToolHolding", "Milk Tea" },
        },
    },
    ["Tea"] = {
        Actions = {
            { "ToolNameValidityCheck", { "Tea Cup" } },
            { "SetToolHoldingProperty", "Liquid", "Transparency", 0.25 },
            { "RenameToolHolding", "Tea" },
        },
    },
}

return Recipes

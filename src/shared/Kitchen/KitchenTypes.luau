--[[
    Module: KitchenTypes
    Description: Shared type definitions for the kitchen interaction system.
--]]

---> Types

export type ActionData = { any }

export type RecipeData = {
    Actions: { ActionData },
}

export type ActionFn = (player: Player, ...any) -> boolean

export type InteractionResult = {
    Success: boolean,
    Error: string?,
}

export type PromptConfig = {
    Label: string,
    ActionText: string,
}

return {}

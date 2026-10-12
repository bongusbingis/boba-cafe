--[[
    Module: KitchenTypes
    Description: Shared type definitions for the kitchen interaction system.
--]]

---> Types

export type ActionData = { any }

-- A visual change applied to the station model on the client while an animation plays
-- (e.g. fading a blender lid). Declared as data rather than a callback so Recipes stays
-- free of side effects and safe to replicate.
export type StationEffect = {
    Type: "SetTransparency",
    Target: string, -- name of a descendant of the station model
    Value: number,
    Duration: number?,
}

export type AnimationSpec = {
    Animation: Animation,
    HoldInLeftHand: Accessory?, -- prop cloned onto the player's left hand for the duration
    DoActionAfter: number?, -- seconds to wait before continuing; defaults to the full animation
    Effect: StationEffect?,
}

export type RecipeData = {
    Sound: string?,
    HoldDuration: number?,
    Actions: { ActionData },
}

export type ActionFn = (player: Player, actionModel: Model, ...any) -> boolean

export type InteractionResult = {
    Success: boolean,
    Error: string?,
}

export type PromptConfig = {
    Label: string,
    ActionText: string,
    HoldDuration: number?, -- default 3
}

return {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useCamera = require(script.Parent.useCamera)
local useEventListener = require(script.Parent.useEventListener)

local BASE_RESOLUTION = Vector2.new(1280, 832)

local function useDebounceState(initialState, options)
    local state, setState = React.useState(initialState)
    local pendingRef = React.useRef(nil)
    local wait = (options and options.wait) or 0
    local leading = (options and options.leading) or false

    local debouncedSet = React.useCallback(function(value)
        local isFirst = pendingRef.current == nil

        if pendingRef.current then
            task.cancel(pendingRef.current)
        end

        if leading and isFirst then
            setState(value)
        end

        pendingRef.current = task.delay(wait, function()
            pendingRef.current = nil
            setState(value)
        end)
    end, {})

    return state, debouncedSet
end
local MIN_SCALE = 0.75
local DOMINANT_AXIS = 0.5

--[[
    @see https://discord.com/channels/476080952636997633/476080952636997635/1146857136358432900
]]
local function calculateScale(viewport: Vector2): number
    local width = math.log(viewport.X / BASE_RESOLUTION.X) / math.log(2)
    local height = math.log(viewport.Y / BASE_RESOLUTION.Y) / math.log(2)
    local centered = width + (height - width) * DOMINANT_AXIS
    return math.max(2 ^ centered, MIN_SCALE)
end

export type ScaleFunction = typeof(setmetatable(
    {} :: {
        --- Scales `pixels` and rounds the result to the nearest even number.
        even: (pixels: number) -> number,
        --- Scales a number based on the current viewport size without rounding.
        scale: (percent: number) -> number,
        --- Scales `pixels` and rounds the result down.
        floor: (pixels: number) -> number,
        --- Scales `pixels` and rounds the result up.
        ceil: (pixels: number) -> number,
    },
    {} :: { __call: (self: any, pixels: number) -> number }
))

local function usePx(): ScaleFunction
    local camera = useCamera()

    local scale, setScale = useDebounceState(calculateScale(camera.ViewportSize), {
        wait = 0.2,
        leading = true,
    })

    useEventListener(camera:GetPropertyChangedSignal("ViewportSize"), function()
        setScale(calculateScale(camera.ViewportSize))
    end)

    return React.useMemo(function()
        local api = {
            even = function(value: number)
                return math.round(value * scale * 0.5) * 2
            end,
            scale = function(value: number)
                return value * scale
            end,
            floor = function(value: number)
                return math.floor(value * scale)
            end,
            ceil = function(value: number)
                return math.ceil(value * scale)
            end,
        }

        setmetatable(api, {
            __call = function(_, value: number)
                return math.round(value * scale)
            end,
        })

        return api :: ScaleFunction
    end, { scale })
end

return usePx
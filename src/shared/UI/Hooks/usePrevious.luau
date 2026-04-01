local React = require(game:GetService("ReplicatedStorage").Packages.React)

local useRef = React.useRef
local useMemo = React.useMemo

-- Default predicate: strict equality
local function isStrictEqual(a, b)
    return a == b
end

--[[
    Returns the most recent value from the previous render. Returns `nil`
    on the first render.

    Takes an optional `predicate` function as the second argument that receives
    the previous and current value. If the predicate returns `false`, the values
    are not equal, and the previous value is updated.

    @param value The value to return on the next render if it changes.
    @param predicate Optional function to determine whether the value changed.
    Defaults to a strict equality check (==).
    @returns The previous value, or nil on the first render.
]]
local function usePrevious(value, predicate)
    predicate = predicate or isStrictEqual

    local previousRef = useRef(nil)
    local currentRef = useRef(nil)

    useMemo(function()
        if not predicate(currentRef.current, value) then
            previousRef.current = currentRef.current
            currentRef.current = value
        end
    end, { value })

    return previousRef.current
end

return {
    usePrevious = usePrevious,
    isStrictEqual = isStrictEqual,
}
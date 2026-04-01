local React = require(game:GetService("ReplicatedStorage").Packages.React)
local usePrevious = require(script.Parent.usePrevious)

local useRef = React.useRef
local useMemo = React.useMemo
local isStrictEqual = usePrevious.isStrictEqual

--[[
    Returns a mutable ref that points to the latest value of the input.

    Takes an optional `predicate` function as the second argument that receives
    the previous and current value. If the predicate returns `false`, the values
    are not equal, and the previous value is updated.

    @param value The value to track.
    @param predicate Optional equality function. Defaults to isStrictEqual.
    @returns A mutable reference to the value.
]]
local function useLatest(value, predicate)
    predicate = predicate or isStrictEqual

    local ref = useRef(value)

    useMemo(function()
        if not predicate(ref.current, value) then
            ref.current = value
        end
    end, { value })

    return ref
end

return useLatest
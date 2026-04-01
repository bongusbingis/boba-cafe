local React = require(game:GetService("ReplicatedStorage").Packages.React)
local useLatest = require(script.Parent.useLatest)

local useEffect = React.useEffect

-- Connects to an event-like object, handling RBXScriptSignal and table-based events.
local function connect(event, callback)
    if typeof(event) == "RBXScriptSignal" then
        -- With deferred events, a "hard disconnect" is necessary to avoid causing
        -- state updates after a component unmounts. Use 'Connected' to check if
        -- the connection is still valid before invoking the callback.
        -- https://devforum.roblox.com/t/deferred-engine-events/2276564/99
        local connection
        connection = event:Connect(function(...)
            if connection.Connected then
                callback(...)
            end
        end)
        return connection
    elseif typeof(event) == "table" then
        if event.Connect then
            return event:Connect(callback)
        elseif event.connect then
            return event:connect(callback)
        elseif event.subscribe then
            return event:subscribe(callback)
        else
            error("Event-like object does not have a supported connect method.")
        end
    else
        error("Event-like object does not have a supported connect method.")
    end
end

-- Disconnects a connection-like object.
local function disconnect(connection)
    if typeof(connection) == "function" then
        connection()
    elseif typeof(connection) == "RBXScriptConnection" or
        (typeof(connection) == "table" and connection.Disconnect) then
        connection:Disconnect()
    elseif typeof(connection) == "table" and connection.disconnect then
        connection:disconnect()
    else
        error("Connection-like object does not have a supported disconnect method.")
    end
end

--[[
    Subscribes to an event-like object. The subscription is automatically
    disconnected when the component unmounts.

    If the event or listener is nil, the event will not be subscribed to,
    and the subscription will be disconnected if it was previously connected.

    The listener is memoized, so it is safe to pass a callback that is recreated
    on every render.

    @param event The event-like object to subscribe to.
    @param listener The listener to subscribe with.
    @param options Options for the subscription (connected, once).
]]
local function useEventListener(event, listener, options)
    options = options or {}
    local once = if options.once ~= nil then options.once else false
    local connected = if options.connected ~= nil then options.connected else true

    local listenerRef = useLatest(listener)

    useEffect(function()
        if not event or not listener or not connected then
            return
        end

        local canDisconnect = true

        local connection
        connection = connect(event, function(...)
            if once then
                disconnect(connection)
                canDisconnect = false
            end
            if listenerRef.current then
                listenerRef.current(...)
            end
        end)

        return function()
            if canDisconnect then
                disconnect(connection)
            end
        end
    end, { event, connected, listener ~= nil })
end

return useEventListener
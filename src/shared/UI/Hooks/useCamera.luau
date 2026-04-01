local React = require(game:GetService("ReplicatedStorage").Packages.React)
local Workspace = game:GetService("Workspace")
local useEventListener = require(script.Parent.useEventListener)

local useState = React.useState

--[[
    Returns the current camera. Updates when the current camera changes.
    @returns A camera instance.
]]
local function useCamera()
    local camera, setCamera = useState(Workspace.CurrentCamera)

    useEventListener(Workspace:GetPropertyChangedSignal("CurrentCamera"), function()
        if Workspace.CurrentCamera then
            setCamera(Workspace.CurrentCamera)
        end
    end)

    return camera
end

return useCamera
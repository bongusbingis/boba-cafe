--[[
    Module: AnimateRaw
    Description: Action that plays an animation on the player's character and waits for it to finish.
--]]

---> Requires

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KitchenConfig = require(ReplicatedStorage.Shared.Configuration.KitchenConfig)

---> Action

local function AnimateRaw(player: Player, _actionModel: Model, animationInstance: Animation, useMarker: boolean?): boolean
    local character = player.Character
    if not character then
        return false
    end

    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    if not humanoid then
        return false
    end

    local track = humanoid.Animator:LoadAnimation(animationInstance)
    track:Play()

    if useMarker then
        local done = false
        track:GetMarkerReachedSignal(KitchenConfig.ANIMATION_MARKER_NAME):Once(function()
            done = true
        end)
        repeat task.wait() until done or not track.IsPlaying
    else
        track.Ended:Wait()
    end

    return true
end

return AnimateRaw

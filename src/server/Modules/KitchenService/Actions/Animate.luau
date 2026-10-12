--[[
    Module: Animate
    Description: Richer animation action — plays an animation, optionally puts a temporary
    prop in the player's left hand (spoon, blender lid), optionally asks the client to
    apply a visual effect to the station model, and waits either a fixed offset or for the
    animation to finish.

    Use AnimateRaw for the simple "play and wait" case.
--]]

---> Requires

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local KitchenTypes = require(ReplicatedStorage.Shared.Kitchen.KitchenTypes)
local GamepassUtil = require(ReplicatedStorage.Shared.Utility.GamepassUtil)

---> constants

-- "Instant Brew" game pass: speeds up kitchen animations and shortens the wait by the
-- same proportion, matching the old game's behaviour.
local INSTANT_BREW_PASS_ID = 12385760
local INSTANT_BREW_SPEED = 1.5

---> Types

type AnimationSpec = KitchenTypes.AnimationSpec

---> State

-- Effect targets are named parts in the build. If the build has not added one yet the
-- effect is skipped; warn once per station rather than on every interaction.
local _warnedMissingTargets: { [string]: boolean } = {}

---> Helpers

local function resolveEffectTarget(actionModel: Model, targetName: string): Instance?
    if actionModel.Name == targetName then
        return actionModel
    end

    return actionModel:FindFirstChild(targetName, true)
end

---> Action

local function Animate(player: Player, actionModel: Model, spec: AnimationSpec): boolean
    local character = player.Character
    if not character then
        return false
    end

    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
    if not humanoid then
        return false
    end

    if not spec or not spec.Animation then
        warn("[Animate] Missing animation in spec.")
        return false
    end

    local track = humanoid.Animator:LoadAnimation(spec.Animation)

    -- The prop is purely cosmetic, so failing to attach it must not fail the recipe.
    local prop: Accessory? = nil
    if spec.HoldInLeftHand then
        local ok, cloned = pcall(function()
            local clone = spec.HoldInLeftHand:Clone()
            humanoid:AddAccessory(clone)
            return clone
        end)

        if ok then
            prop = cloned
        else
            warn(string.format("[Animate] Could not attach prop '%s'.", spec.HoldInLeftHand.Name))
        end
    end

    -- Instant Brew owners brew faster: the animation is sped up and the wait below is
    -- shortened by the same factor, so the pass actually saves time rather than just
    -- looking quicker.
    local speed = 1
    if GamepassUtil:PlayerOwnsPassAsync(player, INSTANT_BREW_PASS_ID) then
        speed = INSTANT_BREW_SPEED
        track:AdjustSpeed(speed)
    end

    track:Play()

    if spec.Effect then
        local target = resolveEffectTarget(actionModel, spec.Effect.Target)
        if target then
            Knit.GetService("KitchenService").Client.StationEffect:Fire(
                player,
                spec.Effect.Type,
                target,
                spec.Effect.Value,
                spec.Effect.Duration or 0
            )
        else
            local key = actionModel.Name .. "/" .. spec.Effect.Target
            if not _warnedMissingTargets[key] then
                _warnedMissingTargets[key] = true
                warn(
                    string.format(
                        "[Animate] Effect target '%s' not found under '%s' — effect skipped.",
                        spec.Effect.Target,
                        actionModel.Name
                    )
                )
            end
        end
    end

    if spec.DoActionAfter then
        task.wait(spec.DoActionAfter / speed)
    else
        track.Ended:Wait()
    end

    if prop then
        prop:Destroy()
    end

    -- If the animation is still running past the offset, let it finish visually but
    -- do not hold the recipe up any further.
    return true
end

return Animate

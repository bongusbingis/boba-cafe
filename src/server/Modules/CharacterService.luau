--[[
    Module: CharacterService
    Description: Applies the cafe's standard character setup on spawn — hides Roblox's
    default name/health display and puts players in a non-colliding collision group.

    Overhead names are drawn by CosmeticsService, so the built-in Humanoid display is
    turned off to avoid two labels stacking.

    Players not colliding matters in a busy cafe: without it, a crowd at a register can
    wedge people into geometry.
--]]

---> services
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

---> module declaration
local CharacterService = Knit.CreateService({
    Name = "CharacterService",
})

---> constants

local PLAYER_COLLISION_GROUP = "PlayerCollision"

---> state

local collisionGroupReady = false

---> private

--- Registers the collision group once. Re-registering an existing group throws, and
--- the group survives across a soft-restart in Studio, so this is guarded.
local function ensureCollisionGroup()
    if collisionGroupReady then
        return
    end

    local ok = pcall(function()
        PhysicsService:RegisterCollisionGroup(PLAYER_COLLISION_GROUP)
    end)

    if not ok then
        -- Already registered — fine, we only need it to exist.
        collisionGroupReady = true
    end

    pcall(function()
        PhysicsService:CollisionGroupSetCollidable(
            PLAYER_COLLISION_GROUP,
            PLAYER_COLLISION_GROUP,
            false
        )
    end)

    collisionGroupReady = true
end

local function applyCharacter(character: Model)
    local humanoid = character:FindFirstChildWhichIsA("Humanoid")
        or character:WaitForChild("Humanoid", 10) :: Humanoid?

    if humanoid then
        -- CosmeticsService draws the overhead label instead.
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayDistance = 0
        humanoid.NameDisplayDistance = 0
    end

    for _, part in character:GetDescendants() do
        if part:IsA("BasePart") then
            part.CollisionGroup = PLAYER_COLLISION_GROUP
        end
    end

    -- Accessories and limbs can stream in after the character does.
    character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("BasePart") then
            descendant.CollisionGroup = PLAYER_COLLISION_GROUP
        end
    end)
end

---> lifecycle

function CharacterService:PlayerAdded(player: Player)
    ensureCollisionGroup()

    player.CharacterAdded:Connect(function(character)
        -- Isolated: a failure here must not stop the rest of the spawn pipeline.
        local ok, err = pcall(applyCharacter, character)
        if not ok then
            warn(`[CharacterService] Setup failed for {player.Name}: {err}`)
        end
    end)

    if player.Character then
        pcall(applyCharacter, player.Character)
    end
end

function CharacterService:KnitStart()
    ensureCollisionGroup()

    for _, player in Players:GetPlayers() do
        if player.Character then
            pcall(applyCharacter, player.Character)
        end
    end
end

return CharacterService

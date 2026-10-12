--[[
    Module: MopWhackService
    Description: "Mop Whack" game pass — gives owners a mop they can use to knock other
    players over.

    All validation is server-side: the client only asks to hit a target, and this service
    decides whether that is allowed (pass owned, tool equipped, target in range, target
    has not opted out, cooldown elapsed).
--]]

---> services
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local SharedStorage = ReplicatedStorage:WaitForChild("SharedStorage")

local Knit = require(Packages.Knit)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local RagdollUtil = require(Shared.Utility.RagdollUtil)

---> assets
local MOP_TOOL = SharedStorage.Tools.Kitchen["Mop Whack"] :: Tool

---> constants
local GAMEPASS_ID = 40973940
local TOOL_NAME = "Mop Whack"
local COOLDOWN_SECONDS = 15
local MAX_HIT_DISTANCE = 15
local RAGDOLL_DURATION = 3.2
local WHACK_WINDUP = 0.6
local KNOCKBACK_VELOCITY = 500

---> module declaration
local MopWhackService = Knit.CreateService({
    Name = "MopWhackService",
    Client = {
        MopStateChanged = Knit.CreateSignal(),
    },
})

---> state
local cooldowns: { [Player]: boolean } = {}

---> private

function MopWhackService:_giveMop(player: Player)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        return
    end

    -- Characters respawn with a fresh Backpack, so re-check rather than assume.
    if backpack:FindFirstChild(TOOL_NAME) then
        return
    end

    local character = player.Character
    if character and character:FindFirstChild(TOOL_NAME) then
        return
    end

    local tool = MOP_TOOL:Clone()

    -- The tool asset still carries V3's Animate script, which requires
    -- ReplicatedStorage.Boba and ServerScriptService.Services.RagdollService. Neither
    -- exists here, so it yields forever in every owner's backpack. Whacking is handled
    -- by this service instead, so strip any scripts that came with the model.
    for _, descendant in tool:GetDescendants() do
        if descendant:IsA("BaseScript") or descendant:IsA("ModuleScript") then
            descendant:Destroy()
        end
    end

    tool.Parent = backpack

    tool.Equipped:Connect(function()
        self.Client.MopStateChanged:Fire(player, true)
    end)

    tool.Unequipped:Connect(function()
        self.Client.MopStateChanged:Fire(player, false)
    end)
end

function MopWhackService:_setupPlayer(player: Player)
    if not GamepassUtil:PlayerOwnsPassAsync(player, GAMEPASS_ID) then
        return
    end

    player.CharacterAdded:Connect(function()
        -- Wait for the Backpack to be repopulated after the respawn.
        task.defer(function()
            self:_giveMop(player)
        end)
    end)

    if player.Character then
        self:_giveMop(player)
    end
end

local function getRootPart(player: Player): BasePart?
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

---> client

--- Attempts to whack `target`. Every precondition is re-validated here; the client is
--- only trusted to name a target.
function MopWhackService.Client:DoHit(player: Player, target: Player)
    return self.Server:Whack(player, target)
end

---> public

function MopWhackService:Whack(player: Player, target: Player): boolean
    if typeof(target) ~= "Instance" or not target:IsA("Player") or target == player then
        return false
    end

    if cooldowns[player] then
        return false
    end

    if not GamepassUtil:PlayerOwnsPassAsync(player, GAMEPASS_ID) then
        return false
    end

    local character = player.Character
    -- The tool must actually be equipped (parented to the character), not just owned.
    if not character or not character:FindFirstChild(TOOL_NAME) then
        return false
    end

    local attackerRoot = getRootPart(player)
    local targetRoot = getRootPart(target)
    if not attackerRoot or not targetRoot then
        return false
    end

    if (attackerRoot.Position - targetRoot.Position).Magnitude > MAX_HIT_DISTANCE then
        return false
    end

    cooldowns[player] = true
    task.delay(COOLDOWN_SECONDS, function()
        cooldowns[player] = nil
    end)

    task.wait(WHACK_WINDUP)

    -- Re-check after the wind-up: the target may have left or moved away.
    local freshTargetRoot = getRootPart(target)
    if not freshTargetRoot or not target.Character then
        return false
    end

    if (attackerRoot.Position - freshTargetRoot.Position).Magnitude > MAX_HIT_DISTANCE then
        return false
    end

    -- Players can opt out of being knocked over.
    local gotData, targetData = Knit.GetService("DataService"):GetDataAsync(target):await()
    if not gotData or not targetData or not targetData.Settings.Ragdollable then
        return false
    end

    if not RagdollUtil:Ragdoll(target.Character, RAGDOLL_DURATION) then
        return false
    end

    local primaryPart = target.Character.PrimaryPart
    if primaryPart then
        primaryPart.AssemblyLinearVelocity = character:GetPivot().LookVector * KNOCKBACK_VELOCITY
    end

    return true
end

---> lifecycle

function MopWhackService:PlayerAdded(player: Player)
    task.spawn(function()
        self:_setupPlayer(player)
    end)
end

function MopWhackService:PlayerRemoving(player: Player)
    cooldowns[player] = nil
end

function MopWhackService:KnitStart()
    -- Hand the mop over immediately on purchase instead of making the player rejoin.
    MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
        if not wasPurchased or passId ~= GAMEPASS_ID then
            return
        end

        GamepassUtil:GrantPassToCache(player, passId)
        task.spawn(function()
            self:_setupPlayer(player)
        end)
    end)
end

return MopWhackService

--[[
    Module: PolicyService
    Description: Wraps Roblox's PolicyService so the rest of the game can ask simple
    questions about what a player is allowed to be shown.

    This matters for compliance, not just polish: `ArePaidRandomItemsRestricted` must be
    respected before offering capsules (paid random items) for sale. Players in
    restricted regions or age groups are shown the direct-purchase shop instead.

    Roblox's PolicyService is server-only and rate limited, so results are fetched once
    per player and cached for the session.

    Fails CLOSED: if the lookup fails we assume the player IS restricted. Wrongly hiding
    a gacha shop is a cosmetic problem; wrongly showing one is a policy violation.
--]]

---> services
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

---> module declaration
local Service = Knit.CreateService({
    Name = "PolicyService",
})

---> constants
local LOOKUP_RETRIES = 3
local RETRY_DELAY = 2

--- Used when the lookup never succeeds. Deliberately the most restrictive answer.
local RESTRICTED_FALLBACK = {
    ArePaidRandomItemsRestricted = true,
    AllowedExternalLinkReferences = {},
    IsPaidItemTradingAllowed = false,
    IsSubjectToChinaPolicies = false,
}

---> state
local policyCache: { [number]: { [string]: any } } = {}

---> private

local function fetchPolicy(player: Player): { [string]: any }
    for attempt = 1, LOOKUP_RETRIES do
        local ok, info = pcall(function()
            return PolicyService:GetPolicyInfoForPlayerAsync(player)
        end)

        if ok and typeof(info) == "table" then
            return info
        end

        if attempt < LOOKUP_RETRIES then
            task.wait(RETRY_DELAY)
        end
    end

    warn(string.format(
        "[PolicyService] Could not read policy for %s — assuming restricted.",
        player.Name
    ))

    return table.clone(RESTRICTED_FALLBACK)
end

---> public

--- Full policy table for a player, cached per session.
function Service:GetPolicy(player: Player): { [string]: any }
    local cached = policyCache[player.UserId]
    if cached then
        return cached
    end

    local info = fetchPolicy(player)

    -- Only cache while the player is still here, so a lookup that resolves after they
    -- leave does not linger.
    if player.Parent == Players then
        policyCache[player.UserId] = info
    end

    return info
end

--- Whether capsules and other paid random items must be hidden from this player.
function Service:ArePaidRandomItemsRestricted(player: Player): boolean
    return self:GetPolicy(player).ArePaidRandomItemsRestricted == true
end

---> client

--- The subset the UI needs. Kept narrow rather than replicating the whole policy table.
function Service.Client:GetPolicy(player: Player)
    return {
        ArePaidRandomItemsRestricted = self.Server:ArePaidRandomItemsRestricted(player),
    }
end

---> lifecycle

function Service:PlayerAdded(player: Player)
    -- Warm the cache so the first client request does not pay the lookup cost.
    task.spawn(function()
        self:GetPolicy(player)
    end)
end

function Service:PlayerRemoving(player: Player)
    policyCache[player.UserId] = nil
end

return Service

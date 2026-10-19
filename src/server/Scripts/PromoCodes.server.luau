---> services
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

---> networking
-- The Networking folder is not guaranteed to exist in the place, so find or create it (and the remote) in code.
local function getOrCreateRemoteFunction(name: string): RemoteFunction
	local networking = ReplicatedStorage:FindFirstChild("Networking")
	if not networking then
		networking = Instance.new("Folder")
		networking.Name = "Networking"
		networking.Parent = ReplicatedStorage
	end

	local remote = networking:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = networking
	elseif not remote:IsA("RemoteFunction") then
		warn(`[PromoCodes] Networking.{name} is a {remote.ClassName}, expected a RemoteFunction`)
	end
	return remote :: RemoteFunction
end

local RedeemCode = getOrCreateRemoteFunction("RedeemCode")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared   = ReplicatedStorage:WaitForChild("Shared")
local Knit     = require(Packages.Knit)

---> server-only config (never replicated to clients)
local PromoCodesConfig = require(script.Parent.Parent.Configuration.PromoCodes)

---> DataStore for global per-code claim counts
local ClaimCountStore = DataStoreService:GetDataStore("PromoCodeClaimCounts_0001")

---> rate-limit: player → os.clock() of last attempt
local REDEEM_COOLDOWN_SECONDS = 5
local lastAttempt: { [number]: number } = {}

Players.PlayerRemoving:Connect(function(player)
    lastAttempt[player.UserId] = nil
end)

--- Builds a human-readable reward summary, e.g. "100 Boba Bucks + 50 Points".
local function buildRewardSummary(rewards: { any }): string
    local parts = {}
    for _, reward in ipairs(rewards) do
        if reward.Type == "Currency" then
            local label = if reward.Currency == "BobaBucks" then "Boba Bucks" else reward.Currency
            table.insert(parts, reward.Amount .. " " .. label)
        elseif reward.Type == "InventoryItem" then
            table.insert(parts, reward.ItemName)
        end
    end
    return table.concat(parts, " + ")
end

--- Atomically increments the claim count for `code`, returning false if the
--- code has already reached `maxClaims`.  Returns true if the slot was reserved.
local function tryReserveClaimSlot(code: string, maxClaims: number): (boolean, string?)
    local reserved = false
    local ok, err = pcall(function()
        ClaimCountStore:UpdateAsync(code, function(count: number?)
            count = count or 0
            if count >= maxClaims then
                return nil -- cancel: no write
            end
            reserved = true
            return count + 1
        end)
    end)
    if not ok then
        return false, "A server error occurred. Please try again later."
    end
    return reserved, nil
end

--- Applies all rewards in a code definition to the given player.
local function applyRewards(player: Player, rewards: { any })
    local CurrencyService = Knit.GetService("CurrencyService")
    local Inventory       = require(Shared.Inventory)

    for _, reward in ipairs(rewards) do
        if reward.Type == "Currency" then
            CurrencyService:Modify(player, reward.Currency, reward.Amount, "PromoCode")
        elseif reward.Type == "InventoryItem" then
            Inventory:GetPlayerInventoryAsync(player, reward.ItemType)
                :andThen(function(inv)
                    inv:Insert({ Name = reward.ItemName })
                end)
                :catch(function(e)
                    warn("[PromoCodes] Failed to grant", reward.ItemName, "to", player.Name, e)
                end)
        end
    end
end

---> Wire up the RemoteFunction once Knit is ready
Knit.OnStart():andThen(function()
    local DialogService = Knit.GetService("DialogService")
    local DataService   = Knit.GetService("DataService")

    RedeemCode.OnServerInvoke = function(player: Player, rawCode: any)
        -- Type guard: only accept strings
        if typeof(rawCode) ~= "string" then
            return { Success = false, Message = "Invalid input." }
        end

        -- Rate limiting
        local userId = player.UserId
        local now = os.clock()
        if lastAttempt[userId] and (now - lastAttempt[userId]) < REDEEM_COOLDOWN_SECONDS then
            return { Success = false, Message = "Please wait a moment before trying again." }
        end
        lastAttempt[userId] = now

        -- Normalise: uppercase and strip all whitespace
        local code = rawCode:upper():gsub("%s+", "")
        if #code == 0 then
            return { Success = false, Message = "Please enter a code." }
        end

        -- Look up code in server-only config
        local config = PromoCodesConfig[code]
        if not config then
            return { Success = false, Message = "That code doesn't exist." }
        end

        -- Check expiry
        if config.ExpiresAt and os.time() > config.ExpiresAt then
            return { Success = false, Message = "That code has expired." }
        end

        -- Load player data
        local _, playerData = DataService:GetDataAsync(player):await()
        if not playerData then
            return { Success = false, Message = "Could not load your data. Try again." }
        end

        -- Check if the player has already redeemed this code
        local redeemed = playerData.RedeemedCodes or {}
        if redeemed[code] then
            return { Success = false, Message = "You have already redeemed this code." }
        end

        -- Check and atomically reserve a global claim slot (if MaxClaims is set)
        if config.MaxClaims then
            local reserved, reserveErr = tryReserveClaimSlot(code, config.MaxClaims)
            if reserveErr then
                return { Success = false, Message = reserveErr }
            end
            if not reserved then
                return { Success = false, Message = "This code has reached its maximum number of redemptions." }
            end
        end

        -- Mark the code as redeemed in the player's profile
        redeemed[code] = true
        playerData:SetValue({ "RedeemedCodes" }, redeemed)

        -- Apply all rewards
        applyRewards(player, config.Rewards)

        local summary = buildRewardSummary(config.Rewards)
        local message = "Code redeemed! You received: " .. summary .. "."

        -- Also push a server-side notification in case the UI is closed
        DialogService:Notify(player, { Title = "Code Redeemed", Description = message })

        return { Success = true, Message = message }
    end
end):catch(warn)

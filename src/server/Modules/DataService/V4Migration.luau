--[[
    Module: V4Migration
    Description: One-time import of a player's V4 profile into their V3 profile.

    Reads the V4 DataStore key directly with GetAsync rather than going through
    ProfileService. That is deliberate and important:

      * ProfileService:LoadProfileAsync would take a SESSION LOCK on the V4 profile. If
        the player is currently online in V4 that either steals or corrupts their live
        session, and the lock would then need releasing.
      * GetAsync is read-only and lock-free, so a player can be in both games at once
        without harm.

    Nothing is ever written back to the V4 store.

    Safety properties:
      * Idempotent — guarded by profile.MigratedFromV4, which is only set after a
        successful read. A failed read leaves the flag false so the next join retries.
      * Additive — currency is added and inventory is unioned, so progress already made
        in V3 is never overwritten or lost.
      * Conservative — items with no counterpart in InventoryItemDefinitions are skipped
        and logged rather than invented.
--]]

---> services
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Configuration")

local MigrationConfig = require(Config.MigrationConfig)
local InventoryItemDefinitions = require(Config.InventoryItemDefinitions)
local InventoryLimits = require(Config.InventoryLimits)

---> module declaration
local V4Migration = {}

---> private

local sourceStore: DataStore? = nil

local function getSourceStore(): DataStore?
    if sourceStore then
        return sourceStore
    end

    local ok, store = pcall(function()
        return DataStoreService:GetDataStore(MigrationConfig.SOURCE_DATASTORE_NAME)
    end)

    if not ok then
        warn("[V4Migration] Could not open source DataStore:", store)
        return nil
    end

    sourceStore = store
    return sourceStore
end

--- Reads the raw ProfileService record. Returns (ok, profileData).
--- `ok` false means the read failed and the migration must be retried later; `ok` true
--- with a nil payload means the player simply has no V4 profile.
local function readSourceProfile(userId: number): (boolean, { [string]: any }?)
    local store = getSourceStore()
    if not store then
        return false, nil
    end

    local key = string.format(MigrationConfig.SOURCE_KEY_FORMAT, userId)

    for attempt = 1, MigrationConfig.READ_RETRIES do
        local ok, result = pcall(function()
            return store:GetAsync(key)
        end)

        if ok then
            if result == nil then
                return true, nil
            end

            -- ProfileService's saved record is
            -- { Data, MetaData, RobloxMetaData, UserIds, GlobalUpdates }.
            -- Only Data holds gameplay values.
            if typeof(result) ~= "table" or typeof(result.Data) ~= "table" then
                warn(string.format("[V4Migration] Unexpected record shape for %s — skipping.", key))
                return true, nil
            end

            return true, result.Data
        end

        warn(string.format("[V4Migration] Read attempt %d/%d failed for %s: %s", attempt, MigrationConfig.READ_RETRIES, key, tostring(result)))

        if attempt < MigrationConfig.READ_RETRIES then
            task.wait(MigrationConfig.RETRY_DELAY)
        end
    end

    return false, nil
end

local function toNumber(value: any): number
    return if typeof(value) == "number" and value == value then value else 0
end

--- Resolves a V4 item name onto a definition in this codebase, via exact match first
--- then the alias table. Returns nil when there is no counterpart.
local function resolveItemName(sourceName: string, destinationType: string, aliasTableName: string?): string?
    local definitions = InventoryItemDefinitions[destinationType]
    if not definitions then
        return nil
    end

    if definitions[sourceName] then
        return sourceName
    end

    local aliases = aliasTableName and MigrationConfig[aliasTableName]
    local aliased = aliases and aliases[sourceName]

    if aliased and definitions[aliased] then
        return aliased
    end

    return nil
end

local function migrateCurrency(source: { [string]: any }, proxy)
    if not MigrationConfig.MIGRATE_CURRENCY then
        return
    end

    -- V4 spells it with a space; V3 uses BobaBucks.
    local bobaBucks = toNumber(source["Boba Bucks"])
    local points = toNumber(source["Points"])

    if bobaBucks > 0 then
        proxy:SetValue({ "Currency", "BobaBucks" }, toNumber(proxy.Currency.BobaBucks) + bobaBucks)
    end

    if points > 0 then
        proxy:SetValue({ "Currency", "Points" }, toNumber(proxy.Currency.Points) + points)
    end
end

local function migratePlaytime(source: { [string]: any }, proxy)
    local sourceFirstJoin = toNumber(source["FirstJoin"])
    if sourceFirstJoin <= 0 then
        return
    end

    -- Keep the earlier of the two so veterans keep their original join date.
    local currentFirstJoin = toNumber(proxy.Playtime.FirstJoin)
    if currentFirstJoin == 0 or sourceFirstJoin < currentFirstJoin then
        proxy:SetValue({ "Playtime", "FirstJoin" }, sourceFirstJoin)
    end
end

local function migrateRedeemedCodes(source: { [string]: any }, proxy)
    if not MigrationConfig.MIGRATE_REDEEMED_CODES then
        return
    end

    local sourceCodes = source["TwitterCodes"]
    if typeof(sourceCodes) ~= "table" then
        return
    end

    local redeemed = proxy.RedeemedCodes or {}
    local changed = false

    -- V4 wrote this as either an array of codes or a map; handle both.
    for key, value in sourceCodes do
        local code = if typeof(value) == "string" then value else key

        if typeof(code) == "string" and code ~= "" then
            local normalised = code:lower()
            if not redeemed[normalised] then
                redeemed[normalised] = true
                changed = true
            end
        end
    end

    if changed then
        proxy:SetValue({ "RedeemedCodes" }, redeemed)
    end
end

local function migrateInventory(source: { [string]: any }, proxy, player: Player)
    if not MigrationConfig.MIGRATE_INVENTORY then
        return
    end

    local sourceInventory = source["Inventory"]
    if typeof(sourceInventory) ~= "table" then
        return
    end

    for _, mapping in MigrationConfig.MIGRATABLE_ITEM_TYPES do
        local sourceItems = sourceInventory[mapping.Source]
        if typeof(sourceItems) ~= "table" then
            continue
        end

        local destinationRoot = proxy.Inventory.Items[mapping.Destination]
        if typeof(destinationRoot) ~= "table" then
            continue
        end

        -- Union by name: a player who already owns the item in V3 does not get a second.
        local ownedNames = {}
        local usedSlots = 0
        for _, item in destinationRoot do
            usedSlots += 1
            if typeof(item) == "table" and item.Name then
                ownedNames[item.Name] = true
            end
        end

        local limit = InventoryLimits.Storage[mapping.Destination] or math.huge
        local definitions = InventoryItemDefinitions[mapping.Destination]
        local skipped, granted, overflow = {}, 0, 0

        for _, sourceItem in sourceItems do
            local sourceName = if typeof(sourceItem) == "table" then sourceItem.Name else sourceItem
            if typeof(sourceName) ~= "string" then
                continue
            end

            local resolved = resolveItemName(sourceName, mapping.Destination, mapping.Aliases)
            if not resolved then
                table.insert(skipped, sourceName)
                continue
            end

            if ownedNames[resolved] then
                continue
            end

            -- Writing straight to the profile bypasses InventoryServer:Insert, so the
            -- per-type storage cap has to be enforced here or the inventory UI breaks.
            if usedSlots >= limit then
                overflow += 1
                continue
            end

            local itemId = string.format("%s-%s", resolved:lower(), HttpService:GenerateGUID(false))
            proxy:SetValue({ "Inventory", "Items", mapping.Destination, itemId }, {
                Name = resolved,
                Tier = definitions[resolved].Tier,
                Equipped = false,
                Properties = {},
            })

            ownedNames[resolved] = true
            usedSlots += 1
            granted += 1
        end

        if granted > 0 then
            print(string.format("[V4Migration] %s: granted %d %s.", player.Name, granted, mapping.Destination))
        end

        if overflow > 0 then
            warn(string.format(
                "[V4Migration] %s: %d %s dropped — storage limit of %d reached.",
                player.Name, overflow, mapping.Destination, limit
            ))
        end

        if #skipped > 0 then
            warn(string.format(
                "[V4Migration] %s: no V3 equivalent for %s: %s",
                player.Name, mapping.Destination, table.concat(skipped, ", ")
            ))
        end
    end
end

---> public

--- Imports `player`'s V4 profile if it has not been imported already. Safe to call on
--- every join; returns true when a migration actually ran.
function V4Migration.Migrate(player: Player, proxy): boolean
    if not MigrationConfig.ENABLED then
        return false
    end

    if proxy.MigratedFromV4 then
        return false
    end

    local ok, sourceData = readSourceProfile(player.UserId)

    if not ok then
        -- Leave the flag unset so the next join retries rather than silently losing data.
        warn(string.format("[V4Migration] Giving up on %s for this session; will retry next join.", player.Name))
        return false
    end

    if not sourceData then
        -- No V4 profile. Mark done so we never look again for this player.
        proxy:SetValue({ "MigratedFromV4" }, true)
        return false
    end

    local migrated, err = pcall(function()
        migrateCurrency(sourceData, proxy)
        migratePlaytime(sourceData, proxy)
        migrateRedeemedCodes(sourceData, proxy)
        migrateInventory(sourceData, proxy, player)
    end)

    if not migrated then
        warn(string.format("[V4Migration] Migration failed for %s:", player.Name), err)
        return false
    end

    proxy:SetValue({ "MigratedFromV4" }, true)
    print(string.format("[V4Migration] Migrated V4 data for %s (%d).", player.Name, player.UserId))

    return true
end

return V4Migration

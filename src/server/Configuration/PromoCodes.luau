--[[
    PromoCodes — server-only configuration.

    Each entry maps a NORMALISED code string (uppercase, no whitespace) to its
    definition.  The system checks this table server-side so exploiters can
    never enumerate valid codes from the client.

    Reward types
    ────────────
    { Type = "Currency",      Currency = "BobaBucks"|"Points", Amount = number }
    { Type = "InventoryItem", ItemType = string,                ItemName = string }

    Optional per-code settings
    ──────────────────────────
    MaxClaims  — maximum total redemptions across ALL players (omit for unlimited)
    ExpiresAt  — os.time() UTC timestamp after which the code is invalid (omit for no expiry)
]]

export type CurrencyReward = {
    Type: "Currency",
    Currency: "BobaBucks" | "Points",
    Amount: number,
}

export type InventoryReward = {
    Type: "InventoryItem",
    ItemType: string,
    ItemName: string,
}

export type Reward = CurrencyReward | InventoryReward

export type CodeConfig = {
    Rewards: { Reward },
    MaxClaims: number?,
    ExpiresAt: number?,
}

local codes: { [string]: CodeConfig } = {
    ["BOBATIME"] = {
        Rewards = {
            { Type = "Currency", Currency = "BobaBucks", Amount = 100 },
        },
        MaxClaims = 500,
    },

    ["GRANDOPENING"] = {
        Rewards = {
            { Type = "Currency", Currency = "BobaBucks", Amount = 250 },
            { Type = "Currency", Currency = "Points",    Amount = 100 },
        },
        MaxClaims = 1000,
    },

    -- Seasonal example — set ExpiresAt to a real Unix timestamp before use.
    -- ["AUTUMN2025"] = {
    --     Rewards = {
    --         { Type = "Currency", Currency = "BobaBucks", Amount = 75 },
    --     },
    --     ExpiresAt = 1761782400, -- 2025-10-31 00:00 UTC
    -- },
}

return codes

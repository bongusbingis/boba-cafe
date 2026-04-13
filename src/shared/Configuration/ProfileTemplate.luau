type InventoryItem = {
    Name: string,
    Tier: string?,
    Equipped: boolean?,
    StackCount: number?,
    Properties: {
        [string]: any,
    }?,
}

type InventoryItemStruct = {
    [string]: InventoryItem,
}

-- Represents a pet capsule that has been activated and is currently incubating.
-- The reward is NOT pre-selected; it is rolled when the hatch completes so
-- that item pool changes during the wait period are respected.
-- TimeAccumulated only counts seconds spent actively playing (offline time
-- does not progress the hatch).
type PendingHatch = {
    CapsuleName: string,   -- definition name of the capsule that was used
    TimeAccumulated: number, -- active-play seconds accumulated so far
}

type Statistics = {
    TimePlayed: number,        -- accumulated seconds from ended sessions (current session added client-side)
    ItemsOrdered: number,
    BobasOrdered: number,
    BobaBucksEarned: number,
    BobaBucksSpent: number,
    CelebritiesMet: number,
    OrdersCreated: number,
    OrdersPrepared: number,
    SpillsCleaned: number,
    TreasureChestsFound: number,
}

export type PlayerSettings = {
    HeadlessHead: boolean,
    FasterWalkSpeed: boolean,
    MusicEnabled: boolean,
    SFXEnabled: boolean,
    SyrupHighlighting: boolean,
    ShiftTimerEnabled: boolean,
}

export type ProfileTemplate = {
    Currency: {
        Points: number,
        BobaBucks: number,
    },
    Playtime: {
        FirstJoin: number,
        MostRecentJoin: number,
    },
    Inventory: {
        Items: {
            Nametags: InventoryItemStruct,
            Pets: InventoryItemStruct,
            Particles: InventoryItemStruct,
            Capsules: InventoryItemStruct,
        },
        FreeItemsRedeemed: { string },
    },
    Statistics: Statistics,
    HatchingPet: PendingHatch | false,
    Nickname: string,
    -- Codes the player has already redeemed; keyed by normalised code string for O(1) lookups.
    RedeemedCodes: { [string]: boolean },
    Settings: PlayerSettings,
}

return {
    Currency = {
        Points = 0,
        BobaBucks = 0,
    },
    Playtime = {
        FirstJoin = 0,
        MostRecentJoin = 0,
    },
    Inventory = {
        Items = {
            Pets = {},
            Nametags = {},
            Capsules = {},
            Particles = {},
        },
        FreeItemsRedeemed = {},
    },
    Statistics = {
        TimePlayed = 0,
        ItemsOrdered = 0,
        BobasOrdered = 0,
        BobaBucksEarned = 0,
        BobaBucksSpent = 0,
        CelebritiesMet = 0,
        OrdersCreated = 0,
        OrdersPrepared = 0,
        SpillsCleaned = 0,
        TreasureChestsFound = 0,
    },
    HatchingPet = false,
    Nickname = "",
    RedeemedCodes = {},
    Settings = {
        HeadlessHead = false,
        FasterWalkSpeed = false,
        MusicEnabled = true,
        SFXEnabled = true,
        SyrupHighlighting = true,
        ShiftTimerEnabled = false,
    },
}

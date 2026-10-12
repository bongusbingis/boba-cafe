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

-- One assigned daily quest. Progress is tracked separately, keyed by the quest's
-- tracker verb, so several quests watching the same verb stay in sync.
type ActiveQuest = {
    Id: string,
    Tier: string,
    Completed: boolean,
}

-- Daily quests. Expires is a UTC-midnight timestamp; once passed, the set is rerolled.
-- Progress maps a tracker verb to either a running total (number) or a set of unique
-- ids (e.g. which friends were seen), matching how each quest counts.
type Quests = {
    Expires: number,
    Current: { ActiveQuest },
    Progress: { [string]: number | { [string]: boolean } },
}

-- Daily login streak. CurrentDay is the index into the reward cycle that was last
-- claimed (0 = nothing claimed yet); TotalDays is a lifetime count that never resets.
-- Onboarding and role progression. There are two roles: Customer and Worker. Barista is
-- a promotion within Worker rather than a third role, so it is a flag and not a value of
-- ActiveRole. Group rank bypasses all of this (see OnboardingUtil).
export type PlayerRole = "Customer" | "Worker"

type Onboarding = {
    -- Set once the worker onboarding has been completed; it never runs twice.
    WorkerOnboarded: boolean,
    -- Set once the Barista promotion has been trained, unlocking drink-making.
    BaristaUnlocked: boolean,
    -- Role chosen for the current session. Persisted only so the role screen can
    -- preselect the last choice; it is re-chosen every join.
    ActiveRole: PlayerRole,
}

type DailyRewards = {
    CurrentDay: number,
    TotalDays: number,
    LastClaimed: number,
}

-- Timed subscriptions, keyed by subscription name. Expire is an os.time() deadline;
-- 0 means never held. See SubscriptionsConfig for the definitions.
type Subscriptions = {
    [string]: { Expire: number },
}

export type PlayerSettings = {
    HeadlessHead: boolean,
    FasterWalkSpeed: boolean,
    MusicEnabled: boolean,
    SFXEnabled: boolean,
    SyrupHighlighting: boolean,
    ShiftTimerEnabled: boolean,
    -- Opt-out for being knocked over by other players (Mop Whack).
    Ragdollable: boolean,
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
    DailyRewards: DailyRewards,
    Quests: Quests,
    Subscriptions: Subscriptions,
    HatchingPet: PendingHatch | false,
    Nickname: string,
    -- Custom nametag tint from the Nametag Customizer pass. Stored as 0-255 channels
    -- because Color3 is not a DataStore-serialisable type. false = use the nametag's
    -- own colour.
    NametagColor: { R: number, G: number, B: number } | false,
    -- Codes the player has already redeemed; keyed by normalised code string for O(1) lookups.
    RedeemedCodes: { [string]: boolean },
    Settings: PlayerSettings,
    -- Set once the V4 datastore has been read for this player. Guards the migration
    -- against running twice; see Modules/DataService/V4Migration.
    MigratedFromV4: boolean,
    Onboarding: Onboarding,
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
    DailyRewards = {
        CurrentDay = 0,
        TotalDays = 0,
        LastClaimed = 0,
    },
    Quests = {
        Expires = 0,
        Current = {},
        Progress = {},
    },
    Subscriptions = {},
    HatchingPet = false,
    Nickname = "",
    NametagColor = false,
    RedeemedCodes = {},
    MigratedFromV4 = false,
    Onboarding = {
        WorkerOnboarded = false,
        BaristaUnlocked = false,
        ActiveRole = "Customer",
    },
    Settings = {
        HeadlessHead = false,
        FasterWalkSpeed = false,
        MusicEnabled = true,
        SFXEnabled = true,
        SyrupHighlighting = true,
        ShiftTimerEnabled = false,
        Ragdollable = true,
    },
}

type InventoryItem = {
    Name: string,
    Tier: string?,
    Equipped: boolean?,
    StackCount: number?,
    Properties: {
        [string]: any,
    }?,
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
            Nametags: {
                [string]: InventoryItem,
            },
            Pets: {
                [string]: InventoryItem,
            },
            Particles: {
                [string]: InventoryItem,
            },
            Capsules: {
                [string]: InventoryItem,
            },
        },
    },
    HatchingPet: PendingHatch | false,
    Nickname: string,
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
    },
    HatchingPet = false,
    Nickname = "",
}

type InventoryItem = {
    Name: string,
    Rarity: string?,
    Equipped: boolean?,
    StackCount: number?,
    Properties: {
        [string]: any,
    }?,
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
}
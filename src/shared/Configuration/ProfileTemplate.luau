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
                [string]: {
                    Name: string,
                    Rarity: string?,
                    Equipped: boolean?,
                    StackCount: number?,
                    Properties: {
                        [string]: any,
                    }?,
                },
            },
            Pets: {
                [string]: {
                    Name: string,
                    Rarity: string?,
                    Equipped: boolean?,
                    StackCount: number?,
                    Properties: {
                        [string]: any,
                    }?,
                },
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
            Nametags = {},
            Pets = {},
        },
    },
}
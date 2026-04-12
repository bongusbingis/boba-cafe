-- Maps game pass IDs to the Roblox group rank they grant when claimed.
-- Only passes that directly confer a group rank need entries here.
-- RankId corresponds to the numeric rank value in group 3174578.

export type GamepassRankEntry = {
    RankId: number,
}

local GamepassConfig: { [number]: GamepassRankEntry } = {
    [6202153]  = { RankId = 8  }, -- Barista
    [15243046] = { RankId = 10 }, -- Kitchen Leader
}

return GamepassConfig

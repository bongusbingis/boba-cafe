--[[
    Module: DailyRewardsConfig
    Description: The daily login reward cycle.

    Grants are declared as data rather than callbacks so this config stays safe to
    replicate to the client (which needs the labels and icons to draw the Rewards page),
    exactly like Shared.Kitchen.Recipes. DailyRewardsService is what actually pays out.

    Grant types:
      { Type = "Currency", Currency = "BobaBucks" | "Points", Amount = n }
      { Type = "Item", ItemType = <InventoryItemDefinitions key>, ItemName = <definition name> }
--]]

local DailyRewardsConfig = {}

--- Seconds that must pass before the next day can be claimed.
DailyRewardsConfig.CLAIM_INTERVAL = 86400

--- Miss this long and the streak resets to day 1. Two claim intervals, so a player has
--- a full day of grace after becoming eligible.
DailyRewardsConfig.STREAK_GRACE = DailyRewardsConfig.CLAIM_INTERVAL * 2

--- The cycle. Claiming the last entry wraps back to the first.
DailyRewardsConfig.CYCLE = {
	{
		Label = "Boba Bucks",
		Description = "50",
		Icon = "rbxassetid://15267526410",
		Grant = { Type = "Currency", Currency = "BobaBucks", Amount = 50 },
	},
	{
		Label = "Boba Bucks",
		Description = "100",
		Icon = "rbxassetid://15267526410",
		Grant = { Type = "Currency", Currency = "BobaBucks", Amount = 100 },
	},
	{
		Label = "Boba Bucks",
		Description = "150",
		Icon = "rbxassetid://15267526410",
		Grant = { Type = "Currency", Currency = "BobaBucks", Amount = 150 },
	},
	{
		Label = "Boba Bucks",
		Description = "180",
		Icon = "rbxassetid://15267526410",
		Grant = { Type = "Currency", Currency = "BobaBucks", Amount = 180 },
	},
	{
		Label = "Boba Bucks",
		Description = "200",
		Icon = "rbxassetid://15267544938",
		Grant = { Type = "Currency", Currency = "BobaBucks", Amount = 200 },
	},
	{
		Label = "Boba Bucks",
		Description = "230",
		Icon = "rbxassetid://15267557982",
		Grant = { Type = "Currency", Currency = "BobaBucks", Amount = 230 },
	},
	{
		-- V4 finished the week with a "Falling Leaves" particle, which has no definition
		-- in this codebase. Sakura is the closest existing particle; swap it if you add
		-- Falling Leaves to InventoryItemDefinitions.Particles.
		Label = "Sakura",
		Description = "Particle",
		Icon = "rbxassetid://96395142011281",
		Grant = { Type = "Item", ItemType = "Particles", ItemName = "Sakura" },
	},
}

return DailyRewardsConfig

--!strict
--[[
	CafeUpgradeConfig.luau
	BIG-B2 Cafe Upgrades: server-wide cosmetic cafe improvements bought with BobaBucks.

	Design (DEC-058 Opus-set, Jack to tune):
	- Per-server, not saved. A fresh server starts with a bare cafe, so every server is a
	  new BobaBucks sink and a new chance to put your name on the plaque.
	- Everything is cosmetic and nonfunctional: decor only, no gameplay effects.
	- Positions are rough. Every entry in PLACEMENT is relative to ORIGIN (y = 0 is the
	  floor), so moving ORIGIN moves the whole set; nudge single pieces in PLACEMENT.
]]

export type Level = {
	Price: number,
}

export type Upgrade = {
	Id: string,
	Name: string,
	Description: string,
	Levels: { Level },
}

export type Contribution = {
	Name: string,
	UpgradeName: string,
	Level: number,
}

export type LightStrand = {
	From: Vector3,
	To: Vector3,
}

local CafeUpgradeConfig = {}

CafeUpgradeConfig.BUILT_BY = "Opus-B2"
CafeUpgradeConfig.FOLDER_NAME = "CafeUpgrades"
CafeUpgradeConfig.PROMPT_MAX_DISTANCE = 10
CafeUpgradeConfig.PLAQUE_MAX_LINES = 8
CafeUpgradeConfig.CURRENCY_LABEL = "Boba Bucks"

-- Plants shown per Plants level (level 3 shows all six pots).
CafeUpgradeConfig.PLANTS_PER_LEVEL = 2

-- Upgrades in menu order. Full set in one server: 1,700 BB. DEC-058 Opus-set, Jack to tune.
CafeUpgradeConfig.UPGRADES = {
	{
		Id = "Plants",
		Name = "Potted Plants",
		Description = "Leafy plants around the cafe.",
		Levels = { { Price = 150 }, { Price = 300 }, { Price = 500 } }, -- DEC-058 Opus-set, Jack to tune
	},
	{
		Id = "Lights",
		Name = "Fairy Lights",
		Description = "Warm string lights over the floor.",
		Levels = { { Price = 250 }, { Price = 500 } }, -- DEC-058 Opus-set, Jack to tune
	},
} :: { Upgrade }

-- Rough world placement (Jack adjusts in Studio). ORIGIN sits on the floor near the
-- customer side of the counter (the NPC test spawn was (4.6, -6.8, 323.9)).
CafeUpgradeConfig.ORIGIN = CFrame.new(4.6, -9.8, 323.9)
CafeUpgradeConfig.PLACEMENT = {
	Board = CFrame.new(-10, 0, 6) * CFrame.Angles(0, math.rad(90), 0),
	Plants = {
		CFrame.new(-14, 0, -2),
		CFrame.new(14, 0, -2),
		CFrame.new(-14, 0, 10),
		CFrame.new(14, 0, 10),
		CFrame.new(-8, 0, 16),
		CFrame.new(8, 0, 16),
	} :: { CFrame },
	Lights = {
		{ From = Vector3.new(-14, 11, -2), To = Vector3.new(14, 11, -2) },
		{ From = Vector3.new(-14, 11, 12), To = Vector3.new(14, 11, 12) },
	} :: { LightStrand },
}

---> helpers

function CafeUpgradeConfig.GetUpgrade(id: any): Upgrade?
	if typeof(id) ~= "string" then
		return nil
	end
	for _, upgrade in CafeUpgradeConfig.UPGRADES do
		if upgrade.Id == id then
			return upgrade
		end
	end
	return nil
end

--- The next level to buy and its price, or nil when the upgrade is maxed or unknown.
function CafeUpgradeConfig.GetNextLevel(id: any, currentLevel: number): (number?, number?)
	local upgrade = CafeUpgradeConfig.GetUpgrade(id)
	if not upgrade then
		return nil, nil
	end
	local nextLevel = currentLevel + 1
	local level = upgrade.Levels[nextLevel]
	if not level then
		return nil, nil
	end
	return nextLevel, level.Price
end

--- Menu button label; unique per upgrade so the dialog answer maps back to one id.
function CafeUpgradeConfig.ButtonLabel(upgrade: Upgrade, currentLevel: number): string
	local nextLevel, price = CafeUpgradeConfig.GetNextLevel(upgrade.Id, currentLevel)
	if not nextLevel then
		return `{upgrade.Name}: Maxed`
	end
	return `{upgrade.Name} Lv {nextLevel}: {price} BB`
end

--- Plaque lines, newest first, capped at `maxLines`.
function CafeUpgradeConfig.PlaqueLines(contributions: { Contribution }, maxLines: number): { string }
	local lines = {}
	for i = #contributions, 1, -1 do
		if #lines >= maxLines then
			break
		end
		local entry = contributions[i]
		table.insert(lines, `{entry.Name} · {entry.UpgradeName} Lv {entry.Level}`)
	end
	return lines
end

return CafeUpgradeConfig

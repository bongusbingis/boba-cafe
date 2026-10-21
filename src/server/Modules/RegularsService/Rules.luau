--!strict
--[[
	RegularsService/Rules
	Pure BIG-B5 rules (no Instances, no services): when a regular spawns, which
	one, their order, their greeting, and how a serve stamps the book. Rolls are
	passed in so the specs can fix them.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CustomerConfig = require(Shared.Configuration.CustomerConfig)
local RegularsConfig = require(Shared.Configuration.RegularsConfig)

export type Regular = RegularsConfig.Regular
export type OrderItem = CustomerConfig.OrderItem
export type Config = typeof(RegularsConfig)
export type StampResult = {
	Visits: number, -- serves of this regular after the stamp
	First: boolean, -- the first time this player served them
	Stamped: number, -- regulars stamped after the stamp
	Completed: boolean, -- this stamp completed the book and the reward is still unclaimed
}

local Rules = {}

-- The roster entry for `id`, or nil.
function Rules.Get(id: string, config: Config?): Regular?
	local c = config or RegularsConfig
	for _, regular in c.ROSTER do
		if regular.Id == id then
			return regular
		end
	end
	return nil
end

-- True when a new customer should be a regular: never for a VIP/Karen, never within
-- MIN_GAP_SECONDS of the last regular, else with SPAWN_CHANCE.
function Rules.ShouldSpawn(roll: number, now: number, lastSpawn: number?, hasVariant: boolean, config: Config?): boolean
	local c = config or RegularsConfig
	if hasVariant then
		return false
	end
	if lastSpawn ~= nil and now - lastSpawn < c.MIN_GAP_SECONDS then
		return false
	end
	return roll < c.SPAWN_CHANCE
end

-- Picks a regular who is not in the cafe already. With `biasRoll` < UNMET_BIAS the pick is
-- from `unmet` (ids some clocked-in barista has not stamped) when any of those are free.
-- `roll` in [0, 1) chooses within the candidates. Nil when every regular is present.
function Rules.Pick(
	roll: number,
	biasRoll: number,
	present: { [string]: boolean },
	unmet: { [string]: boolean },
	config: Config?
): Regular?
	local c = config or RegularsConfig
	local free: { Regular } = {}
	local freeUnmet: { Regular } = {}
	for _, regular in c.ROSTER do
		if not present[regular.Id] then
			table.insert(free, regular)
			if unmet[regular.Id] then
				table.insert(freeUnmet, regular)
			end
		end
	end
	local pool = if biasRoll < c.UNMET_BIAS and #freeUnmet > 0 then freeUnmet else free
	if #pool == 0 then
		return nil
	end
	local index = math.clamp(math.floor(roll * #pool) + 1, 1, #pool)
	return pool[index]
end

-- The pool entry for the regular's favourite, or nil when the key is not in ORDER_POOL.
function Rules.FavouriteEntry(regular: Regular): CustomerConfig.PoolEntry?
	for _, entry in CustomerConfig.ORDER_POOL do
		if entry.Key == regular.Favourite then
			return entry
		end
	end
	return nil
end

-- The favourite drink's display label ("Taro Boba"), or the key when it is missing.
function Rules.FavouriteLabel(regular: Regular): string
	local entry = Rules.FavouriteEntry(regular)
	return if entry ~= nil then entry.Label else regular.Favourite
end

-- The regular's favourite as an order item, or nil when the barista's `level` is below the
-- drink's MinLevel (or the favourite is not a pool drink). A new table, safe to keep.
function Rules.FavouriteOrder(regular: Regular, level: number): OrderItem?
	local entry = Rules.FavouriteEntry(regular)
	if entry == nil or (entry.MinLevel or 1) > level then
		return nil
	end
	local customInfo = table.clone(entry.OrderItem.CustomInfo)
	if entry.Sized then
		customInfo.Size = regular.Size or "Medium"
	end
	return {
		Category = entry.OrderItem.Category,
		Item = entry.OrderItem.Item,
		CustomInfo = customInfo,
	}
end

local function fill(line: string, regular: Regular, playerName: string, drink: string): string
	local out = line:gsub("{name}", function()
		return regular.Name
	end)
	out = out:gsub("{player}", function()
		return playerName
	end)
	out = out:gsub("{drink}", function()
		return drink
	end)
	return out
end

-- What the regular says when `playerName` takes their order. `met` = this player has a stamp
-- for them; `hasFavourite` = the favourite is the order (false = a surprise pool order).
function Rules.Greeting(
	regular: Regular,
	playerName: string,
	met: boolean,
	hasFavourite: boolean,
	roll: number,
	config: Config?
): string
	local c = config or RegularsConfig
	local lines: { string }
	if hasFavourite then
		lines = if met then c.MET_GREETINGS else c.FIRST_GREETINGS
	else
		lines = if met then c.SURPRISE_GREETINGS else c.SURPRISE_FIRST_GREETINGS
	end
	local index = math.clamp(math.floor(roll * #lines) + 1, 1, #lines)
	return fill(lines[index], regular, playerName, Rules.FavouriteLabel(regular))
end

-- Regulars stamped in `visits` (only roster ids count).
function Rules.Count(visits: { [string]: number }, config: Config?): number
	local c = config or RegularsConfig
	local count = 0
	for _, regular in c.ROSTER do
		if (visits[regular.Id] or 0) > 0 then
			count += 1
		end
	end
	return count
end

-- One serve of `id`. Does not edit `visits`; the caller writes Visits[id] = result.Visits.
-- Nil for an id outside the roster.
function Rules.Stamp(visits: { [string]: number }, id: string, rewardClaimed: boolean, config: Config?): StampResult?
	local c = config or RegularsConfig
	if Rules.Get(id, c) == nil then
		return nil
	end
	local before = visits[id] or 0
	local after = table.clone(visits)
	after[id] = before + 1
	local stamped = Rules.Count(after, c)
	return {
		Visits = before + 1,
		First = before == 0,
		Stamped = stamped,
		Completed = not rewardClaimed and stamped >= #c.ROSTER,
	}
end

return Rules

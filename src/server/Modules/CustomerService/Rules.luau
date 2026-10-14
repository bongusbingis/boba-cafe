--!strict
--[[
	Rules
	Pure NPC customer rules (REVIVAL-001 M1.4c, the answer-robust part): the pacing
	target, patience length and the order pick. No Instances, no services, so
	CustomerService.spec can test it directly.

	Not here yet: assignment, Rescue and payout (PENDING JACK Q1/Q5/Q6).
--]]

---> services

local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies

local CustomerConfig = require(ReplicatedStorage:WaitForChild("Shared").Configuration.CustomerConfig)

---> types

export type OrderItem = CustomerConfig.OrderItem
export type PatienceState = "Green" | "Yellow" | "Red"

type Config = typeof(CustomerConfig)

---> private

local function defaultRng(): number
	return math.random()
end

-- Index of the entry a roll in [0, 1) lands on, weighted by each entry's Weight.
local function pickIndex(entries: { any }, roll: number): number
	local total = 0
	for _, entry in entries do
		total += entry.Weight
	end

	local remaining = roll * total
	for index, entry in entries do
		remaining -= entry.Weight
		if remaining < 0 then
			return index
		end
	end
	return #entries -- roll of exactly 1, or float rounding
end

---> public

local Rules = {}

-- How many NPCs should be present for this many clocked-in baristas (design 4.2).
-- With nobody clocked in nothing spawns.
function Rules.PacingTarget(baristas: number, config: Config?): number
	local c = config or CustomerConfig
	if baristas <= 0 then
		return 0
	end

	local slots = baristas * c.SLOTS_PER_BARISTA
	local line = c.LINE_BASE + math.floor(baristas / c.LINE_BARISTAS_PER_EXTRA)
	return math.min(c.SERVER_CAP, slots + line)
end

-- Seconds of patience for an order (design 4.5): the base plus one bonus per item.
function Rules.PatienceSeconds(items: { OrderItem }, config: Config?): number
	local c = config or CustomerConfig
	local seconds = c.PATIENCE_BASE_SECONDS
	for _, item in items do
		seconds += c.PATIENCE_BONUS_SECONDS[item.Category] or c.PATIENCE_GRAB_BONUS_SECONDS
	end
	return seconds
end

-- Bar colour state for the fraction of patience left (1 = full, 0 = out).
function Rules.PatienceState(fractionLeft: number, config: Config?): PatienceState
	local c = config or CustomerConfig
	if fractionLeft <= c.PATIENCE_RED_FRACTION then
		return "Red"
	elseif fractionLeft <= c.PATIENCE_YELLOW_FRACTION then
		return "Yellow"
	end
	return "Green"
end

-- Picks one order from the pool. `rng` returns a number in [0, 1) and defaults to
-- math.random, so tests can pass a fixed sequence. Returns a new table that is
-- safe to keep or edit.
function Rules.PickOrder(rng: (() -> number)?, config: Config?): OrderItem
	local c = config or CustomerConfig
	local roll: () -> number = rng or defaultRng

	local entry = c.ORDER_POOL[pickIndex(c.ORDER_POOL, roll())]
	local customInfo = table.clone(entry.OrderItem.CustomInfo)
	if entry.Sized then
		customInfo.Size = c.SIZE_WEIGHTS[pickIndex(c.SIZE_WEIGHTS, roll())].Size
	end

	return {
		Category = entry.OrderItem.Category,
		Item = entry.OrderItem.Item,
		CustomInfo = customInfo,
	}
end

return Rules

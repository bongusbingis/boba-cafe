--!strict
--[[
	Rules
	Pure NPC customer rules (REVIVAL-001 M1.4c, the answer-robust part): the pacing
	target, patience length and the order pick. No Instances, no services, so
	CustomerService.spec can test it directly.

	Assignment, Rescue and payout live below (REVIVAL-001 M1.4e).
--]]

---> services

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

---> dependencies

local CustomerConfig = require(ReplicatedStorage:WaitForChild("Shared").Configuration.CustomerConfig)

---> types

export type OrderItem = CustomerConfig.OrderItem
export type ServeGrade = "Perfect" | "Close"
export type PatienceState = "Green" | "Yellow" | "Red"
export type Variant = "VIP" | "Karen"

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
-- Only entries with MinLevel <= `level` (default 1) can be picked.
function Rules.PickOrder(rng: (() -> number)?, config: Config?, level: number?): OrderItem
	local c = config or CustomerConfig
	local roll: () -> number = rng or defaultRng

	local pool = {}
	for _, candidate in c.ORDER_POOL do
		if (candidate.MinLevel or 1) <= (level or 1) then
			table.insert(pool, candidate)
		end
	end
	if #pool == 0 then
		pool = c.ORDER_POOL -- never leave a customer without an order
	end

	local entry = pool[pickIndex(pool, roll())]
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

-- Items in one NPC order at `level`: the ITEM_COUNT_BY_LEVEL value of the highest key at or below it.
function Rules.ItemCountForLevel(level: number, config: Config?): number
	local c = config or CustomerConfig
	local best, count = 0, 1
	for from, n in c.ITEM_COUNT_BY_LEVEL do
		if from <= level and from > best then
			best, count = from, n
		end
	end
	return count
end

-- Pays one serve (design 3.5): base x grade x speed x combo x rescue, at least
-- MIN_PAY. `items` are order items ({ Category, CustomInfo }); a multi-item
-- order pays the sum. `comboCount` is the consecutive Perfect serves before this
-- one. Scripted serves are always Fast. `rescue` is a non-assignee serve while
-- the patience is below RESCUE_FRACTION.
function Rules.Payout(
	items: { OrderItem },
	grade: ServeGrade,
	fractionLeft: number,
	comboCount: number,
	scripted: boolean,
	rescue: boolean,
	config: Config?
): number
	local c = config or CustomerConfig

	local base = 0
	for _, item in items do
		base += c.PAY_TABLE[item.Category] or 1 -- unknown categories pay the Grab rate
		local info = item.CustomInfo
		if typeof(info) == "table" then
			if info.Iced == true then
				base += 1
			end
			if info.Sugar == true then
				base += 1
			end
		end
	end

	local speed = if scripted or fractionLeft >= c.FAST_FRACTION then c.FAST_MULT else 1
	local combo = 1 + math.min(comboCount * c.COMBO_STEP, c.COMBO_CAP)
	local source = if rescue then c.RESCUE_MULT else 1
	return math.max(c.MIN_PAY, math.round(base * (c.GRADE_MULT[grade] or 1) * speed * combo * source))
end

-- The NPC variant for a roll in [0, 1) (design 4.10): Karen from her MinLevel in the first
-- band, then VIP in the next band, else nil. `level` is the highest clocked-in barista level.
function Rules.PickVariant(level: number, roll: number, config: Config?): Variant?
	local c = config or CustomerConfig
	local karen = c.VARIANTS.Karen
	local vip = c.VARIANTS.VIP
	local karenMinLevel = karen.MinLevel
	local karenChance = karen.Chance

	if Workspace:GetAttribute("KarenRush") == true then
		karenMinLevel = 1
		karenChance = 0.50
	end

	local floor = 0
	if level >= karenMinLevel then
		floor = karenChance
		if roll < floor then
			return "Karen"
		end
	end
	if level >= vip.MinLevel and roll < floor + vip.Chance then
		return "VIP"
	end
	return nil
end

-- Patience seconds after the variant multiplier (one place for it).
function Rules.VariantPatience(seconds: number, variant: Variant?, config: Config?): number
	local c = config or CustomerConfig
	if variant == nil then
		return seconds
	end
	return seconds * c.VARIANTS[variant].PatienceMult
end

-- Applies the variant pay multiplier to an already computed Rules.Payout result.
function Rules.PayoutVariant(basePay: number, variant: Variant?, grade: ServeGrade, config: Config?): number
	local c = config or CustomerConfig
	if variant == nil then
		return basePay
	end
	local v = c.VARIANTS[variant]
	if v.PayMultGrade ~= nil and v.PayMultGrade ~= grade then
		return basePay
	end
	return math.max(c.MIN_PAY, math.round(basePay * v.PayMult))
end

-- The combo after a serve: Perfect adds one step, anything else resets to 0.
-- A Wrong attempt never reaches this (the tool is kept and the combo untouched).
function Rules.NextCombo(comboCount: number, grade: ServeGrade): number
	if grade == "Perfect" then
		return comboCount + 1
	end
	return 0
end

-- The server-wide Team Combo chain after an event (DEC-036 C1): any successful serve adds one,
-- a walkout (`grade` nil) resets to 0. Returns (newChain, triggered); reaching `target` triggers
-- the combo and restarts the chain at 0.
function Rules.NextTeamChain(chain: number, grade: ServeGrade?, target: number): (number, boolean)
	if grade == nil then
		return 0, false
	end
	local nextChain = chain + 1
	if nextChain >= target then
		return 0, true
	end
	return nextChain, false
end

-- Team Combo pay: `pay` x (1 + bonus) rounded while the combo is active, else unchanged.
function Rules.TeamComboPay(pay: number, active: boolean, bonus: number): number
	if not active then
		return pay
	end
	return math.round(pay * (1 + bonus))
end

-- Who may serve: the assigned barista always, anyone else only on a Rescue
-- (patience below RESCUE_FRACTION, design 4.3).
function Rules.CanServe(isAssigned: boolean, fractionLeft: number, config: Config?): boolean
	if isAssigned then
		return true
	end
	local c = config or CustomerConfig
	return fractionLeft < c.RESCUE_FRACTION
end

-- Picks the assignee from the qualifying candidates (clocked in, free slot, no
-- active player order; filtered by the caller): whoever has been idle longest
-- (design 4.3). Missing idle entries count as idle since the epoch, so an
-- untracked barista is picked first. Returns nil when nobody qualifies.
function Rules.PickAssignee(candidates: { Player }, idleSince: { [Player]: number }?): Player?
	local best: Player? = nil
	local bestIdle = math.huge
	for _, candidate in candidates do
		local idle = if idleSince ~= nil then idleSince[candidate] or 0 else 0
		if idle < bestIdle then
			best = candidate
			bestIdle = idle
		end
	end
	return best
end

return Rules

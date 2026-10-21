--!strict

local ProfileTemplate = require(script.Parent.ProfileTemplate)

export type QuestEntry = ProfileTemplate.QuestEntry

export type QuestTemplate = {
	Title: string,
	Targets: { number },
	BobaBucks: { number }, -- aligned with Targets
	XP: { number }, -- aligned with Targets
}

local QuestConfig = {}

QuestConfig.BASE_SLOTS = 3
QuestConfig.BONUS_SLOT_PASSES = { 219650999, 12385834 }
QuestConfig.FREE_REROLL_PASS = 219650999
QuestConfig.REROLL_COST_BOBABUCKS = 20 -- DEC-037 Q11b

-- Q6-CHAINS (PROPOSED, Jack adjusts): 3 weekly quests at 3-5x daily targets.
-- Reward is 1 Regular Pet Capsule via CapsuleService:GrantEarnedCapsule
-- (the same inventory grant path as the first-shift starter capsule).
QuestConfig.WEEKLY_SLOT_COUNT = 3
QuestConfig.WEEKLY_POOL = {
	"BobaOrdered",
	"CustomersServed",
	"SpillsCleaned",
	"ShiftsCompleted",
}
QuestConfig.WEEKLY_MULTIPLIER_MIN = 3
QuestConfig.WEEKLY_MULTIPLIER_MAX = 5
QuestConfig.WEEKLY_CAPSULE_NAME = "Regular Pet Capsule"

QuestConfig.TYPE_ORDER = {
	"BobaOrdered",
	"CustomersServed",
	"SpillsCleaned",
	"RegularOrders",
	"ShiftsCompleted",
}

local TEMPLATES: { [string]: QuestTemplate } = {
	BobaOrdered = {
		Title = "Prepare %d Boba Drinks",
		Targets = { 3, 5, 8 },
		BobaBucks = { 25, 40, 60 }, -- DEC-036
		XP = { 15, 25, 35 }, -- DEC-036
	},
	CustomersServed = {
		Title = "Serve %d Customers",
		Targets = { 5, 10, 15 },
		BobaBucks = { 25, 40, 60 }, -- DEC-036
		XP = { 15, 25, 35 }, -- DEC-036
	},
	SpillsCleaned = {
		Title = "Clean %d Spills",
		Targets = { 2, 4, 6 },
		BobaBucks = { 20, 30, 45 }, -- DEC-036
		XP = { 10, 20, 30 }, -- DEC-036
	},
	RegularOrders = {
		Title = "Serve %d Real Players",
		Targets = { 1, 2 },
		BobaBucks = { 40, 75 }, -- DEC-036
		XP = { 25, 40 }, -- DEC-036
	},
	ShiftsCompleted = {
		Title = "Complete %d Shifts",
		Targets = { 1, 2 },
		BobaBucks = { 40, 75 }, -- DEC-036
		XP = { 25, 40 }, -- DEC-036
	},
}
QuestConfig.TEMPLATES = TEMPLATES

function QuestConfig.GetCurrentDay(now: number?): number
	return math.floor((now or os.time()) / 86400)
end

-- Q6-CHAINS (PROPOSED): weekly cadence. No existing weekly boundary was found
-- in the codebase (daily systems use UTC-day arithmetic), so this resets on
-- Monday 00:00 server local time. Returns a stable week index derived from
-- the most recent server-local Monday midnight.
function QuestConfig.GetCurrentWeek(nowSeconds: number?): number
	local t = nowSeconds or os.time()
	local parts = os.date("*t", t) :: any
	local mondayOffset = (parts.wday + 5) % 7 -- 0 for Monday .. 6 for Sunday
	local sinceMidnight = parts.hour * 3600 + parts.min * 60 + parts.sec
	local mondayMidnight = t - mondayOffset * 86400 - sinceMidnight
	return math.floor(mondayMidnight / 604800)
end

function QuestConfig.GetQuestTitle(entry: QuestEntry): string
	local template = QuestConfig.TEMPLATES[entry.Type]
	if template then
		return string.format(template.Title, entry.Target)
	end
	return entry.Type
end

function QuestConfig.GenerateDailyQuests(
	dayNumber: number,
	slotCount: number,
	rngOrSeed: (Random | number)?
): { QuestEntry }
	local actualRng: Random
	if typeof(rngOrSeed) == "Random" then
		actualRng = rngOrSeed
	elseif typeof(rngOrSeed) == "number" then
		actualRng = Random.new(rngOrSeed)
	else
		actualRng = Random.new(dayNumber)
	end

	local pool = table.clone(QuestConfig.TYPE_ORDER)
	for i = #pool, 2, -1 do
		local j = actualRng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	local count = math.clamp(slotCount, 1, #pool)
	local quests: { QuestEntry } = {}
	for i = 1, count do
		local questType = pool[i]
		local template = QuestConfig.TEMPLATES[questType]
		local targetIndex = actualRng:NextInteger(1, #template.Targets)
		local target = template.Targets[targetIndex]
		table.insert(quests, {
			Id = string.format("%d_%s_%d", dayNumber, questType, target),
			Type = questType,
			Target = target,
			Progress = 0,
			Completed = false,
			Claimed = false,
			RewardBobaBucks = template.BobaBucks[targetIndex],
			RewardXP = template.XP[targetIndex],
		})
	end
	return quests
end

-- Q6-CHAINS (PROPOSED): 3 weekly quests drawn from WEEKLY_POOL at 3-5x
-- their daily targets. Reward is a capsule (RewardCapsule); BobaBucks/XP are 0.
function QuestConfig.GenerateWeeklyQuests(
	weekNumber: number,
	slotCount: number?,
	rngOrSeed: (Random | number)?
): { QuestEntry }
	local actualRng: Random
	if typeof(rngOrSeed) == "Random" then
		actualRng = rngOrSeed
	elseif typeof(rngOrSeed) == "number" then
		actualRng = Random.new(rngOrSeed)
	else
		actualRng = Random.new(weekNumber)
	end

	local pool = table.clone(QuestConfig.WEEKLY_POOL)
	for i = #pool, 2, -1 do
		local j = actualRng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	local count = math.clamp(slotCount or QuestConfig.WEEKLY_SLOT_COUNT, 1, #pool)
	local quests: { QuestEntry } = {}
	for i = 1, count do
		local questType = pool[i]
		local template = QuestConfig.TEMPLATES[questType]
		local targetIndex = actualRng:NextInteger(1, #template.Targets)
		local multiplier = actualRng:NextInteger(QuestConfig.WEEKLY_MULTIPLIER_MIN, QuestConfig.WEEKLY_MULTIPLIER_MAX)
		local target = template.Targets[targetIndex] * multiplier
		table.insert(quests, {
			Id = string.format("w%d_%s_%d", weekNumber, questType, target),
			Type = questType,
			Target = target,
			Progress = 0,
			Completed = false,
			Claimed = false,
			RewardBobaBucks = 0,
			RewardXP = 0,
			RewardCapsule = QuestConfig.WEEKLY_CAPSULE_NAME,
		})
	end
	return quests
end

function QuestConfig.RollQuest(dayNumber: number, excludeTypes: { [string]: boolean }?, rng: Random?): QuestEntry
	local actualRng = rng or Random.new()
	local candidateTypes: { string } = {}
	for _, typeName in QuestConfig.TYPE_ORDER do
		if not excludeTypes or not excludeTypes[typeName] then
			table.insert(candidateTypes, typeName)
		end
	end
	if #candidateTypes == 0 then
		for _, typeName in QuestConfig.TYPE_ORDER do
			table.insert(candidateTypes, typeName)
		end
	end
	local pickedType = candidateTypes[actualRng:NextInteger(1, #candidateTypes)]
	local template = QuestConfig.TEMPLATES[pickedType]
	local targetIndex = actualRng:NextInteger(1, #template.Targets)
	local target = template.Targets[targetIndex]
	return {
		Id = string.format("%d_%s_%d_%d", dayNumber, pickedType, target, actualRng:NextInteger(1000, 9999)),
		Type = pickedType,
		Target = target,
		Progress = 0,
		Completed = false,
		Claimed = false,
		RewardBobaBucks = template.BobaBucks[targetIndex],
		RewardXP = template.XP[targetIndex],
	}
end

return QuestConfig

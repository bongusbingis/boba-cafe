--!strict

local ProfileTemplate = require(script.Parent.ProfileTemplate)

export type QuestEntry = ProfileTemplate.QuestEntry

export type QuestTemplate = {
	Title: string,
	Targets: { number },
	BobaBucks: number,
	XP: number,
}

local QuestConfig = {}

QuestConfig.BASE_SLOTS = 3
QuestConfig.BONUS_SLOT_PASSES = { 219650999, 12385834 }
QuestConfig.FREE_REROLL_PASS = 219650999
QuestConfig.REROLL_COST_BOBABUCKS = 50

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
		BobaBucks = 50,
		XP = 25,
	},
	CustomersServed = {
		Title = "Serve %d Customers",
		Targets = { 5, 10, 15 },
		BobaBucks = 60,
		XP = 30,
	},
	SpillsCleaned = {
		Title = "Clean %d Spills",
		Targets = { 2, 4, 6 },
		BobaBucks = 40,
		XP = 20,
	},
	RegularOrders = {
		Title = "Serve %d Real Players",
		Targets = { 1, 2 },
		BobaBucks = 75,
		XP = 40,
	},
	ShiftsCompleted = {
		Title = "Complete %d Shifts",
		Targets = { 1, 2 },
		BobaBucks = 50,
		XP = 25,
	},
}
QuestConfig.TEMPLATES = TEMPLATES

function QuestConfig.GetCurrentDay(now: number?): number
	return math.floor((now or os.time()) / 86400)
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
		local target = template.Targets[actualRng:NextInteger(1, #template.Targets)]
		table.insert(quests, {
			Id = string.format("%d_%s_%d", dayNumber, questType, target),
			Type = questType,
			Target = target,
			Progress = 0,
			Completed = false,
			Claimed = false,
			RewardBobaBucks = template.BobaBucks,
			RewardXP = template.XP,
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
	local target = template.Targets[actualRng:NextInteger(1, #template.Targets)]
	return {
		Id = string.format("%d_%s_%d_%d", dayNumber, pickedType, target, actualRng:NextInteger(1000, 9999)),
		Type = pickedType,
		Target = target,
		Progress = 0,
		Completed = false,
		Claimed = false,
		RewardBobaBucks = template.BobaBucks,
		RewardXP = template.XP,
	}
end

return QuestConfig

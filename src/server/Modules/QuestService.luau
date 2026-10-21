--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local QuestConfig = require(Shared.Configuration.QuestConfig)
local GamepassUtil = require(Shared.Utility.GamepassUtil)

export type QuestEntry = QuestConfig.QuestEntry

local DATA_TIMEOUT_SECONDS = 10
local HALFWAY_MIN_TARGET = 4
local questLocks: { [number]: boolean } = {}

-- Ensure legacy / off-sale More Quests pass is registered on GamepassUtil
if (GamepassUtil :: any).Gamepasses and not (GamepassUtil :: any).Gamepasses[12385834] then
	(GamepassUtil :: any).Gamepasses[12385834] = {
		Name = "More Quests",
		Description = "Get +1 daily quest slot!",
		Icon = "",
	}
end

local QuestService = Knit.CreateService({
	Name = "QuestService",
	Client = {
		QuestsUpdated = Knit.CreateSignal(),
		WeeklyQuestsUpdated = Knit.CreateSignal(),
		GetQuests = function(self, player: Player)
			return self.Server:GetQuests(player)
		end,
		GetWeeklyQuests = function(self, player: Player)
			return self.Server:GetWeeklyQuests(player)
		end,
		ClaimQuest = function(self, player: Player, questIndex: number)
			return self.Server:ClaimQuest(player, questIndex)
		end,
		ClaimWeeklyQuest = function(self, player: Player, questIndex: number)
			return self.Server:ClaimWeeklyQuest(player, questIndex)
		end,
		RerollQuest = function(self, player: Player, questIndex: number)
			return self.Server:RerollQuest(player, questIndex)
		end,
	},
})

function QuestService:_getService(name: string): any
	return Knit.GetService(name)
end

function QuestService:_now(): number
	return os.time()
end

function QuestService:_getCurrentDay(): number
	return QuestConfig.GetCurrentDay(self:_now())
end

function QuestService:_getCurrentWeek(): number
	return QuestConfig.GetCurrentWeek(self:_now())
end

function QuestService:_hasPass(player: Player, passId: number): boolean
	local ok, owns = pcall(function()
		return (GamepassUtil :: any):PlayerOwnsPassAsync(player, passId)
	end)
	return ok and owns == true
end

function QuestService:_getPlayerData(player: Player): any
	local ok, playerData = self:_getService("DataService"):GetDataAsync(player):timeout(DATA_TIMEOUT_SECONDS):await()
	if ok and playerData then
		return playerData
	end
	return nil
end

function QuestService:_ensureDailyQuests(player: Player, playerData: any): { QuestEntry }
	if typeof(playerData.Quests) ~= "table" then
		playerData.Quests = {
			AssignedDay = 0,
			ActiveQuests = {},
			FreeRerollsRemaining = 0,
		}
	end

	local currentDay = self:_getCurrentDay()
	local activeQuests = playerData.Quests.ActiveQuests

	if playerData.Quests.AssignedDay ~= currentDay or typeof(activeQuests) ~= "table" or #activeQuests == 0 then
		local hasBonusSlot = false
		for _, passId in QuestConfig.BONUS_SLOT_PASSES do
			if self:_hasPass(player, passId) then
				hasBonusSlot = true
				break
			end
		end

		local slotCount = QuestConfig.BASE_SLOTS + (if hasBonusSlot then 1 else 0)
		local freeRerolls = if self:_hasPass(player, QuestConfig.FREE_REROLL_PASS) then 1 else 0

		-- Rollover race fix: _hasPass yields (PlayerOwnsPassAsync), so a
		-- concurrent ensure may have already rolled the day over while this
		-- call was suspended. Re-read before overwriting so the loser adopts
		-- the winner's fresh quests instead of wiping them with a stale
		-- regeneration. The re-check and the writes below have no yields
		-- between them, so this adoption is atomic.
		local latest = playerData.Quests.ActiveQuests
		if playerData.Quests.AssignedDay == currentDay and typeof(latest) == "table" and #latest > 0 then
			activeQuests = latest
		else
			activeQuests = QuestConfig.GenerateDailyQuests(currentDay, slotCount)

			playerData:SetValue({ "Quests", "AssignedDay" }, currentDay)
			playerData:SetValue({ "Quests", "ActiveQuests" }, activeQuests)
			playerData:SetValue({ "Quests", "FreeRerollsRemaining" }, freeRerolls)

			pcall(function()
				self.Client.QuestsUpdated:Fire(player, activeQuests)
			end)
		end
	end

	return activeQuests
end

function QuestService:_ensureWeeklyQuests(player: Player, playerData: any): { QuestEntry }
	if typeof(playerData.WeeklyQuests) ~= "table" then
		playerData.WeeklyQuests = {
			AssignedWeek = 0,
			ActiveQuests = {},
		}
	end

	local currentWeek = self:_getCurrentWeek()
	local weekly = playerData.WeeklyQuests
	if weekly.AssignedWeek ~= currentWeek or typeof(weekly.ActiveQuests) ~= "table" or #weekly.ActiveQuests == 0 then
		-- Pure generation with no yields between the check and the writes,
		-- so unlike the daily path there is no check-then-act window here.
		local activeQuests = QuestConfig.GenerateWeeklyQuests(currentWeek, QuestConfig.WEEKLY_SLOT_COUNT)

		playerData:SetValue({ "WeeklyQuests", "AssignedWeek" }, currentWeek)
		playerData:SetValue({ "WeeklyQuests", "ActiveQuests" }, activeQuests)

		pcall(function()
			self.Client.WeeklyQuestsUpdated:Fire(player, activeQuests)
		end)
		return activeQuests
	end

	return weekly.ActiveQuests
end

function QuestService:GetQuests(player: Player): { QuestEntry }
	local playerData = self:_getPlayerData(player)
	if not playerData then
		return {}
	end
	return self:_ensureDailyQuests(player, playerData)
end

function QuestService:GetWeeklyQuests(player: Player): { QuestEntry }
	local playerData = self:_getPlayerData(player)
	if not playerData then
		return {}
	end
	return self:_ensureWeeklyQuests(player, playerData)
end

-- Advances every non-completed entry of the given quest type in one quest
-- list. Returns whether anything changed plus the newly completed and
-- halfway entries for notifications.
local function advanceQuestList(
	questList: { QuestEntry },
	questType: string,
	amount: number
): (boolean, { QuestEntry }, { QuestEntry })
	local changed = false
	local newlyCompleted = {}
	local halfwayEntries = {}

	for _, quest in questList do
		if quest.Type == questType and not quest.Completed then
			quest.Progress = math.min(quest.Target, quest.Progress + amount)
			if quest.Progress >= quest.Target then
				quest.Completed = true
				table.insert(newlyCompleted, quest)
			end
			if
				not quest.Completed
				and quest.Target >= HALFWAY_MIN_TARGET
				and (quest :: any).HalfwayPinged ~= true
				and quest.Progress >= math.ceil(quest.Target / 2)
			then
				(quest :: any).HalfwayPinged = true
				table.insert(halfwayEntries, quest)
			end
			changed = true
		end
	end

	return changed, newlyCompleted, halfwayEntries
end

function QuestService:AdvanceQuest(player: Player, questType: string, amount: number?): boolean
	local actualAmount = amount or 1
	if actualAmount <= 0 then
		return false
	end

	local playerData = self:_getPlayerData(player)
	if not playerData then
		return false
	end

	local activeQuests = self:_ensureDailyQuests(player, playerData)
	local weeklyQuests = self:_ensureWeeklyQuests(player, playerData)

	local changed, newlyCompleted, halfwayEntries = advanceQuestList(activeQuests, questType, actualAmount)
	local weeklyChanged, weeklyCompleted, weeklyHalfway = advanceQuestList(weeklyQuests, questType, actualAmount)
	for _, quest in weeklyCompleted do
		table.insert(newlyCompleted, quest)
	end
	for _, quest in weeklyHalfway do
		table.insert(halfwayEntries, quest)
	end
	changed = changed or weeklyChanged

	if changed then
		playerData:SetValue({ "Quests", "ActiveQuests" }, activeQuests)
		pcall(function()
			self.Client.QuestsUpdated:Fire(player, activeQuests)
		end)
	end

	if weeklyChanged then
		playerData:SetValue({ "WeeklyQuests", "ActiveQuests" }, weeklyQuests)
		pcall(function()
			self.Client.WeeklyQuestsUpdated:Fire(player, weeklyQuests)
		end)
	end

	if #newlyCompleted > 0 then
		-- deferred so no caller (serve path) ever waits on the toast
		task.defer(function()
			pcall(function()
				local dialog = self:_getService("DialogService")
				if dialog then
					for _, entry in newlyCompleted do
						dialog:Notify(
							player,
							{
								Text = "Quest complete: "
									.. QuestConfig.GetQuestTitle(entry)
									.. "! Open Quests to claim.",
							} :: any
						)
					end
				end
			end)
		end)
	end

	if #halfwayEntries > 0 then
		task.defer(function()
			pcall(function()
				local dialog = self:_getService("DialogService")
				if dialog then
					for _, quest in halfwayEntries do
						dialog:Notify(
							player,
							{
								Text = string.format(
									"%s: %d/%d",
									QuestConfig.GetQuestTitle(quest),
									quest.Progress,
									quest.Target
								),
							} :: any
						)
					end
				end
			end)
		end)
	end

	return changed
end

local function isValidQuestIndex(index: any): boolean
	if typeof(index) ~= "number" then
		return false
	end
	if index ~= index or index == math.huge or index == -math.huge then
		return false
	end
	if index % 1 ~= 0 or index < 1 then
		return false
	end
	return true
end

function QuestService:ClaimQuest(player: Player, questIndex: number): (boolean, string?)
	if not isValidQuestIndex(questIndex) then
		return false, "InvalidQuestIndex"
	end

	if questLocks[player.UserId] then
		return false, "ClaimInProgress"
	end
	questLocks[player.UserId] = true

	local ok, success, errReason = pcall(function()
		local playerData = self:_getPlayerData(player)
		if not playerData then
			return false, "DataNotLoaded"
		end

		local activeQuests = self:_ensureDailyQuests(player, playerData)
		if questIndex > #activeQuests then
			return false, "QuestNotFound"
		end

		local quest = activeQuests[questIndex]
		if not quest then
			return false, "QuestNotFound"
		end

		if not quest.Completed then
			return false, "QuestNotCompleted"
		end

		if quest.Claimed then
			return false, "AlreadyClaimed"
		end

		quest.Claimed = true
		playerData:SetValue({ "Quests", "ActiveQuests" }, activeQuests)

		if quest.RewardBobaBucks > 0 then
			local currencyService = self:_getService("CurrencyService")
			if currencyService then
				currencyService:Modify(player, "BobaBucks", quest.RewardBobaBucks, "QuestReward")
			end
		end

		if quest.RewardXP > 0 then
			local progressionService = self:_getService("ProgressionService")
			if progressionService then
				if progressionService.AddXP then
					progressionService:AddXP(player, quest.RewardXP)
				elseif progressionService.AddXp then
					progressionService:AddXp(player, quest.RewardXP)
				end
			end
		end

		pcall(function()
			self.Client.QuestsUpdated:Fire(player, activeQuests)
		end)

		return true, nil
	end)

	questLocks[player.UserId] = nil

	if not ok then
		warn(`[QuestService] ClaimQuest error for {player.Name}: {success}`)
		return false, tostring(success)
	end

	return success, errReason
end

-- Q6-CHAINS: claims a completed weekly quest. The reward is 1 Regular Pet
-- Capsule granted through CapsuleService:GrantEarnedCapsule, the same
-- inventory grant path as the first-shift starter capsule. The capsule is
-- granted BEFORE the quest is marked claimed so a full capsule inventory
-- (InventoryFull) does not consume the claim; questLocks serializes
-- concurrent claims for the player so grant-then-mark stays idempotent.
function QuestService:ClaimWeeklyQuest(player: Player, questIndex: number): (boolean, string?)
	if not isValidQuestIndex(questIndex) then
		return false, "InvalidQuestIndex"
	end

	if questLocks[player.UserId] then
		return false, "ClaimInProgress"
	end
	questLocks[player.UserId] = true

	local ok, success, errReason = pcall(function()
		local playerData = self:_getPlayerData(player)
		if not playerData then
			return false, "DataNotLoaded"
		end

		local weeklyQuests = self:_ensureWeeklyQuests(player, playerData)
		if questIndex > #weeklyQuests then
			return false, "QuestNotFound"
		end

		local quest = weeklyQuests[questIndex]
		if not quest then
			return false, "QuestNotFound"
		end

		if not quest.Completed then
			return false, "QuestNotCompleted"
		end

		if quest.Claimed then
			return false, "AlreadyClaimed"
		end

		local capsuleName = quest.RewardCapsule or QuestConfig.WEEKLY_CAPSULE_NAME
		local capsuleService = self:_getService("CapsuleService")
		if capsuleService and capsuleService.GrantEarnedCapsule then
			local granted, grantErr = capsuleService:GrantEarnedCapsule(player, capsuleName)
			if not granted then
				return false, grantErr or "CapsuleGrantFailed"
			end
		end

		quest.Claimed = true
		playerData:SetValue({ "WeeklyQuests", "ActiveQuests" }, weeklyQuests)

		if (quest.RewardBobaBucks or 0) > 0 then
			local currencyService = self:_getService("CurrencyService")
			if currencyService then
				currencyService:Modify(player, "BobaBucks", quest.RewardBobaBucks, "QuestReward")
			end
		end

		if (quest.RewardXP or 0) > 0 then
			local progressionService = self:_getService("ProgressionService")
			if progressionService then
				if progressionService.AddXP then
					progressionService:AddXP(player, quest.RewardXP)
				elseif progressionService.AddXp then
					progressionService:AddXp(player, quest.RewardXP)
				end
			end
		end

		pcall(function()
			self.Client.WeeklyQuestsUpdated:Fire(player, weeklyQuests)
		end)

		return true, nil
	end)

	questLocks[player.UserId] = nil

	if not ok then
		warn(`[QuestService] ClaimWeeklyQuest error for {player.Name}: {success}`)
		return false, tostring(success)
	end

	return success, errReason
end

function QuestService:RerollQuest(player: Player, questIndex: number): (boolean, string?)
	if not isValidQuestIndex(questIndex) then
		return false, "InvalidQuestIndex"
	end

	if questLocks[player.UserId] then
		return false, "RerollInProgress"
	end
	questLocks[player.UserId] = true

	local ok, success, errReason = pcall(function()
		local playerData = self:_getPlayerData(player)
		if not playerData then
			return false, "DataNotLoaded"
		end

		local activeQuests = self:_ensureDailyQuests(player, playerData)
		if questIndex > #activeQuests then
			return false, "QuestNotFound"
		end

		local quest = activeQuests[questIndex]
		if not quest then
			return false, "QuestNotFound"
		end

		if quest.Claimed then
			return false, "AlreadyClaimed"
		end

		if quest.Completed then
			return false, "QuestAlreadyCompleted"
		end

		local charged = false
		local freeRerolls = playerData.Quests.FreeRerollsRemaining or 0
		if freeRerolls > 0 then
			playerData:SetValue({ "Quests", "FreeRerollsRemaining" }, freeRerolls - 1)
		else
			local currentBobaBucks = (playerData.Currency and playerData.Currency.BobaBucks) or 0
			if currentBobaBucks < QuestConfig.REROLL_COST_BOBABUCKS then
				return false, "InsufficientFunds"
			end
			local currencyService = self:_getService("CurrencyService")
			if currencyService then
				if typeof(currencyService.TrySpendAsync) == "function" then
					local spent, spendReason =
						currencyService:TrySpendAsync(player, "BobaBucks", QuestConfig.REROLL_COST_BOBABUCKS)
					if not spent then
						return false, spendReason or "InsufficientFunds"
					end
				else
					currencyService:Modify(player, "BobaBucks", -QuestConfig.REROLL_COST_BOBABUCKS, "QuestReroll")
				end
				charged = true
			end
		end

		-- TrySpendAsync can yield; progress may have completed the quest meanwhile.
		local latestQuests = playerData.Quests and playerData.Quests.ActiveQuests
		local latest = if typeof(latestQuests) == "table" then latestQuests[questIndex] else nil
		if latest == nil or latest.Completed or latest.Claimed then
			if charged then
				local refundService = self:_getService("CurrencyService")
				if refundService then
					refundService:Modify(player, "BobaBucks", QuestConfig.REROLL_COST_BOBABUCKS, "QuestRerollRefund")
				end
			end
			return false, "QuestAlreadyCompleted"
		end
		activeQuests = latestQuests

		local currentDay = self:_getCurrentDay()
		local excludeTypes: { [string]: boolean } = {}
		for i, q in activeQuests do
			if i ~= questIndex then
				excludeTypes[q.Type] = true
			end
		end

		local newQuest = QuestConfig.RollQuest(currentDay, excludeTypes)
		activeQuests[questIndex] = newQuest
		playerData:SetValue({ "Quests", "ActiveQuests" }, activeQuests)

		pcall(function()
			self.Client.QuestsUpdated:Fire(player, activeQuests)
		end)

		return true, nil
	end)

	questLocks[player.UserId] = nil

	if not ok then
		warn(`[QuestService] RerollQuest error for {player.Name}: {success}`)
		return false, tostring(success)
	end

	return success, errReason
end

QuestService.Progress = QuestService.AdvanceQuest

function QuestService:PlayerRemoving(player: Player)
	questLocks[player.UserId] = nil
end

function QuestService:KnitStart()
	local dataService = self:_getService("DataService")
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local ok, playerData = dataService:GetDataAsync(player):timeout(DATA_TIMEOUT_SECONDS):await()
			if ok and playerData and player.Parent then
				self:_ensureDailyQuests(player, playerData)
				self:_ensureWeeklyQuests(player, playerData)
			end
		end)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			local ok, playerData = dataService:GetDataAsync(player):timeout(DATA_TIMEOUT_SECONDS):await()
			if ok and playerData and player.Parent then
				self:_ensureDailyQuests(player, playerData)
				self:_ensureWeeklyQuests(player, playerData)
			end
		end)
	end
end

return QuestService

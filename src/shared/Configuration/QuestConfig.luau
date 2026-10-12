--[[
    Module: QuestConfig
    Description: The daily quest bank.

    Four quests are assigned per day, one per entry in SLOTS, drawn from that tier
    without repeats. They expire at the next UTC midnight and reroll on the next join.

    Each quest declares a Tracker verb. QuestService:Advance(player, verb, value) is what
    moves the needle, so a quest is only completable if something in the codebase
    actually calls Advance with its verb — see TRACKERS below for the live ones.

    Counting modes:
      "Sum"     value is a number and accumulates (PlayTime, RobuxSpent)
      "Unique"  value is a string id and only distinct ids count (FriendJoined)
--]]

local QuestConfig = {}

--- Which tier fills each of the four daily slots. Slot 4 duplicates Easy, matching V3.
QuestConfig.SLOTS = { "Easy", "Moderate", "Hard", "Easy" }

--- The fourth slot is a bonus quest gated behind a game pass. V3 used pass 12385834,
--- which is not in Gamepasses.luau — set this to a real pass id to enable the slot, or
--- leave nil to give every player all four.
QuestConfig.BONUS_SLOT_INDEX = 4
QuestConfig.BONUS_SLOT_PASS_ID = nil

--- Verbs that something in this codebase currently fires. Quests using anything else
--- would be unwinnable, so the bank below is limited to these.
---   PlayTime            QuestService session ticker
---   BobaOrdered         OrderService
---   MacaronOrdered      OrderService
---   HotChocolateOrdered OrderService
---   RobuxSpent          ProcessReceipt
---   FriendJoined        QuestService on join
QuestConfig.TRACKERS = {
	PlayTime = "Sum",
	BobaOrdered = "Sum",
	MacaronOrdered = "Sum",
	HotChocolateOrdered = "Sum",
	RobuxSpent = "Sum",
	FriendJoined = "Unique",
}

--- Ids must be stable and unique across all tiers — they are what gets saved.
QuestConfig.Quests = {
	Easy = {
		{ Id = "play_15", Text = "Play for 15 minutes", Tracker = "PlayTime", Goal = 15, Reward = 10 },
		{ Id = "friend_1", Text = "Play with 1 friend", Tracker = "FriendJoined", Goal = 1, Reward = 10 },
		{ Id = "macaron_1", Text = "Order a macaron", Tracker = "MacaronOrdered", Goal = 1, Reward = 10 },
		{ Id = "cocoa_1", Text = "Order a hot chocolate", Tracker = "HotChocolateOrdered", Goal = 1, Reward = 10 },
		{ Id = "boba_1", Text = "Order a boba", Tracker = "BobaOrdered", Goal = 1, Reward = 10 },
	},

	Moderate = {
		{ Id = "play_45", Text = "Play for 45 minutes", Tracker = "PlayTime", Goal = 45, Reward = 20 },
		{ Id = "boba_5", Text = "Order 5 bobas", Tracker = "BobaOrdered", Goal = 5, Reward = 20 },
		{ Id = "macaron_3", Text = "Order 3 macarons", Tracker = "MacaronOrdered", Goal = 3, Reward = 20 },
		{ Id = "friend_2", Text = "Play with 2 friends", Tracker = "FriendJoined", Goal = 2, Reward = 20 },
		{ Id = "cocoa_3", Text = "Order 3 hot chocolates", Tracker = "HotChocolateOrdered", Goal = 3, Reward = 20 },
	},

	Hard = {
		{ Id = "play_120", Text = "Play for 2 hours", Tracker = "PlayTime", Goal = 120, Reward = 40 },
		{ Id = "boba_15", Text = "Order 15 bobas", Tracker = "BobaOrdered", Goal = 15, Reward = 40 },
		{ Id = "friend_4", Text = "Play with 4 friends", Tracker = "FriendJoined", Goal = 4, Reward = 40 },
		{ Id = "robux_10", Text = "Spend 10 Robux", Tracker = "RobuxSpent", Goal = 10, Reward = 50 },
		{ Id = "macaron_10", Text = "Order 10 macarons", Tracker = "MacaronOrdered", Goal = 10, Reward = 40 },
	},
}

--- Badge awarded on completing any quest. V3 used this id.
QuestConfig.COMPLETION_BADGE_ID = 2124640229

--- Flat index of every quest by id, so saved ids resolve without scanning tiers.
local byId: { [string]: any } = {}
for tier, quests in QuestConfig.Quests do
	for _, quest in quests do
		if byId[quest.Id] then
			warn(string.format("[QuestConfig] Duplicate quest id '%s'.", quest.Id))
		end
		local entry = table.clone(quest)
		entry.Tier = tier
		byId[quest.Id] = entry
	end
end

function QuestConfig.getById(id: string)
	return byId[id]
end

return QuestConfig

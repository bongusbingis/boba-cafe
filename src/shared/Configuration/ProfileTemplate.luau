type InventoryItem = {
	Name: string,
	Tier: string?,
	Equipped: boolean?,
	StackCount: number?,
	Properties: {
		[string]: any,
	}?,
}

type InventoryItemStruct = {
	[string]: InventoryItem,
}

-- Represents a pet capsule that has been activated and is currently incubating.
-- The reward is NOT pre-selected; it is rolled when the hatch completes so
-- that item pool changes during the wait period are respected.
-- TimeAccumulated only counts seconds spent actively playing (offline time
-- does not progress the hatch).
type PendingHatch = {
	CapsuleName: string, -- definition name of the capsule that was used
	TimeAccumulated: number, -- active-play seconds accumulated so far
}

type Statistics = {
	TimePlayed: number, -- accumulated seconds from ended sessions (current session added client-side)
	ItemsOrdered: number,
	BobasOrdered: number,
	BobaBucksEarned: number,
	BobaBucksSpent: number,
	CelebritiesMet: number,
	OrdersCreated: number,
	OrdersPrepared: number,
	SpillsCleaned: number,
	TreasureChestsFound: number,
	ShiftsCompleted: number,
	RegularOrders: number,
	HeartsReceived: number,
	HeartsCount: number,
}

export type PlayerSettings = {
	HeadlessHead: boolean,
	FasterWalkSpeed: boolean,
	UniformRemoverEnabled: boolean?,
	MusicEnabled: boolean,
	SFXEnabled: boolean,
	SyrupHighlighting: boolean,
	ShiftTimerEnabled: boolean,
}

export type DailyRewardData = {
	Streak: number,
	LastClaimTime: number,
}

export type QuestEntry = {
	Id: string,
	Type: string,
	Target: number,
	Progress: number,
	Completed: boolean,
	Claimed: boolean,
	RewardBobaBucks: number,
	RewardXP: number,
	RewardCapsule: string?,
}

export type QuestData = {
	AssignedDay: number,
	ActiveQuests: { QuestEntry },
	FreeRerollsRemaining: number,
}

export type WeeklyQuestData = {
	AssignedWeek: number,
	ActiveQuests: { QuestEntry },
}

export type RegularsData = {
	Visits: { [string]: number },
	RewardClaimed: boolean,
}

export type ProfileTemplate = {
	Currency: {
		Points: number,
		BobaBucks: number,
	},
	Playtime: {
		FirstJoin: number,
		MostRecentJoin: number,
	},
	Inventory: {
		Items: {
			Nametags: InventoryItemStruct,
			Pets: InventoryItemStruct,
			Particles: InventoryItemStruct,
			Capsules: InventoryItemStruct,
		},
		FreeItemsRedeemed: { string },
	},
	Statistics: Statistics,
	PendingBobaBucksRefund: number,
	LastTreasureChestTime: number,
	HatchingPet: PendingHatch | false,
	Nickname: string,
	-- True once the player pressed Skip on the nickname prompt (REVIEW-FIX P2-3).
	NicknameSkipped: boolean,
	-- Codes the player has already redeemed; keyed by normalised code string for O(1) lookups.
	RedeemedCodes: { [string]: boolean },
	-- Developer product receipts already granted; keyed by `ReceiptInfo.PurchaseId`, value is the grant time (os.time()).
	-- Bounded by ProcessReceipt (oldest entries are pruned) so the profile cannot grow without limit.
	ProcessedReceipts: { [string]: number },
	Settings: PlayerSettings,
	Level: number,
	XP: number,
	DailyRewards: DailyRewardData,
	Quests: QuestData,
	BestCombo: number,
	BestShiftPay: number,
	WeeklyQuests: WeeklyQuestData,
	InvitedFriends: { [string]: boolean },
	-- Lifetime Robux donated through the Donate! board (sum of granted donation receipts).
	RobuxDonated: number,
	-- UserId of the inviter who was paid for bringing this player in (0 = none). One invite reward per player ever.
	InviteRewardedBy: number,
	-- Invite rewards this player earned as inviter on UTC day `Day` (daily cap in SocialInviteService).
	InviteRewardsToday: { Day: number, Count: number },
	-- BIG-B5: serves per regular id (RegularsConfig.ROSTER); a key present = stamped.
	-- RewardClaimed is set once when every regular is stamped. Written only by RegularsService.
	Regulars: RegularsData,
}

return {
	Currency = {
		Points = 0,
		BobaBucks = 0,
	},
	Playtime = {
		FirstJoin = 0,
		MostRecentJoin = 0,
	},
	Inventory = {
		Items = {
			Pets = {},
			Nametags = {},
			Capsules = {},
			Particles = {},
		},
		FreeItemsRedeemed = {},
	},
	Statistics = {
		TimePlayed = 0,
		ItemsOrdered = 0,
		BobasOrdered = 0,
		BobaBucksEarned = 0,
		BobaBucksSpent = 0,
		CelebritiesMet = 0,
		OrdersCreated = 0,
		OrdersPrepared = 0,
		SpillsCleaned = 0,
		TreasureChestsFound = 0,
		CustomersServed = 0,
		ShiftsCompleted = 0,
		RegularOrders = 0,
		HeartsReceived = 0,
		HeartsCount = 0,
	},
	PendingBobaBucksRefund = 0,
	LastTreasureChestTime = 0,
	HatchingPet = false,
	Nickname = "",
	NicknameSkipped = false,
	RedeemedCodes = {},
	ProcessedReceipts = {},
	Settings = {
		HeadlessHead = false,
		FasterWalkSpeed = false,
		UniformRemoverEnabled = true,
		MusicEnabled = true,
		SFXEnabled = true,
		SyrupHighlighting = true,
		ShiftTimerEnabled = false,
	},
	Level = 1,
	XP = 0,
	DailyRewards = {
		Streak = 0,
		LastClaimTime = 0,
	},
	Quests = {
		AssignedDay = 0,
		ActiveQuests = {},
		FreeRerollsRemaining = 0,
	},
	BestCombo = 0,
	BestShiftPay = 0,
	WeeklyQuests = {
		AssignedWeek = 0,
		ActiveQuests = {},
	},
	InvitedFriends = {},
	RobuxDonated = 0,
	InviteRewardedBy = 0,
	InviteRewardsToday = {
		Day = 0,
		Count = 0,
	},
	Regulars = {
		Visits = {},
		RewardClaimed = false,
	},
}

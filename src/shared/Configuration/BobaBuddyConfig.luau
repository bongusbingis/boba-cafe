--!strict
--[[
	BobaBuddyConfig
	Configuration for consumable Boba Buddy products (Cleaner & Stocker)
	and their first-pain onboarding upsell modals.
--]]

return {
	LIFESPAN_SECONDS = 180,

	-- Behavior when purchasing the same buddy product while one is already active
	-- "Extend": Adds 180s to existing timer (recommended; prevents visual clutter)
	-- "Spawn": Spawns an additional buddy
	STACK_MODE = "Extend" :: "Extend" | "Spawn",

	CLEANER = {
		RANGE_STUDS = 50,
		CHECK_INTERVAL_SECONDS = 5,
		COOLDOWN_SECONDS = 5,
		MOP_DURATION_SECONDS = 1.2,
		WALK_SPEED = 14,
		ANCHOR_ROBUX = 49,
	},

	STOCKER = {
		RANGE_STUDS = 50,
		CHECK_INTERVAL_SECONDS = 3,
		COOLDOWN_SECONDS = 5,
		STOCK_THRESHOLD_PERCENT = 0.8,
		WALK_SPEED = 16,
		ANCHOR_ROBUX = 99,
	},

	COLORS = {
		Stocker = {
			Skin = Color3.fromRGB(130, 138, 93),
			Liquid = Color3.fromRGB(193, 190, 66),
		},
		Cleaner = {
			Skin = Color3.fromRGB(93, 128, 148),
			Liquid = Color3.fromRGB(75, 175, 220),
		},
	},

	UPSELL = {
		TriggerCount = 1, -- Fires on 1st chore completion; configurable for A/B testing
		DelaySeconds = 8, -- Delay after chore before presenting modal
		SuppressWindowSeconds = 60, -- Minimum delay after any other upsell/dialog
		ConversionWindowSeconds = 300, -- Purchases within 5 min attributed to upsell

		CleanerTitle = "Boba Buddy",
		CleanerText = "That took a minute, didn't it? A Boba Buddy can clean spills for you next time.",

		StockerTitle = "Boba Buddy",
		StockerText = "That took a minute, didn't it? A Boba Buddy can restock for you next time.",

		ButtonSee = "See Buddy",
		ButtonDismiss = "Not Now",
	},

	NPC_SLIP = {
		RATING_PENALTY_PERCENT = 1,
		FALL_DURATION_SECONDS = 2.5,
		COOLDOWN_SECONDS = 5,
		TOAST_MESSAGE = "A customer slipped on a spill! -1% Cafe Rating",
	},
}

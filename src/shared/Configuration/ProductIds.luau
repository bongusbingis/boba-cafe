--!strict

-- Creator Hub developer-product IDs (M3-STUBS, authorized by Jack 2026-10-21).
-- Donations are live IDs (moved here from GamepassBoardController). Everything else is a STUB:
-- nil until Jack pastes the real Creator Hub ID.
-- A nil stub means the offer is skipped/inert (never prompted, never granted).
-- Price display must always use live Marketplace product metadata (DEC-026):
-- never hardcode a Robux price next to these IDs.
--
-- NOTE: Skip Hatch (1143554452) stays hardcoded in
-- src/server/Scripts/ProcessReceipt.server.luau and
-- src/shared/UI/Components/Core/Hud/BottomLeft.luau. It is live money-path
-- code and is intentionally untouched by this change.

-- One live donation developer product. `Robux` is the tier label the product was created at; the receipt's
-- CurrencySpent is what is actually recorded when Roblox provides it.
export type DonationProduct = {
	ProductId: number,
	Robux: number,
}

export type ProductIds = {
	Donations: { DonationProduct },
	BobaParty: number?,
	RushHour: number?,
	-- SEASON-PASS: nil until Jack pastes the Creator Hub IDs (nil = inert).
	SeasonPass: number?,
	StarterBundle: number?,
	BobaBucks: {
		Pack50: number?,
		Pack150: number?,
		Pack500: number?,
		Pack1000: number?,
		Pack5000: number?,
	},
	CapsuleRobux: {
		NametagCapsule1: number?,
		NametagCapsule10: number?,
		NametagCapsule50: number?,
	},
	ChangeNickname: number?,
	-- Limited-time Halloween Gamepass (STUB: Jack to provide Game Pass ID).
	PumpkinLauncherPass: number?,
}

local ProductIds: ProductIds = {
	-- LIVE donation board products (Donate! board in workspace.Assets.GamepassBoards). Shared by
	-- GamepassBoardController (prompts) and ProcessReceipt (grants via DonationReceipts). These are real
	-- Creator Hub IDs: never change an ID or tier without Jack.
	Donations = {
		{ ProductId = 928273533, Robux = 5 },
		{ ProductId = 55777641, Robux = 10 },
		{ ProductId = 680670445, Robux = 20 },
		{ ProductId = 680670692, Robux = 50 },
		{ ProductId = 680670865, Robux = 100 },
		{ ProductId = 680671117, Robux = 500 },
		{ ProductId = 680671325, Robux = 1000 },
		{ ProductId = 680671544, Robux = 5000 },
		{ ProductId = 680671832, Robux = 10000 },
		{ ProductId = 928275862, Robux = 50000 },
		{ ProductId = 928276567, Robux = 100000 },
		{ ProductId = 1168137385, Robux = 500000 },
	},
	-- Creator Hub IDs from Jack (2026-10-21).
	BobaParty = 3300909405,
	RushHour = 3318558073, -- 2-minute server Rush; a purchase during a Rush/Party adds 2 minutes

	-- SEASON-PASS (Jack: paste Creator Hub developer-product IDs here).
	-- Season Pass 299 R$; Starter Bundle ~99 R$ PROPOSED. nil = offer hidden/inert.
	SeasonPass = 3721438870,
	StarterBundle = 3721439110,

	BobaBucks = {
		Pack50 = 1780164398,
		Pack150 = 1780164611,
		Pack500 = 1780165079,
		Pack1000 = 1780165241,
		Pack5000 = 1780164860,
	},
	CapsuleRobux = {
		-- JACK: paste Creator Hub developer-product IDs for Robux capsule offers here
		-- (nil = offer hidden/inert). No capsule Robux offers exist yet; these keys
		-- mirror the BobaBucks nametag-capsule pack sizes as placeholders.
		NametagCapsule1 = 3721439802,
		NametagCapsule10 = 3721439931,
		NametagCapsule50 = 3721439975,
	},
	ChangeNickname = 1152995517,
	PumpkinLauncherPass = nil, -- STUB: Jack to provide Game Pass ID
}

return ProductIds

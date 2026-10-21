--!strict

-- Creator Hub developer-product IDs (M3-STUBS, authorized by Jack 2026-10-21).
-- STUBS ONLY: every value is nil until Jack pastes the real Creator Hub ID.
-- A nil stub means the offer is skipped/inert (never prompted, never granted).
-- Price display must always use live Marketplace product metadata (DEC-026):
-- never hardcode a Robux price next to these IDs.
--
-- NOTE: Skip Hatch (1143554452) stays hardcoded in
-- src/server/Scripts/ProcessReceipt.server.luau and
-- src/shared/UI/Components/Core/Hud/BottomLeft.luau. It is live money-path
-- code and is intentionally untouched by this change.

export type ProductIds = {
	BobaParty: number?,
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
}

local ProductIds: ProductIds = {
	-- JACK: paste the Boba Party Creator Hub developer-product ID here (nil = party purchase disabled).
	BobaParty = nil,
	BobaBucks = {
		-- JACK: paste the Creator Hub developer-product ID for each BB pack (nil = pack inert).
		Pack50 = nil,
		Pack150 = nil,
		Pack500 = nil,
		Pack1000 = nil,
		Pack5000 = nil,
	},
	CapsuleRobux = {
		-- JACK: paste Creator Hub developer-product IDs for Robux capsule offers here
		-- (nil = offer hidden/inert). No capsule Robux offers exist yet; these keys
		-- mirror the BobaBucks nametag-capsule pack sizes as placeholders.
		NametagCapsule1 = nil,
		NametagCapsule10 = nil,
		NametagCapsule50 = nil,
	},
}

return ProductIds

--[[
    Module: MigrationConfig
    Description: Settings for the one-time V4 -> V3 player data migration.

    The V4 game stores profiles with ProfileService. We deliberately do NOT use
    ProfileService to read them: loading a profile would take a session lock and could
    corrupt or steal the live V4 session. Instead we read the underlying DataStore key
    directly with GetAsync, which is read-only and lock-free.

    Verified against boba-v4.rbxl:
      DataService.module.luau  MAIN_DATASTORE_NAME = "PRODUCTION_03"
                               GetProfileStore(MAIN_DATASTORE_NAME, ...)  -- no Scope
                               LoadProfileAsync("Player_" .. player.UserId)
--]]

local MigrationConfig = {}

--- Master switch. Turn off to disable migration entirely without removing the code.
MigrationConfig.ENABLED = true

--- Source DataStore. ProfileService.GetProfileStore was called with a plain string, so
--- no Scope was set and the default ("global") applies — GetDataStore(name) matches.
MigrationConfig.SOURCE_DATASTORE_NAME = "PRODUCTION_03"

--- V4 key format. ProfileService uses the profile_key verbatim as the DataStore key.
MigrationConfig.SOURCE_KEY_FORMAT = "Player_%d"

--- Retry budget for the source read. A failed read leaves the player unmigrated so the
--- next join tries again — it never marks them done.
MigrationConfig.READ_RETRIES = 3
MigrationConfig.RETRY_DELAY = 2

--- Migrate currency balances.
MigrationConfig.MIGRATE_CURRENCY = true

--- Migrate owned cosmetics.
MigrationConfig.MIGRATE_INVENTORY = true

--- Migrate redeemed promo codes so old codes cannot be claimed twice.
MigrationConfig.MIGRATE_REDEEMED_CODES = true

--- V4 item names that differ from this codebase's InventoryItemDefinitions. Names that
--- match exactly need no entry. Anything V4 owns that is neither an exact match nor
--- listed here is skipped and logged, so nothing is silently invented.
---
--- These mappings are judgement calls — edit freely.
MigrationConfig.NAMETAG_ALIASES = {
	Red = "Crimson",
	Green = "Emerald",
	Purple = "Violet",
	Cyan = "Turquoise",
	Black = "Void",
	SunsetOrange = "Sunset",
	BabyBlue = "Ocean",
	Watermelon = "Rose",
	Golden = "Gold",
	Rainbow = "Prism",
	IcyEssence = "Aurora",
	FrostedGlow = "Storm",
	Platinum = "Slate",
	SunnyDay = "Tangerine",
	HarvestSun = "Ember",
	-- Deliberately unmapped (no sensible equivalent): USA.
}

MigrationConfig.PARTICLE_ALIASES = {
	SakuraPetals = "Sakura",
}

--- V4 cosmetic categories with no counterpart here (Uniforms, Trails, Register,
--- Scooping, Pouring, Shaking, DropOff) are ignored entirely.
MigrationConfig.MIGRATABLE_ITEM_TYPES = {
	{ Source = "Nametags", Destination = "Nametags", Aliases = "NAMETAG_ALIASES" },
	{ Source = "Particles", Destination = "Particles", Aliases = "PARTICLE_ALIASES" },
}

return MigrationConfig

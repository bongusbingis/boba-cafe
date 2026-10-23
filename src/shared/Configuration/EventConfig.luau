--!strict
--[[
	EventConfig.luau
	Configuration for server events and staff hosting (REVIVAL-001 M4-EVENTS, DEC-032).
]]

export type EventDefinition = {
	Name: string,
	Attribute: string,
	Description: string,
}

export type EventConfigType = {
	EVENT_DURATION_SECONDS: number,
	HOST_COOLDOWN_SECONDS: number,
	AUTO_EVENT_INTERVAL_SECONDS: number,
	MIN_STAFF_RANK: number,
	EVENTS: { [string]: EventDefinition },
}

local EventConfig: EventConfigType = {
	EVENT_DURATION_SECONDS = 600,
	HOST_COOLDOWN_SECONDS = 0,--1800,
	AUTO_EVENT_INTERVAL_SECONDS = 3600,
	MIN_STAFF_RANK = 10,

	EVENTS = {
		RushHour = {
			Name = "Rush Hour",
			Attribute = "RushHour",
			Description = "2x Customer Pacing & Tips!",
		},
		KarenRush = {
			Name = "Karen Day",
			Attribute = "KarenRush",
			Description = "Impatient Karens have arrived for 3x Tips!",
		},
		TreasureFrenzy = {
			Name = "Treasure Frenzy",
			Attribute = "TreasureFrenzy",
			Description = "Treasure chests are respawning rapidly!",
		},
	},
}

return EventConfig

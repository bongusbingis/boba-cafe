--!strict
return {
	Name = "start-event",
	Aliases = { "event", "startevent" },
	Description = "Starts a server event (RushHour, KarenRush, TreasureFrenzy).",
	Group = "Events",
	Args = {
		{
			Type = "eventType",
			Name = "event",
			Description = "Event to start (RushHour, KarenRush, TreasureFrenzy)",
		},
		{
			Type = "integer",
			Name = "duration",
			Description = "Duration in seconds",
			Optional = true,
		},
	},
}

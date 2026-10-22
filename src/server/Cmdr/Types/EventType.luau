return function(registry)
	registry:RegisterType(
		"eventType",
		registry.Cmdr.Util.MakeEnumType("eventType", {
			"RushHour",
			"KarenRush",
			"TreasureFrenzy",
		})
	)
end

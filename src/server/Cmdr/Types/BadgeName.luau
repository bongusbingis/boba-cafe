return function(registry)
	registry:RegisterType(
		"badgeName",
		registry.Cmdr.Util.MakeEnumType("badgeName", {
			"Welcome",
			"MetTheOwner",
			"MetTheCoOwner",
			"MetADeveloper",
			"FirstQuest",
			"FirstStaff",
			"Celebrity",
			"SakuraIsland",
			"TreasureChest",
			"ShinyPet",
			"HalloweenEvent",
			"Slipped",
			"FirstPaycheck",
			"LevelUp",
		})
	)
end

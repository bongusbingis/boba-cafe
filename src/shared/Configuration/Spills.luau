return {
	MaxTotal = 20,
    MaxSpawned = 15,
	Min_Distance = {
		Floor = 15,
	},
	PointIncrement = 1,

	--- Server-wide cleanliness reward. When the cafe reaches 100% clean, every player
	--- earns Points at this multiplier for BoostDuration seconds, then it resets to 0%.
	--- Applied by SpillService via CurrencyService.GlobalMulti.
	BoostMultiplier = 2,
	BoostDuration = 300,
}

--!strict
--[[
	InstantBrewConfig
	Configuration for the Instant Brewing gamepass and its first non-onboarding order upsell modal.
--]]

return {
	PASS_ID = 12385760,
	PERK_NAME = "StationHold50",

	UPSELL = {
		DelaySeconds = 6, -- Delay after serve before presenting modal so player sees payout/effects
		SuppressWindowSeconds = 60, -- Minimum delay after any other upsell/dialog
		ConversionWindowSeconds = 300, -- Purchases within 5 min attributed to upsell

		Title = "Instant Brewing",
		Text = "Didn't that take a long time? Buy Instant Brew to make drinks faster!",

		ButtonBuy = "Buy Instant Brew",
		ButtonDismiss = "Not Now",
	},
}

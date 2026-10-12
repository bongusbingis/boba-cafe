--[[
    Module: LoadingConfig
    Description: The loading screen shown while the game finishes replicating.

    V3 shipped four near-identical loading screens (MainLoading, MainLoadingEvent,
    MainLoadingSpecial, MainLoadingSpecial2) as separate copies. There is one screen
    here and the seasonal differences are data: pick a variant with `getVariant`.
--]]

local LoadingConfig = {}

--- Which variant to show. Set to a key of Variants, or "Auto" to choose by date.
LoadingConfig.ACTIVE_VARIANT = "Auto"

--- Minimum seconds the screen stays up, so it does not flash on fast joins.
LoadingConfig.MIN_DISPLAY_TIME = 2

--- Seconds between rotating facts.
LoadingConfig.FACT_INTERVAL = 4

--- Seasonal variants. `Months` drives "Auto" selection.
LoadingConfig.Variants = {
	Default = {
		Background = Color3.fromRGB(143, 169, 127),
		Accent = Color3.fromRGB(253, 240, 190),
		Title = "Boba Cafe",
	},
	Halloween = {
		Months = { 10 },
		Background = Color3.fromRGB(60, 40, 80),
		Accent = Color3.fromRGB(255, 150, 40),
		Title = "Boba Cafe",
	},
	Winter = {
		Months = { 12, 1 },
		Background = Color3.fromRGB(90, 130, 170),
		Accent = Color3.fromRGB(240, 250, 255),
		Title = "Boba Cafe",
	},
	Summer = {
		Months = { 6, 7, 8 },
		Background = Color3.fromRGB(120, 180, 200),
		Accent = Color3.fromRGB(255, 240, 180),
		Title = "Boba Cafe",
	},
}

--- Shown one at a time while loading. V3 called these "RandomFact".
LoadingConfig.Facts = {
	"Tapioca pearls are made from cassava root!",
	"Boba tea originated in Taiwan in the 1980s.",
	"You can customise your nametag colour in the shop.",
	"Clean spills to help the cafe reach 100% cleanliness for a server-wide bonus!",
	"Complete daily quests to earn extra Boba Bucks.",
	"Claim a reward every day — the streak resets if you miss one.",
	"Capsules can contain pets, nametags or particles.",
	"Staff can prepare orders in the kitchen for Points.",
	"Check the leaderboards to see the top players.",
	"Ask a barista for a recommendation!",
}

--- The variant for the current date, or the explicitly configured one.
function LoadingConfig.getVariant(now: number?)
	if LoadingConfig.ACTIVE_VARIANT ~= "Auto" then
		return LoadingConfig.Variants[LoadingConfig.ACTIVE_VARIANT] or LoadingConfig.Variants.Default
	end

	local month = tonumber(os.date("!%m", now or os.time()))

	for name, variant in LoadingConfig.Variants do
		if name ~= "Default" and variant.Months then
			for _, variantMonth in variant.Months do
				if variantMonth == month then
					return variant
				end
			end
		end
	end

	return LoadingConfig.Variants.Default
end

return LoadingConfig

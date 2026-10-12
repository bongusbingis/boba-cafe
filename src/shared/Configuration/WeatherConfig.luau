--[[
    Module: WeatherConfig
    Description: In-game clock and weather cycle.

    V3's WeatherService:Start() hardcoded SetState("Snowing") with the real cycle
    commented out — a seasonal change that was never reverted, the same trap as the
    music playlist. The cycle is data here so it cannot rot silently.
--]]

local WeatherConfig = {}

---> clock

--- Real seconds per in-game minute. V3 advanced one minute per second.
WeatherConfig.SECONDS_PER_GAME_MINUTE = 1

--- Hour the day starts at when the server boots.
WeatherConfig.START_HOUR = 16
WeatherConfig.START_MINUTE = 0

--- Hour that triggers the warm "golden hour" tint.
WeatherConfig.GOLDEN_HOUR = 17
WeatherConfig.GOLDEN_HOUR_TWEEN = 3

WeatherConfig.NORMAL_TINT = Color3.fromRGB(255, 242, 233)
WeatherConfig.GOLDEN_TINT = Color3.fromRGB(255, 247, 201)

---> weather

--- Set to a key of States to pin the weather, or "Cycle" to run Rotation below.
WeatherConfig.ACTIVE_STATE = "Cycle"

WeatherConfig.States = {
    Sunny = {},
    Raining = {},
    Snowing = {},
}

--- Ordered cycle, each entry lasting Duration seconds.
WeatherConfig.Rotation = {
    { State = "Sunny", Duration = 900 },
    { State = "Raining", Duration = 300 },
}

return WeatherConfig

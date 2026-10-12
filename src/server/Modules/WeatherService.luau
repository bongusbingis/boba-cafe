--[[
    Module: WeatherService
    Description: Owns the in-game clock and the weather state.

    The clock drives Lighting.TimeOfDay (which replicates on its own) and publishes a
    formatted string for the HUD clock. Weather is a named state other systems can read
    or react to.

    Everything degrades: a missing ColorCorrection only costs the golden-hour tint, it
    never stops the clock.
--]]

---> services
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local WeatherConfig = require(Shared.Configuration.WeatherConfig)

---> module declaration
local WeatherService = Knit.CreateService({
    Name = "WeatherService",
    Client = {
        --- Fired once per in-game minute with the formatted clock string.
        TimeChanged = Knit.CreateSignal(),
        --- Fired when the weather state changes.
        WeatherChanged = Knit.CreateSignal(),
    },
})

---> state

local currentHour = WeatherConfig.START_HOUR
local currentMinute = WeatherConfig.START_MINUTE
local currentState = "Sunny"
local currentTimeString = ""

---> private

--- 13:05 -> "1:05 PM". Midnight and noon are the cases V3's version got subtly wrong,
--- so they are handled explicitly here.
local function formatTime(hour: number, minute: number): string
    local suffix = if hour >= 12 and hour < 24 then "PM" else "AM"

    local displayHour = hour % 12
    if displayHour == 0 then
        displayHour = 12
    end

    return string.format("%d:%02d %s", displayHour, minute, suffix)
end

local function applyGoldenHour()
    local colorCorrection = Lighting:FindFirstChildWhichIsA("ColorCorrectionEffect")
    if not colorCorrection then
        return
    end

    local target = if currentHour == WeatherConfig.GOLDEN_HOUR
        then WeatherConfig.GOLDEN_TINT
        else WeatherConfig.NORMAL_TINT

    if colorCorrection.TintColor == target then
        return
    end

    TweenService:Create(
        colorCorrection,
        TweenInfo.new(WeatherConfig.GOLDEN_HOUR_TWEEN),
        { TintColor = target }
    ):Play()
end

function WeatherService:_tickClock()
    currentMinute += 1

    if currentMinute >= 60 then
        currentMinute = 0
        currentHour += 1
    end

    if currentHour >= 24 then
        currentHour = 0
    end

    Lighting.TimeOfDay = string.format("%02d:%02d:00", currentHour, currentMinute)

    applyGoldenHour()

    currentTimeString = formatTime(currentHour, currentMinute)
    self.Client.TimeChanged:FireAll(currentTimeString)
end

---> public

function WeatherService:GetTime(): string
    return currentTimeString
end

function WeatherService:GetState(): string
    return currentState
end

function WeatherService:SetState(stateName: string)
    if not WeatherConfig.States[stateName] then
        warn(string.format("[WeatherService] Unknown weather state '%s'.", tostring(stateName)))
        return
    end

    if currentState == stateName then
        return
    end

    currentState = stateName
    self.Client.WeatherChanged:FireAll(currentState)
end

---> client

function WeatherService.Client:GetTime(): string
    return self.Server:GetTime()
end

function WeatherService.Client:GetState(): string
    return self.Server:GetState()
end

---> lifecycle

function WeatherService:KnitStart()
    currentTimeString = formatTime(currentHour, currentMinute)
    Lighting.TimeOfDay = string.format("%02d:%02d:00", currentHour, currentMinute)

    ---> clock
    task.spawn(function()
        while true do
            task.wait(WeatherConfig.SECONDS_PER_GAME_MINUTE)
            self:_tickClock()
        end
    end)

    ---> weather
    task.spawn(function()
        if WeatherConfig.ACTIVE_STATE ~= "Cycle" then
            self:SetState(WeatherConfig.ACTIVE_STATE)
            return
        end

        if #WeatherConfig.Rotation == 0 then
            return
        end

        while true do
            for _, entry in WeatherConfig.Rotation do
                self:SetState(entry.State)
                task.wait(entry.Duration)
            end
        end
    end)
end

return WeatherService

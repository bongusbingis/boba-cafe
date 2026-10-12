---> services
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local WeatherConfig = require(Shared.Configuration.WeatherConfig)

---> module declaration
local ClientWeatherController = Knit.CreateController({
	Name = "ClientWeatherController",
	CurrentState = nil,
	Time = "",
})

---> constants

local TRANSITION_TIME = 4

--- Lighting presets per weather state. The server owns which state is active;
--- rendering it is entirely client-side so it costs no bandwidth.
local PRESETS = {
	Sunny = {
		Ambient = Color3.fromRGB(140, 140, 140),
		OutdoorAmbient = Color3.fromRGB(150, 150, 150),
		Brightness = 2,
		FogEnd = 10000,
	},
	Raining = {
		Ambient = Color3.fromRGB(90, 95, 105),
		OutdoorAmbient = Color3.fromRGB(95, 100, 110),
		Brightness = 1,
		FogEnd = 600,
	},
	Snowing = {
		Ambient = Color3.fromRGB(120, 125, 135),
		OutdoorAmbient = Color3.fromRGB(130, 135, 145),
		Brightness = 1.5,
		FogEnd = 450,
	},
}

---> private

function ClientWeatherController:_applyState(stateName: string)
	if stateName == self.CurrentState then
		return
	end
	self.CurrentState = stateName

	local preset = PRESETS[stateName]
	if not preset then
		-- Unknown state (config added one without a preset): leave lighting alone
		-- rather than snapping to something arbitrary.
		warn(`[ClientWeatherController] No lighting preset for '{stateName}'.`)
		return
	end

	TweenService:Create(Lighting, TweenInfo.new(TRANSITION_TIME), preset):Play()
end

---> lifecycle

function ClientWeatherController:KnitStart()
	local weatherService = Knit.GetService("WeatherService")

	weatherService.WeatherChanged:Connect(function(stateName: string)
		self:_applyState(stateName)
	end)

	weatherService.TimeChanged:Connect(function(timeText: string)
		self.Time = timeText
	end)

	-- Catch up on join: the state was likely set before this client connected.
	task.spawn(function()
		local ok, state = weatherService:GetState():await()
		if ok and state then
			self:_applyState(state)
		end

		local timeOk, timeText = weatherService:GetTime():await()
		if timeOk and timeText then
			self.Time = timeText
		end
	end)

	-- Pinned states never fire WeatherChanged, so apply the configured one directly.
	if WeatherConfig.ACTIVE_STATE ~= "Cycle" then
		self:_applyState(WeatherConfig.ACTIVE_STATE)
	end
end

return ClientWeatherController

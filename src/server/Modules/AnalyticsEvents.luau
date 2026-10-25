--!strict
--[[
    Module: AnalyticsEvents
    Description: Comprehensive wrapper over Roblox AnalyticsService for:
    - First-Time User Experience (FTUE) Onboarding Funnel (LogOnboardingFunnelStepEvent)
    - Custom and legacy Funnels (LogFunnelStepEvent)
    - Economy Sources & Sinks for BobaBucks & Points with SKU & type mapping (LogEconomyEvent)
    - Progression Tracking for Career Levels, Shifts, & Season Pass (LogProgressionEvent)
    - Custom Gameplay, Engagement, & Monetization Events (LogCustomEvent)
    - Player Segmentation (GetPlayerSegmentsAsync)
--]]

---> services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

---> modules
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

---> variables
local AnalyticsEvents = Knit.CreateService({ Name = "AnalyticsEvents", Client = {} })

local sessionIds: { [Player]: string } = {}
local stepsSeen: { [Player]: { [number]: boolean } } = {}
local onboardingStepsSeen: { [Player]: { [number]: boolean } } = {}
local warned = false

-- Map internal reason strings to standard Roblox AnalyticsEconomyTransactionType names
local TRANSACTION_TYPE_MAP: { [string]: string } = {
	["Shop"] = Enum.AnalyticsEconomyTransactionType.Shop.Name,
	["CafeUpgrade"] = Enum.AnalyticsEconomyTransactionType.Shop.Name,
	["Capsule"] = Enum.AnalyticsEconomyTransactionType.Shop.Name,
	["Cosmetics"] = Enum.AnalyticsEconomyTransactionType.Shop.Name,
	["Nametag"] = Enum.AnalyticsEconomyTransactionType.Shop.Name,

	["Gameplay"] = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
	["ShiftPay"] = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
	["ShiftBonus"] = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
	["CustomerTip"] = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
	["Spill"] = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
	["Order"] = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,
	["ShiftStreak"] = Enum.AnalyticsEconomyTransactionType.Gameplay.Name,

	["DailyReward"] = Enum.AnalyticsEconomyTransactionType.TimedReward.Name,
	["TreasureChest"] = Enum.AnalyticsEconomyTransactionType.TimedReward.Name,
	["TimedReward"] = Enum.AnalyticsEconomyTransactionType.TimedReward.Name,

	["IAP"] = Enum.AnalyticsEconomyTransactionType.IAP.Name,
	["RobuxPack"] = Enum.AnalyticsEconomyTransactionType.IAP.Name,
	["StarterBundle"] = Enum.AnalyticsEconomyTransactionType.IAP.Name,
	["Product"] = Enum.AnalyticsEconomyTransactionType.IAP.Name,
	["Gamepass"] = Enum.AnalyticsEconomyTransactionType.IAP.Name,

	["Onboarding"] = Enum.AnalyticsEconomyTransactionType.Onboarding.Name,
	["ContextualPurchase"] = Enum.AnalyticsEconomyTransactionType.ContextualPurchase.Name,
}

local function safe(callback: () -> ())
	task.spawn(function()
		local ok, err = pcall(callback)
		if not ok and not warned and not RunService:IsStudio() then
			warned = true
			warn(`[AnalyticsEvents] AnalyticsService call failed (further failures are silent): {err}`)
		end
	end)
end

local function analytics(): any
	return game:GetService("AnalyticsService")
end

---> api

--- Logs an Onboarding Funnel step (FTUE) via Roblox's native LogOnboardingFunnelStepEvent.
--- Recorded once per player per step index.
function AnalyticsEvents:OnboardingFunnel(player: Player, stepIndex: number, stepName: string)
	local seen = onboardingStepsSeen[player]
	if seen == nil then
		seen = {}
		onboardingStepsSeen[player] = seen
	end
	if seen[stepIndex] then
		return
	end
	seen[stepIndex] = true

	safe(function()
		analytics():LogOnboardingFunnelStepEvent(player, stepIndex, stepName)
	end)
end

--- Logs a Funnel step (legacy / repeatable).
function AnalyticsEvents:Funnel(player: Player, stepIndex: number, stepName: string, funnelName: string?)
	local name = funnelName or "FirstSession"
	local seen = stepsSeen[player]
	if seen == nil then
		seen = {}
		stepsSeen[player] = seen
		sessionIds[player] = HttpService:GenerateGUID(false)
	end
	if (seen :: any)[stepIndex] then
		return
	end
	(seen :: any)[stepIndex] = true
	local sessionId = sessionIds[player]
	safe(function()
		analytics():LogFunnelStepEvent(player, name, sessionId, stepIndex, stepName)
	end)
end

--- Logs an Economy source (isSource = true) or sink (isSource = false).
--- Parameter order: player, flowType, currencyType, amount, endingBalance, transactionType, itemSku
function AnalyticsEvents:Economy(
	player: Player,
	isSource: boolean,
	amount: number,
	endingBalance: number,
	transactionType: string?,
	currencyType: string?,
	itemSku: string?
)
	local flow = if isSource then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
	local currency = currencyType or "BobaBucks"
	local rawType = transactionType or (if isSource then "Gameplay" else "Shop")
	local mappedType = TRANSACTION_TYPE_MAP[rawType] or Enum.AnalyticsEconomyTransactionType.Gameplay.Name
	local sku = itemSku or ""

	safe(function()
		analytics():LogEconomyEvent(player, flow, currency, math.abs(amount), endingBalance, mappedType, sku)
	end)
end

--- Logs a Progression event (Start, Complete, Fail) for levels, shifts, or season pass.
function AnalyticsEvents:Progression(
	player: Player,
	category: string,
	status: Enum.AnalyticsProgressionType,
	level: number,
	levelName: string?
)
	safe(function()
		analytics():LogProgressionEvent(player, category, status, level, levelName or "")
	end)
end

function AnalyticsEvents:ProgressionStart(player: Player, category: string, level: number, levelName: string?)
	self:Progression(player, category, Enum.AnalyticsProgressionType.Start, level, levelName)
end

function AnalyticsEvents:ProgressionComplete(player: Player, category: string, level: number, levelName: string?)
	self:Progression(player, category, Enum.AnalyticsProgressionType.Complete, level, levelName)
end

function AnalyticsEvents:ProgressionFail(player: Player, category: string, level: number, levelName: string?)
	self:Progression(player, category, Enum.AnalyticsProgressionType.Fail, level, levelName)
end

--- Logs a Custom game event with an optional numeric value or count.
function AnalyticsEvents:Custom(player: Player, name: string, value: number?)
	safe(function()
		analytics():LogCustomEvent(player, name, value or 1)
	end)
end

function AnalyticsEvents.Client:Custom(player: Player, name: any, value: any, extra: any)
	local eventName: string? = nil
	local eventValue: any = nil
	if typeof(name) == "string" then
		eventName = name
		eventValue = value
	elseif typeof(value) == "string" then
		eventName = value
		eventValue = extra
	end
	if typeof(eventName) ~= "string" then
		return
	end
	pcall(function()
		self.Server:Custom(player, eventName, eventValue)
	end)
end

--- Safely retrieves player segment buckets for personalization/offers.
function AnalyticsEvents:GetSegments(player: Player): {
	HasData: boolean,
	ActivePayerStatus: any,
	WhenUserFirstPlayed: any,
	PlatformSpenderStatus: any,
}
	local ok, segments = pcall(function()
		return analytics():GetPlayerSegmentsAsync(player)
	end)
	if ok and typeof(segments) == "table" and segments.HasData == true then
		return segments
	end
	return {
		HasData = false,
		ActivePayerStatus = nil,
		WhenUserFirstPlayed = nil,
		PlatformSpenderStatus = nil,
	}
end

---> lifecycle

function AnalyticsEvents:KnitStart()
	local function onAdded(player: Player)
		self:OnboardingFunnel(player, 1, "Joined")
		self:Funnel(player, 1, "Joined")
	end
	Players.PlayerAdded:Connect(onAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		stepsSeen[player] = nil
		onboardingStepsSeen[player] = nil
		sessionIds[player] = nil
	end)
end

return AnalyticsEvents

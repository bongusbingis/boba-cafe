--!strict
--[[
    Module: AnalyticsEvents
    Description: REVIVAL-001 M1.MEASURE. Thin wrapper over Roblox AnalyticsService (first-session
    funnel, BobaBucks economy events, custom events). Named AnalyticsEvents so it does not
    shadow the Roblox service. A failing call warns once and never errors or yields the caller.
--]]

---> services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> modules
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

---> variables
local AnalyticsEvents = Knit.CreateService({ Name = "AnalyticsEvents", Client = {} })

local sessionIds: { [Player]: string } = {}
local stepsSeen: { [Player]: { [number]: boolean } } = {}
local warned = false

local function safe(callback: () -> ())
	task.spawn(function()
		local ok, err = pcall(callback)
		if not ok and not warned then
			warned = true
			warn(`[AnalyticsEvents] AnalyticsService call failed (further failures are silent): {err}`)
		end
	end)
end

local function analytics(): any
	return game:GetService("AnalyticsService")
end

---> api

--- Logs a FirstSession funnel step once per player per step.
function AnalyticsEvents:Funnel(player: Player, stepIndex: number, stepName: string)
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
		analytics():LogFunnelStepEvent(player, "FirstSession", sessionId, stepIndex, stepName)
	end)
end

--- Logs a BobaBucks source (isSource) or sink. `amount` is the absolute size.
function AnalyticsEvents:Economy(
	player: Player,
	isSource: boolean,
	amount: number,
	endingBalance: number,
	transactionType: string
)
	local flow = if isSource then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
	safe(function()
		analytics():LogEconomyEvent(player, flow, "BobaBucks", endingBalance, math.abs(amount), transactionType)
	end)
end

function AnalyticsEvents:Custom(player: Player, name: string, value: number?)
	safe(function()
		analytics():LogCustomEvent(player, name, value or 1)
	end)
end

---> lifecycle

function AnalyticsEvents:KnitStart()
	local function onAdded(player: Player)
		self:Funnel(player, 1, "Joined")
	end
	Players.PlayerAdded:Connect(onAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		stepsSeen[player] = nil
		sessionIds[player] = nil
	end)
end

return AnalyticsEvents

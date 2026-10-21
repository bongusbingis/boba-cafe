--[[
	Module: PourMoments
	Description: Server side of the station skill moment (REVIVAL-001 BIG-B7, DEC-058 redesign).
	Coordinates two-phase station pour moments: creates windows, awaits client taps
	with bounded timeouts and cancellation guards, applies drink craft attributes,
	and calculates pour tips at NPC serve. A pour never lowers the drink's grade:
	a miss or a timeout is Good with no tip (AUDIT-FIX D2.1).
--]]

---> Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

---> Requires

local Knit = require(Packages.Knit)
local KitchenConfig = require(ReplicatedStorage.Shared.Configuration.KitchenConfig)
local PourMeter = require(ReplicatedStorage.Shared.Kitchen.PourMeter)

---> Types

type KitchenService = {
	Client: {
		PourWindowOpened: any,
		PourResolved: any,
	},
}

type RecipeData = {
	SkillMoment: boolean?,
	[string]: any,
}

export type PourMoments = {
	_service: KitchenService,
	_windows: { [Player]: PourMeter.Window },
	_nextId: number,
	_unlocked: { [Player]: boolean },
	_pendingThreads: { [Player]: thread },
	_pendingCancels: { [Player]: () -> () },
	_pendingFinish: { [Player]: (PourMeter.PourTier?, string?) -> () },
	Start: (self: PourMoments) -> (),
	AwaitPour: (self: PourMoments, player: Player, recipeData: RecipeData, model: Model?) -> PourMeter.PourTier?,
	ReportTap: (self: PourMoments, player: Player, windowId: any, claimedElapsed: any) -> PourMeter.PourTier?,
	TipForTools: (self: PourMoments, tools: { Instance }) -> number,
	MaybeOpen: (self: PourMoments, player: Player, recipeData: RecipeData) -> (),
}

---> Module

local PourMoments = {}
PourMoments.__index = PourMoments

local PERFECT_ATTRIBUTE = "PerfectPours"

local function pourConfig(): PourMeter.Config
	return KitchenConfig.POUR_METER
end

local function getHeldTool(player: Player): Tool?
	local character = player.Character
	return character and character:FindFirstChildWhichIsA("Tool")
end

function PourMoments.new(service: KitchenService): PourMoments
	return setmetatable({
		_service = service,
		_windows = {},
		_nextId = 0,
		_unlocked = {},
		_pendingThreads = {},
		_pendingCancels = {},
		_pendingFinish = {},
	}, PourMoments) :: any
end

function PourMoments:_cancelPending(player: Player)
	local cancelFn = self._pendingCancels[player]
	if cancelFn then
		self._pendingCancels[player] = nil
		cancelFn()
	end
	self._windows[player] = nil
	self._pendingThreads[player] = nil
	self._pendingFinish[player] = nil
end

-- A first serve unlocks the meter for that player. Walkouts do not count.
function PourMoments:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		self:_cancelPending(player)
		self._unlocked[player] = nil
	end)
	local ok, customerService = pcall(Knit.GetService, "CustomerService")
	if ok and customerService ~= nil and customerService.CustomerResolved ~= nil then
		customerService.CustomerResolved:Connect(function(player: Player, result: any)
			if typeof(result) == "table" and result.Kind == "Served" then
				self._unlocked[player] = true
			end
		end)
	else
		warn("[PourMoments] CustomerService.CustomerResolved not found; pour meters stay hidden.")
	end
end

-- Two-phase async pour moment. Yields the calling thread until a tap is reported
-- or the window expires. Cancels cleanly if the player walks away, un-equips the
-- tool, or disconnects.
function PourMoments:AwaitPour(player: Player, recipeData: RecipeData, model: Model?): PourMeter.PourTier?
	if KitchenConfig.SKILL_MOMENTS_ENABLED ~= true then
		return "Good"
	end
	if type(recipeData) ~= "table" or recipeData.SkillMoment ~= true then
		return "Good"
	end

	-- If player has not yet served their first customer (unlocked == false), default
	-- to "Good" without showing the GUI so new players aren't overwhelmed on customer 1.
	if self._unlocked[player] ~= true then
		local tool = getHeldTool(player)
		if tool then
			local liquid = tool:FindFirstChild("Liquid")
			if liquid and liquid:IsA("BasePart") then
				liquid.Transparency = 0
			end
		end
		return "Good"
	end

	local initialTool = getHeldTool(player)
	if not initialTool then
		return nil
	end

	self:_cancelPending(player)

	local config = pourConfig()
	self._nextId += 1
	local windowId = self._nextId
	local window = PourMeter.NewWindow(windowId, os.clock(), math.random(), config)
	self._windows[player] = window

	self._service.Client.PourWindowOpened:Fire(player, PourMeter.ToView(window))

	local currentThread = coroutine.running()
	self._pendingThreads[player] = currentThread

	local cleaned = false
	local cancelSelf: (() -> ())? = nil
	local timeoutTask: thread? = nil
	local unequipConn: RBXScriptConnection? = nil
	local walkCheckTask: thread? = nil

	-- Never task.cancel the thread cleanup is running on: the timeout and walk-away
	-- watchers call finish() from inside themselves (TAKEOVER-FIX 1). The handle is
	-- cleared first and the cancel is pcall'd, so cleanup can never throw and strand
	-- the awaiting thread (which would pin InteractionRunner's station lock).
	local function stopThread(handle: thread?)
		if handle == nil or handle == coroutine.running() then
			return
		end
		pcall(task.cancel, handle)
	end

	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true
		local timeoutHandle, walkHandle = timeoutTask, walkCheckTask
		timeoutTask = nil
		walkCheckTask = nil
		if unequipConn then
			unequipConn:Disconnect()
			unequipConn = nil
		end
		if self._windows[player] == window then
			self._windows[player] = nil
		end
		if self._pendingThreads[player] == currentThread then
			self._pendingThreads[player] = nil
		end
		if self._pendingCancels[player] ~= nil and self._pendingCancels[player] == cancelSelf then
			self._pendingCancels[player] = nil
		end
		stopThread(timeoutHandle)
		stopThread(walkHandle)
	end

	-- The single resolve path. Idempotent; resumes the awaiting thread exactly once.
	local resumed = false
	local reason = "Ok"
	local function finish(tier: PourMeter.PourTier?, why: string?)
		cleanup()
		if resumed then
			return
		end
		resumed = true
		reason = why or reason
		if coroutine.status(currentThread) == "suspended" then
			task.spawn(currentThread, tier)
		end
	end

	cancelSelf = function()
		finish(nil)
	end
	self._pendingCancels[player] = cancelSelf
	self._pendingFinish[player] = finish

	-- Timeout fallback: no tap in time is Good with no tip; skipping the meter never
	-- costs the drink its grade (AUDIT-FIX D2.1, DEC-058).
	local timeoutSeconds = window.Duration + config.LATENCY_ALLOWANCE_SECONDS
	timeoutTask = task.delay(timeoutSeconds, function()
		finish("Good", "Expired")
	end)

	-- Un-equip, death (character removed) or a swapped tool cancels the pour.
	unequipConn = initialTool.AncestryChanged:Connect(function()
		local character = player.Character
		if character == nil or initialTool.Parent ~= character or not initialTool:IsDescendantOf(game) then
			finish(nil)
		end
	end)

	-- Walking away (or losing the root part) cancels the pour.
	local stationPart = model and model.PrimaryPart
	if stationPart then
		walkCheckTask = task.spawn(function()
			while not cleaned do
				task.wait(0.2)
				if cleaned then
					return
				end
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				if not hrp or not hrp:IsA("BasePart") then
					finish(nil)
					return
				end
				if (hrp.Position - stationPart.Position).Magnitude > KitchenConfig.MAX_INTERACTION_DISTANCE then
					finish(nil)
					return
				end
			end
		end)
	end

	local tier: PourMeter.PourTier? = coroutine.yield()
	cleanup()
	resumed = true
	if self._pendingFinish[player] == finish then
		self._pendingFinish[player] = nil
	end

	if not tier then
		return nil
	end

	-- A perfect adds to the drink's tip count; nothing else touches the drink.
	local tool = getHeldTool(player)
	if tool then
		if tier == "Perfect" then
			local current = tool:GetAttribute(PERFECT_ATTRIBUTE)
			tool:SetAttribute(PERFECT_ATTRIBUTE, PourMeter.AddPerfect(current, config.MAX_PERFECT_PER_DRINK))
		end
		local liquid = tool:FindFirstChild("Liquid")
		if liquid and liquid:IsA("BasePart") then
			liquid.Transparency = 0
		end
	end

	-- The reason ("Ok", "Miss", "Expired", "Early") lets the client say "Messy pour"
	-- for a missed tip without the drink being graded down.
	self._service.Client.PourResolved:Fire(player, windowId, tier, reason)
	return tier
end

-- Grades one tap against the player's open window and resumes the awaiting thread.
function PourMoments:ReportTap(player: Player, windowId: any, claimedElapsed: any): PourMeter.PourTier?
	local window = self._windows[player]
	if window == nil or window.Id ~= windowId then
		return nil
	end
	local config = pourConfig()
	local tier, reason = PourMeter.Resolve(window, claimedElapsed, os.clock(), config.LATENCY_ALLOWANCE_SECONDS)
	local finish = self._pendingFinish[player]
	if finish then
		finish(tier, reason)
	end
	return tier
end

-- The flat BobaBuck tip for a set of served tools' PerfectPours attributes.
function PourMoments:TipForTools(tools: { Instance }): number
	local config = pourConfig()
	local counts = {}
	for _, tool in tools do
		table.insert(counts, tool:GetAttribute(PERFECT_ATTRIBUTE))
	end
	return PourMeter.TipFor(counts, config.TIP_PER_PERFECT, config.MAX_PERFECT_PER_DRINK)
end

-- Backward-compatibility stub for one-phase callers.
function PourMoments:MaybeOpen(_player: Player, _recipeData: RecipeData)
	-- Redesign: pour moments are awaited inline via AwaitPour.
end

return PourMoments

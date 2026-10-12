--[[
    Module: OnboardingService
    Description: Authority for role state, progression gates and the worker onboarding.

    There are two roles — Customer and Worker — and Barista is a promotion within Worker.
    Group membership is not required for either; rank 7+ is a bypass that skips onboarding
    entirely so existing staff are never asked to re-learn the game.

    The server owns every decision here. The client asks what it may do and renders
    accordingly, but OrderService and KitchenService call the predicates on this service
    rather than trusting anything the client sends.

    All the rule arithmetic lives in Shared.Utility.OnboardingUtil so it can be tested
    without a Roblox runtime (tools/verify-onboarding.luau).
--]]

---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Config = Shared:WaitForChild("Configuration")

local Knit = require(Packages.Knit)
local Promise = require(Packages.Promise)
local RankUtil = require(Shared.Utility.RankUtil)
local OnboardingUtil = require(Shared.Utility.OnboardingUtil)
local OnboardingConfig = require(Config.OnboardingConfig)

---> module declaration
local OnboardingService = Knit.CreateService({
	Name = "OnboardingService",
	Client = {
		-- Fired whenever a player's role, gate progress or objective step changes.
		-- Carries the same shape Client:GetState returns.
		StateChanged = Knit.CreateSignal(),
	},
})

---> constants

local RULES: OnboardingUtil.GateRules = {
	BaristaPlaytimeRequirement = OnboardingConfig.BARISTA_PLAYTIME_REQUIREMENT,
	RankBypass = OnboardingConfig.RANK_BYPASS,
}

---> state

type Session = {
	Proxy: any,
	Rank: number,
	-- How many worker onboarding steps are done. Session-only: onboarding either
	-- completes in one sitting or restarts, which is simpler than persisting a partial
	-- index and far shorter than the time it takes to abandon a session.
	StepIndex: number,
	-- Set while the worker onboarding is actually running, so step reports from a player
	-- who has already finished are ignored cheaply.
	Running: boolean,
	-- Guards the one-shot "you can train now" announcement and its funnel step.
	TrainingOffered: boolean,
	-- The NPC customer reserved for this player's onboarding, so the "take an order" step
	-- always has someone to take an order from.
	Customer: any,
}

--- How often the Barista playtime gate is re-checked. The gate opens on wall-clock time
--- with nothing to trigger off, so it needs a poll; 15s is well inside the tolerance of a
--- ten-minute threshold and costs one table walk.
local GATE_POLL_SECONDS = 15

--- How long Client:GetState waits for a profile that has not finished loading.
local SESSION_WAIT_TIMEOUT = 20

local sessions: { [number]: Session } = {}

---> private

--- Reads the persisted onboarding block, tolerating a profile written before this system
--- existed (V4Migration does not create it).
local function readState(session: Session): OnboardingUtil.OnboardingState
	local stored = session.Proxy.Data.Onboarding or {}

	return {
		WorkerOnboarded = stored.WorkerOnboarded == true,
		BaristaUnlocked = stored.BaristaUnlocked == true,
		ActiveRole = stored.ActiveRole or OnboardingConfig.DEFAULT_ROLE,
	}
end

--- Lifetime playtime including the live session — see OnboardingUtil for why the banked
--- statistic alone is not enough.
local function lifetimePlaytime(session: Session): number
	local data = session.Proxy.Data

	return OnboardingUtil.getLifetimePlaytime(
		data.Statistics.TimePlayed or 0,
		data.Playtime.MostRecentJoin or 0,
		os.time()
	)
end

--- Objective line for the "take an order" step, naming the customer and what they asked
--- for. The NPC says it aloud in a chat bubble, but a bubble that scrolled past leaves the
--- player stuck with no way to ask again — so it is also written where it persists.
local function describeCustomerObjective(customer): string?
	if not customer or not customer.Active then
		return nil
	end

	local name = customer.DisplayName or "Your customer"

	if not customer.Order or #customer.Order == 0 then
		return `{name} is on their way over`
	end

	local names = {}
	for _, item in customer.Order do
		local itemName = if typeof(item) == "table" then (item.ItemName or item.Name) else tostring(item)
		if itemName then
			table.insert(names, itemName)
		end
	end

	if #names == 0 then
		return `Take {name}'s order`
	end

	return `{name} wants: {table.concat(names, ", ")}`
end

--- Onboarding funnel steps fire once per user and need no session id. They are recorded
--- only in published games, and the call throws in some contexts, so it is guarded — a
--- missing analytics event must never break a player's onboarding.
local function logFunnelStep(player: Player, stepName: string)
	local stepNumber = OnboardingConfig.FUNNEL_STEPS[stepName]
	if not stepNumber then
		warn(`[OnboardingService] Unknown funnel step '{stepName}'.`)
		return
	end

	task.spawn(function()
		local ok, err = pcall(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, stepNumber, stepName)
		end)

		if not ok then
			warn(`[OnboardingService] Funnel step '{stepName}' failed: {err}`)
		end
	end)
end

--- The role choice is the single most valuable number this system produces, so it also
--- goes through a standard funnel: role selection recurs every session, which the
--- once-per-user onboarding funnel cannot express.
local function logRoleChoice(player: Player, role: string)
	task.spawn(function()
		pcall(function()
			AnalyticsService:LogFunnelStepEvent(
				player,
				OnboardingConfig.ROLE_FUNNEL_NAME,
				`{player.UserId}-{os.time()}`,
				1,
				role
			)
		end)
	end)
end

---> public

--- Everything the client needs to render the role screen and the objective card. Safe to
--- hand to the client wholesale: it contains no other player's data.
function OnboardingService:GetState(player: Player)
	local session = sessions[player.UserId]
	if not session then
		return nil
	end

	local state = readState(session)
	local playtime = lifetimePlaytime(session)
	local canTrain, trainReason = OnboardingUtil.canTrainBarista(state, playtime, RULES)

	return {
		ActiveRole = state.ActiveRole,
		WorkerOnboarded = state.WorkerOnboarded,
		BaristaUnlocked = state.BaristaUnlocked,
		HasRankBypass = OnboardingUtil.hasRankBypass(session.Rank, RULES),
		ShowRoleSelect = OnboardingUtil.shouldShowRoleSelect(session.Rank, RULES),
		CanTrainBarista = canTrain,
		-- The gate states its own unlock condition; no dead controls.
		BaristaLockReason = trainReason,
		BaristaProgress = OnboardingUtil.getBaristaProgress(playtime, RULES),
		OnboardingRunning = session.Running,
		StepIndex = session.StepIndex,
		-- Overrides the current step's configured world anchor when set. The customer to
		-- serve is spawned at runtime, so it cannot be named in config. Instances
		-- replicate over remotes, so the client can beacon straight at it.
		ObjectiveTarget = session.Customer and session.Customer.Character or nil,
		-- Overrides the step's static objective line when there is a specific customer to
		-- name. nil falls back to OnboardingConfig.
		ObjectiveText = describeCustomerObjective(session.Customer),
	}
end

local function publish(player: Player)
	local state = OnboardingService:GetState(player)
	if state then
		OnboardingService.Client.StateChanged:Fire(player, state)
	end
end

--- May the player take orders — staff screens, the ordering system, the barista queue?
function OnboardingService:CanTakeOrders(player: Player): boolean
	local session = sessions[player.UserId]
	if not session then
		-- Profile not loaded yet. Fall back to rank so existing staff are never locked
		-- out by a slow load; everyone else simply waits a moment.
		return RankUtil:CanUseOrderingSystem(player)
	end

	return OnboardingUtil.canTakeOrders(readState(session), session.Rank, RULES)
end

--- May the player make drinks? Requires the Barista promotion.
function OnboardingService:CanUseKitchen(player: Player): boolean
	local session = sessions[player.UserId]
	if not session then
		return RankUtil:CanEnterKitchen(player)
	end

	return OnboardingUtil.canUseKitchen(readState(session), session.Rank, RULES)
end

--- Why a staff action was refused, phrased as the thing the player should do next.
--- Call sites surface this themselves — OrderService through its Announcement signal,
--- KitchenService through DialogService — so nothing fails silently.
function OnboardingService:GetDenialReason(player: Player, action: "TakeOrders" | "UseKitchen"): string
	local session = sessions[player.UserId]
	if not session then
		return "Still loading your data — try again in a moment."
	end

	return OnboardingUtil.explainDenial(action, readState(session), lifetimePlaytime(session), RULES)
end

--- Sets the active role for this session. Choosing Worker for the first time starts the
--- onboarding, which is also the tutorial.
function OnboardingService:SelectRole(player: Player, role: string)
	local session = sessions[player.UserId]
	if not session then
		return false
	end

	if not table.find(OnboardingConfig.ROLES, role) then
		warn(`[OnboardingService] {player.Name} requested unknown role '{tostring(role)}'.`)
		return false
	end

	session.Proxy:SetValue({ "Onboarding", "ActiveRole" }, role)
	-- Exposed as an attribute so client code and world systems can branch on the role
	-- without a round-trip.
	player:SetAttribute("ActiveRole", role)

	logFunnelStep(player, "RoleChosen")
	logRoleChoice(player, role)

	if role == "Worker" and not readState(session).WorkerOnboarded then
		self:StartWorkerOnboarding(player)
	else
		publish(player)
	end

	return true
end

--- Begins the objective-driven worker onboarding. Idempotent.
function OnboardingService:StartWorkerOnboarding(player: Player)
	local session = sessions[player.UserId]
	if not session or session.Running or readState(session).WorkerOnboarded then
		return
	end

	session.Running = true
	session.StepIndex = 0

	logFunnelStep(player, "WorkerOnboardingStarted")
	publish(player)
end

--[=[
	Makes sure a customer is waiting for this player to serve.

	A new Worker arriving at the register and finding nobody there is the failure this
	exists to prevent — there may be no other players, and NPC customers otherwise place
	their own orders on the board rather than waiting to be served.

	Idempotent: it reuses the reserved customer if one is still around.
]=]
function OnboardingService:_ensureCustomer(player: Player)
	local session = sessions[player.UserId]
	if not session or not session.Running then
		return
	end

	if session.Customer and session.Customer.Active then
		-- Already waiting — remind them what they wanted, in case the player missed it.
		session.Customer:RepeatOrder()
		return
	end

	local ok, customerService = pcall(function()
		return Knit.GetService("CustomerService")
	end)

	if not ok or not customerService then
		warn("[OnboardingService] CustomerService unavailable; onboarding has no customer to serve.")
		return
	end

	-- Guarded: this runs from the gate poll, and an error escaping here would kill that
	-- loop for every player on the server, not just this one.
	local spawned, customer = pcall(function()
		return customerService:SpawnOnboardingCustomer(player)
	end)

	if not spawned or not customer then
		warn(`[OnboardingService] Could not spawn an onboarding customer: {tostring(customer)}`)
		return
	end

	session.Customer = customer

	-- The customer walks to a register before ordering, so the beacon target only becomes
	-- meaningful once they are there; publish again when the character is ready.
	publish(player)
end

--- Re-publishes state to one player. CustomerService calls this once the reserved customer
--- has decided what they want, so the objective can name it.
function OnboardingService:RefreshObjective(player: Player)
	publish(player)
end

--- Releases the reserved customer once they are no longer needed.
function OnboardingService:_releaseCustomer(session: Session)
	local customer = session.Customer
	session.Customer = nil

	if customer and customer.Active then
		-- Clear the reservation first, or the patience sweep will keep skipping them and
		-- they will stand at the register forever.
		customer.ReservedFor = nil
	end
end

--- Advances the onboarding when the player *does the thing*. `tracker` names the event,
--- matching a step's `Tracker` in OnboardingConfig; a report for any step other than the
--- current one is ignored, so out-of-order actions cannot skip ahead.
function OnboardingService:ReportStep(player: Player, tracker: string)
	local session = sessions[player.UserId]
	if not session or not session.Running then
		return
	end

	local step = OnboardingUtil.getCurrentStep(OnboardingConfig.WORKER_STEPS, session.StepIndex)
	if not step or step.Tracker ~= tracker then
		return
	end

	session.StepIndex += 1

	if step.Id == "TakeOrder" then
		logFunnelStep(player, "FirstOrderTaken")
		self:_releaseCustomer(session)
	end

	if session.StepIndex >= #OnboardingConfig.WORKER_STEPS then
		self:_completeWorkerOnboarding(player, session)
		return
	end

	publish(player)

	-- Reaching the register is what summons the customer to serve: spawning them earlier
	-- would have them waiting while the player is still walking over, and the "someone is
	-- here for you" moment is the point.
	local next = OnboardingUtil.getCurrentStep(OnboardingConfig.WORKER_STEPS, session.StepIndex)
	if next and next.Id == "TakeOrder" then
		task.spawn(function()
			self:_ensureCustomer(player)
		end)
	end
end

function OnboardingService:_completeWorkerOnboarding(player: Player, session: Session)
	session.Running = false
	self:_releaseCustomer(session)
	session.Proxy:SetValue({ "Onboarding", "WorkerOnboarded" }, true)

	logFunnelStep(player, "WorkerOnboardingCompleted")

	-- An immediate win matters more than its size.
	Knit.GetService("CurrencyService"):Modify(player, "BobaBucks", OnboardingConfig.COMPLETION_REWARD)

	Knit.GetService("DialogService"):Notify(player, {
		Title = "Shift complete!",
		Description = `You earned {OnboardingConfig.COMPLETION_REWARD} Boba Bucks. Keep serving to become a Barista.`,
		Image = "",
	})

	publish(player)

	-- The nickname prompt is deliberately last: it is the one blocking modal in the flow
	-- and must never stand between joining and playing.
	Knit.GetService("DataService"):PromptNickname(player)
end

--- Barista training. Stubbed behind its real interface: the gate, the unlock and the
--- analytics are live, so the flow is testable before lessons exist.
function OnboardingService:StartTraining(player: Player, kind: string)
	return Promise.new(function(resolve)
		local session = sessions[player.UserId]
		if not session or kind ~= "Barista" then
			resolve(false)
			return
		end

		local canTrain, reason = OnboardingUtil.canTrainBarista(readState(session), lifetimePlaytime(session), RULES)
		if not canTrain then
			Knit.GetService("DialogService"):Notify(player, {
				Title = "Not yet",
				Description = reason or "You can't train for that yet.",
				Image = "",
			})
			resolve(false)
			return
		end

		session.Proxy:SetValue({ "Onboarding", "BaristaUnlocked" }, true)
		logFunnelStep(player, "BaristaUnlocked")

		Knit.GetService("DialogService"):Notify(player, {
			Title = "You're a Barista!",
			Description = "You can now use the kitchen to make drinks.",
			Image = "",
		})

		publish(player)
		resolve(true)
	end)
end

--- Records that an order this player took reached its customer. Not an onboarding funnel
--- step — see OnboardingConfig for why it cannot be one.
function OnboardingService:LogOrderServed(player: Player)
	task.spawn(function()
		pcall(function()
			AnalyticsService:LogFunnelStepEvent(
				player,
				OnboardingConfig.ORDER_SERVED_FUNNEL_NAME,
				`{player.UserId}-{os.time()}`,
				1,
				"OrderServed"
			)
		end)
	end)
end

---> client

--- The client asks for this the moment the UI mounts, which can beat the profile load. If
--- it simply returned nil the role screen would never appear for that player, so it waits
--- for the session instead — bounded, because a request that never returns is worse than
--- one that gives up.
function OnboardingService.Client:GetState(player: Player)
	local deadline = os.clock() + SESSION_WAIT_TIMEOUT

	while not sessions[player.UserId] and os.clock() < deadline do
		if not player.Parent then
			return nil
		end
		task.wait(0.1)
	end

	return self.Server:GetState(player)
end

function OnboardingService.Client:SelectRole(player: Player, role: string)
	return self.Server:SelectRole(player, role)
end

function OnboardingService.Client:StartTraining(player: Player, kind: string)
	return self.Server:StartTraining(player, kind)
end

--- The only step the client can report is the proximity one; the order steps are reported
--- by OrderService from the server, where they actually happen.
function OnboardingService.Client:ReportProximity(player: Player)
	self.Server:ReportStep(player, "ApproachedRegister")
end

---> lifecycle

function OnboardingService:PlayerAdded(player: Player)
	local ok, proxy = Knit.GetService("DataService"):GetDataAsync(player):await()
	if not ok or not proxy or not player.Parent then
		return
	end

	-- Older profiles predate this block; fill it in rather than special-casing every read.
	if typeof(proxy.Data.Onboarding) ~= "table" then
		proxy:SetValue({ "Onboarding" }, {
			WorkerOnboarded = false,
			BaristaUnlocked = false,
			ActiveRole = OnboardingConfig.DEFAULT_ROLE,
		})
	end

	sessions[player.UserId] = {
		Proxy = proxy,
		Rank = RankUtil:GetRankAsync(player),
		StepIndex = 0,
		Running = false,
		TrainingOffered = false,
	}

	logFunnelStep(player, "Joined")

	local session = sessions[player.UserId]
	player:SetAttribute("ActiveRole", readState(session).ActiveRole)

	-- Staff skip the role screen, so nothing else asks them for a nickname; prompt them
	-- here instead. Everyone else is prompted after onboarding.
	if OnboardingUtil.hasRankBypass(session.Rank, RULES) then
		Knit.GetService("DataService"):PromptNickname(player)
	end

	publish(player)
end

function OnboardingService:PlayerRemoving(player: Player)
	local session = sessions[player.UserId]
	if session then
		-- Otherwise their reserved customer stands at the register forever, immune to the
		-- patience sweep, blocking a spawn slot for everyone else.
		self:_releaseCustomer(session)
	end

	sessions[player.UserId] = nil
end

--- The Barista gate opens on wall-clock time, so nothing else would ever announce it.
--- Poll for the crossing and tell the player the moment it happens — an unlock the player
--- has to go looking for is an unlock most players never find.
function OnboardingService:KnitStart()
	task.spawn(function()
		while task.wait(GATE_POLL_SECONDS) do
			for userId, session in sessions do
				local player = Players:GetPlayerByUserId(userId)
				if not player then
					continue
				end

				-- Safety net: if the reserved customer went away (a failed path, a stuck
				-- rig), the onboarding would sit on "take an order" with nobody to take
				-- one from. _ensureCustomer no-ops while one is still active.
				if session.Running then
					local step = OnboardingUtil.getCurrentStep(OnboardingConfig.WORKER_STEPS, session.StepIndex)
					if step and step.Id == "TakeOrder" and not (session.Customer and session.Customer.Active) then
						self:_ensureCustomer(player)
					end
				end

				if session.TrainingOffered then
					continue
				end

				local canTrain = OnboardingUtil.canTrainBarista(readState(session), lifetimePlaytime(session), RULES)
				if not canTrain then
					continue
				end

				session.TrainingOffered = true
				logFunnelStep(player, "BaristaTrainingAvailable")

				Knit.GetService("DialogService"):Notify(player, {
					Title = "Barista training unlocked!",
					Description = "You've worked long enough to learn drink-making. Open the Menu to train.",
					Image = "",
				})

				publish(player)
			end
		end
	end)
end

return OnboardingService

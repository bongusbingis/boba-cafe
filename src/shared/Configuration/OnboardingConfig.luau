--[[
    Module: OnboardingConfig
    Description: Role progression, gate thresholds, worker onboarding steps and analytics
    funnel names.

    There are two roles — Customer and Worker. Barista is a promotion within Worker, not a
    third role. Group membership is deliberately NOT required for either: rank is a bypass
    that skips onboarding, never a requirement to play.

    Onboarding steps are declared as data. Each step names a world target and the tracker
    that advances it; nothing here calls a service, so this stays safe to replicate.
--]]

local OnboardingConfig = {}

---> roles

OnboardingConfig.ROLES = { "Customer", "Worker" }
OnboardingConfig.DEFAULT_ROLE = "Customer"

---> gates

--- Lifetime playtime, in seconds, before the Barista promotion can be trained.
--- Wall-clock and idle-inclusive, per the design ruling.
OnboardingConfig.BARISTA_PLAYTIME_REQUIREMENT = 600

--- Group rank that bypasses onboarding entirely. Matches RankUtil.CanUseOrderingSystem,
--- so existing staff are never asked to re-learn the game.
OnboardingConfig.RANK_BYPASS = 7

---> worker onboarding

--- Steps run in order. `Tracker` is the event OnboardingService listens for; `Target`
--- names the world anchor the beacon attaches to, resolved under workspace at runtime.
---
--- Objective text is deliberately short and imperative — the research is explicit that
--- walls of text fail for players still learning to read.
---
--- Every step is completable by a Worker *alone*. Claiming and preparing an order is
--- Barista work and needs the kitchen, so it cannot appear here: a new Worker who claimed
--- an order would be stranded with no way to make the drink.
OnboardingConfig.WORKER_STEPS = {
	-- Both steps point at the registers ("Computers"), not at "Staff Screens": the screens
	-- are the barista claim board, while the registers are where a Worker actually takes a
	-- customer's order. TopBar attaches the register prompts.
	{
		Id = "GoToRegister",
		Objective = "Go to a register",
		Tracker = "ApproachedRegister",
		Target = { "Ordering System", "Computers" },
	},
	-- A customer is spawned and reserved for this step, so it can never stall waiting for
	-- someone to walk in. The beacon retargets onto that customer, which is why this step
	-- carries no fixed Target — see OnboardingService's ObjectiveTarget.
	{
		Id = "TakeOrder",
		Objective = "Take your customer's order",
		Tracker = "OrderTaken",
		Target = { "Ordering System", "Computers" },
	},
}

--- Boba Bucks granted on finishing the worker onboarding. Small but immediate — an early
--- win matters more than its size.
OnboardingConfig.COMPLETION_REWARD = 100

---> analytics

--- Steps for AnalyticsService:LogOnboardingFunnelStepEvent. These fire once per user, so
--- they use the onboarding funnel (no session id needed).
---
--- Order matters: skipping a step auto-completes the earlier ones, so every step here must
--- be strictly monotonic in time. That is why "an order this worker took was collected by
--- the customer" is NOT a step — it depends on a Barista being online and would usually
--- land after WorkerOnboardingCompleted, silently auto-completing itself and destroying
--- the signal. It is logged through ORDER_SERVED_FUNNEL_NAME instead.
OnboardingConfig.FUNNEL_STEPS = {
	Joined = 1,
	RoleChosen = 2,
	WorkerOnboardingStarted = 3,
	FirstOrderTaken = 4,
	WorkerOnboardingCompleted = 5,
	-- The playtime gate being reached, logged whether or not they then train. The gap
	-- between this and BaristaUnlocked is the drop-off the 10-minute gate costs.
	BaristaTrainingAvailable = 6,
	BaristaUnlocked = 7,
}

--- Repeatable role selection uses a standard funnel, since it recurs every session.
OnboardingConfig.ROLE_FUNNEL_NAME = "RoleSelection"

--- Whether an order a Worker took ever reached its customer. A standard funnel because it
--- recurs and because it is not monotonic against onboarding. This is the direct measure
--- of the design's biggest risk: a Worker taking orders no Barista is around to make.
OnboardingConfig.ORDER_SERVED_FUNNEL_NAME = "OrderFulfilment"

return OnboardingConfig

--[[
    Module: OnboardingUtil
    Description: Pure role/gate logic for onboarding.

    No Roblox APIs and no state, so the rules that decide what a player may do — which is
    security-relevant — can be tested directly rather than only in Studio.

    The central rule: permission is "the active role allows it, OR group rank grants it".
    Rank is a bypass for existing staff, never a requirement, because the group
    requirement was dropped.
--]]

local OnboardingUtil = {}

export type OnboardingState = {
	WorkerOnboarded: boolean,
	BaristaUnlocked: boolean,
	ActiveRole: string,
}

export type GateRules = {
	BaristaPlaytimeRequirement: number,
	RankBypass: number,
}

--- Lifetime playtime in seconds: banked time from previous sessions plus the live one.
--- `TimePlayed` alone excludes the current session and reads 0 for a first-time player who
--- has been on for twenty minutes, which would make the Barista gate unreachable on a
--- first visit.
function OnboardingUtil.getLifetimePlaytime(timePlayed: number, mostRecentJoin: number, now: number): number
	local banked = math.max(0, timePlayed or 0)

	-- MostRecentJoin of 0 means no session is in progress (or it was never stamped).
	if not mostRecentJoin or mostRecentJoin <= 0 then
		return banked
	end

	return banked + math.max(0, now - mostRecentJoin)
end

--- Whether the player's group rank lets them skip onboarding entirely.
function OnboardingUtil.hasRankBypass(rank: number, rules: GateRules): boolean
	return (rank or 0) >= rules.RankBypass
end

--- Whether the role selection screen should be shown at all.
function OnboardingUtil.shouldShowRoleSelect(rank: number, rules: GateRules): boolean
	return not OnboardingUtil.hasRankBypass(rank, rules)
end

--- Barista is a promotion within Worker: it needs the worker onboarding done and the
--- playtime threshold met. Training itself is what flips BaristaUnlocked.
function OnboardingUtil.canTrainBarista(
	state: OnboardingState,
	lifetimePlaytime: number,
	rules: GateRules
): (boolean, string?)
	if state.BaristaUnlocked then
		return false, "Already unlocked."
	end

	if not state.WorkerOnboarded then
		return false, "Work a shift first."
	end

	local remaining = rules.BaristaPlaytimeRequirement - lifetimePlaytime
	if remaining > 0 then
		return false, `Play for {math.ceil(remaining / 60)} more minutes.`
	end

	return true, nil
end

--- Fraction of the Barista playtime requirement completed, for the progress bar. Clamped,
--- so a long-time player does not overflow the bar.
function OnboardingUtil.getBaristaProgress(lifetimePlaytime: number, rules: GateRules): number
	if rules.BaristaPlaytimeRequirement <= 0 then
		return 1
	end

	return math.clamp(lifetimePlaytime / rules.BaristaPlaytimeRequirement, 0, 1)
end

--- May the player take orders (use staff screens and the ordering system)?
--- True for any active Worker, and for ranked staff regardless of role.
function OnboardingUtil.canTakeOrders(state: OnboardingState, rank: number, rules: GateRules): boolean
	if OnboardingUtil.hasRankBypass(rank, rules) then
		return true
	end

	return state.ActiveRole == "Worker"
end

--- May the player use the kitchen (make drinks)? Requires the Barista promotion, which is
--- only meaningful while actually working.
function OnboardingUtil.canUseKitchen(state: OnboardingState, rank: number, rules: GateRules): boolean
	if OnboardingUtil.hasRankBypass(rank, rules) then
		return true
	end

	return state.ActiveRole == "Worker" and state.BaristaUnlocked == true
end

--- Human-readable reason a staff action was refused, plus what would unlock it. Used to
--- replace the silent `return`s in OrderService — a new player must never click something
--- and get nothing.
function OnboardingUtil.explainDenial(
	action: "TakeOrders" | "UseKitchen",
	state: OnboardingState,
	lifetimePlaytime: number,
	rules: GateRules
): string
	if state.ActiveRole ~= "Worker" then
		return "Switch to the Worker role to do that."
	end

	if action == "UseKitchen" and not state.BaristaUnlocked then
		local remaining = rules.BaristaPlaytimeRequirement - lifetimePlaytime
		if remaining > 0 then
			return `Become a Barista to make drinks — play {math.ceil(remaining / 60)} more minutes to train.`
		end
		return "Become a Barista to make drinks — you can train now!"
	end

	return "You can't do that right now."
end

--- Next incomplete onboarding step, or nil when finished.
function OnboardingUtil.getCurrentStep(steps: { any }, completedIndex: number)
	local nextIndex = (completedIndex or 0) + 1
	return steps[nextIndex], nextIndex
end

return OnboardingUtil

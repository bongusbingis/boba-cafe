--[[
    Module: SubscriptionsConfig
    Description: Timed subscriptions a player can hold.

    V3 mixed definitions and behaviour together, with Active/Expires callbacks living
    inside the config and calling services directly. Definitions are pure data here;
    SubscriptionService fires signals and other systems react.

    Kinds:
      "Duration" — Expire is extended from now, so buying twice stacks the time
      "Calendar" — Expire is extended from the current expiry if still active, so a
                   month means a calendar month rather than a rolling window
--]]

local SubscriptionsConfig = {}

--- Free trial length granted to Roblox Premium members, in seconds.
SubscriptionsConfig.PREMIUM_TRIAL_SECONDS = 86400 * 10

SubscriptionsConfig.Subscriptions = {
	Celebrity = {
		Kind = "Calendar",
		DisplayName = "Celebrity",
		--- Developer products that grant this subscription, mapped to seconds.
		Products = {
			[1128806440] = 86400 * 30, -- 1 Month
			[1143304035] = 86400 * 90, -- 3 Months
			[1143304104] = 86400 * 180, -- 6 Months
		},
		--- Roblox Premium members can claim a free trial once.
		PremiumTrial = true,
	},

	-- V3's "FunPass" and "IceSkates" subscriptions are deliberately absent: the Fun Pass
	-- is retired and ice skating was never ported.
}

--- Whether a subscription name is known.
function SubscriptionsConfig.exists(name: string): boolean
	return SubscriptionsConfig.Subscriptions[name] ~= nil
end

--- The subscription a developer product grants, if any.
--- Returns (subscriptionName, seconds).
function SubscriptionsConfig.getProductGrant(productId: number): (string?, number?)
	for name, definition in SubscriptionsConfig.Subscriptions do
		local seconds = definition.Products and definition.Products[productId]
		if seconds then
			return name, seconds
		end
	end

	return nil, nil
end

return SubscriptionsConfig

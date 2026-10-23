--!strict
--[[
	StarterBundleConfig
	One-time Starter Bundle tuning (SEASON-PASS, 2026-10-23).

	All values are PROPOSED (Jack) until Jack approves them.
	Pure data only: no Instances, no services.
]]

local StarterBundleConfig = {}

-- PROPOSED (Jack): ~99 R$ product.
StarterBundleConfig.BOBA_BUCKS = 300
StarterBundleConfig.CAPSULES = { "Regular Pet Capsule", "Nametag Capsule" } :: { string }

return StarterBundleConfig

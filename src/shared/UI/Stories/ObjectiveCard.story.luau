--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local ObjectiveCard = require(Shared.UI.Components.Core.Hud.ObjectiveCard)
local OnboardingConfig = require(Shared.Configuration.OnboardingConfig)

local c = React.createElement

-- Second step, first one done — a filled pip, the enlarged current pip, and the
-- server-supplied objective line, which is the longest text the card ever holds.
-- Drop InitialObjectiveText to see the static fallback from the config.
return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(ObjectiveCard, {
		InitialObjective = OnboardingConfig.WORKER_STEPS[2],
		InitialStepIndex = 1,
		InitialObjectiveText = "Aria wants: Boba, Strawberry Macaron",
	}))

	return function()
		root:unmount()
	end
end

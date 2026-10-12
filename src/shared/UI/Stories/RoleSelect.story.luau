--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local RoleSelect = require(Shared.UI.Pages.RoleSelect)

local c = React.createElement

-- A returning player part-way to the Barista gate: the case with the most on screen at
-- once (progress bar + lock reason). Swap BaristaProgress to 1 / CanTrainBarista to true
-- to check the Train button, and WorkerOnboarded to false for a first-time join.
return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c(RoleSelect, {
		InitialState = {
			ActiveRole = "Customer",
			WorkerOnboarded = true,
			BaristaUnlocked = false,
			HasRankBypass = false,
			ShowRoleSelect = true,
			CanTrainBarista = false,
			BaristaLockReason = "Play for 4 more minutes.",
			BaristaProgress = 0.6,
			OnboardingRunning = false,
			StepIndex = 0,
		},
	}))

	return function()
		root:unmount()
	end
end

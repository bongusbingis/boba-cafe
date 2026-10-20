--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local DailyRewardsBody = require(UI.Components.Dialogs.DailyRewardsBody)

local c = React.createElement

-- Daily Rewards tab of the Menu. The body fetches its own status on mount.
return function()
	return c(DailyRewardsBody, {})
end

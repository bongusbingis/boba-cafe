--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)
local DailyRewardConfig = require(Shared.Configuration.DailyRewardConfig)

---> components
local DailyRewardsDialog = require(Shared.UI.Components.Dialogs.DailyRewardsDialog)

---> private
local c = React.createElement

local STATUS = {
	CanClaim = true,
	DayToClaim = 3,
	CurrentStreak = 2,
	SecondsUntilNextClaim = 0,
	Expired = false,
	IsVIP = false,
	DataLoaded = true,
	Reward = DailyRewardConfig.REWARDS[3],
}

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.7, 0.7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, {
		DailyRewards = c(DailyRewardsDialog, {
			Status = STATUS,
		}),
	}))

	return function()
		root:unmount()
	end
end

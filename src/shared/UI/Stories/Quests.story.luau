--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local QuestCard = require(Shared.UI.Components.Core.Hud.QuestCard)

---> private
local c = React.createElement

local QUESTS = {
	{
		Id = "story_1",
		Type = "BobaOrdered",
		Target = 5,
		Progress = 3,
		Completed = false,
		Claimed = false,
		RewardBobaBucks = 40,
		RewardXP = 25,
	},
	{
		Id = "story_2",
		Type = "CustomersServed",
		Target = 10,
		Progress = 10,
		Completed = true,
		Claimed = false,
		RewardBobaBucks = 40,
		RewardXP = 25,
	},
	{
		Id = "story_3",
		Type = "SpillsCleaned",
		Target = 4,
		Progress = 4,
		Completed = true,
		Claimed = true,
		RewardBobaBucks = 40,
		RewardXP = 25,
	},
}

return function(target)
	local root = ReactRoblox.createRoot(target)

	root:render(c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.7, 0.7),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	}, {
		QuestCard = c(QuestCard, {
			Quests = QUESTS,
			OnClose = function() end,
		}),
	}))

	return function()
		root:unmount()
	end
end

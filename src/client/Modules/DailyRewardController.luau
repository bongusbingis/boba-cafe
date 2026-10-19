--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

local DailyRewardController = Knit.CreateController({
	Name = "DailyRewardController",
})

local isDialogOpen = false

function DailyRewardController:OpenDailyRewards(initialStatus: { [string]: any }?)
	if isDialogOpen then
		return
	end
	isDialogOpen = true

	local dialogController = Knit.GetController("DialogController")
	local dialog = dialogController.new("DailyRewardsDialog", {
		Status = initialStatus,
	})

	dialog:Fire():finally(function()
		isDialogOpen = false
	end)
end

function DailyRewardController:KnitInit() end

function DailyRewardController:KnitStart()
	task.spawn(function()
		local dailyRewardService = Knit.GetService("DailyRewardService")
		-- Poll up to 5 times for player data to replicate/load
		for _ = 1, 5 do
			local ok, status = dailyRewardService:GetRewardStatus():await()
			if ok and status then
				if status.DataLoaded then
					if status.CanClaim == true then
						self:OpenDailyRewards(status)
					end
					break
				end
			end
			task.wait(1)
		end
	end)
end

return DailyRewardController

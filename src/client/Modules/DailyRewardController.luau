--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local SmallNotification = require(ReplicatedStorage:WaitForChild("Shared").UI.Components.Core.Hud.SmallNotification)

local DAILY_DRAIN_SECONDS, DAILY_WAIT_MAX_SECONDS = 1, 60

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

-- The Daily dialog waits for the first serve (new profiles) and for the toast panel to go idle,
-- so it never covers the first-order toast.
local function openWhenFirstServed(self, status)
	Knit.GetController("DataController"):GetDataAsync():andThen(function(playerData)
		local opened = false
		local function tryOpen(served)
			if opened or typeof(served) ~= "number" or served <= 0 then
				return
			end
			opened = true
			task.spawn(function()
				task.wait(DAILY_DRAIN_SECONDS)
				local waited = 0
				while SmallNotification.IdleFor() < DAILY_DRAIN_SECONDS and waited < DAILY_WAIT_MAX_SECONDS do
					task.wait(0.5)
					waited += 0.5
				end
				self:OpenDailyRewards(status)
			end)
		end
		local stats = playerData.Statistics
		tryOpen(if stats then stats.CustomersServed else nil)
		playerData:ListenToChange({ "Statistics", "CustomersServed" }, tryOpen)
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
						openWhenFirstServed(self, status)
					end
					break
				end
			end
			task.wait(1)
		end
	end)
end

return DailyRewardController

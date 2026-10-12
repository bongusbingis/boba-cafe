---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

---> module declaration
local ActivityController = Knit.CreateController({
	Name = "ActivityController",
})

---> private
local LocalPlayer = Players.LocalPlayer

---> lifecycle

function ActivityController:KnitStart()
	-- Player.Idled only fires in a LocalScript, so the client is the only place that
	-- can observe it; ActivityService clamps whatever we report.
	LocalPlayer.Idled:Connect(function(idleTime: number)
		Knit.GetService("ActivityService"):ReportIdle(idleTime)
	end)
end

return ActivityController

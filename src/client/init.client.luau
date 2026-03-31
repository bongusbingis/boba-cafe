local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local Controllers = Knit.AddControllersDeep(script.Modules)

Knit.Start()
	:andThen(function()
		print("[Client] Knit started successfully.")

		local playerAddedProcesses = {}
		local playerRemovingProcesses = {}

		for _, controller in Knit.Controllers do
			if typeof(controller.PlayerAdded) == "function" then
				table.insert(playerAddedProcesses, function(player)
					controller:PlayerAdded(player)
				end)
			end
			if typeof(controller.PlayerRemoving) == "function" then
				table.insert(playerRemovingProcesses, function(player)
					controller:PlayerRemoving(player)
				end)
			end
		end

		for _, player in Players:GetPlayers() do
			for _, fn in playerAddedProcesses do
				task.spawn(fn, player)
			end
		end

		Players.PlayerAdded:Connect(function(player)
			for _, fn in playerAddedProcesses do
				task.spawn(fn, player)
			end
		end)

		Players.PlayerRemoving:Connect(function(player)
			for _, fn in playerRemovingProcesses do
				task.spawn(fn, player)
			end
		end)
	end)
	:catch(warn)

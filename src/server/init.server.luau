local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local Services = Knit.AddServicesDeep(script.Modules)

Knit.Start()
	:andThen(function()
		print(Knit)
		print("[Server] Knit started successfully.")

		local playerAddedProcesses = {}
		local playerRemovingProcesses = {}

		for _, service in Services do
			if typeof(service.PlayerAdded) == "function" then
				table.insert(playerAddedProcesses, function(player)
					service:PlayerAdded(player)
				end)
			end
			if typeof(service.PlayerRemoving) == "function" then
				table.insert(playerRemovingProcesses, function(player)
					service:PlayerRemoving(player)
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

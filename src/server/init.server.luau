local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

-- Set to true to automatically grant every item to yourself when testing in
-- Studio. Has no effect on live servers regardless of this value.
local STUDIO_GRANT_ALL_ITEMS = true

local Knit = require(Packages.Knit)
local Services = Knit.AddServicesDeep(script.Modules)

Knit.Start()
	:andThen(function()
		print("[Server] Knit started successfully.")

		local playerAddedProcesses = {}
		local playerRemovingProcesses = {}

		for _, service in Services do
			if typeof(service) ~= "table" then
				continue
			end

			if typeof(service.PlayerAdded) == "function" then
				table.insert(playerAddedProcesses, function(player)
					service:PlayerAdded(player)
				end)
			end
			if typeof(service.PlayerRemoving) == "function" then
				table.insert(playerRemovingProcesses, {
					Name = service.Name,
					Run = function(player)
						service:PlayerRemoving(player)
					end,
				})
			end
		end

		table.insert(playerAddedProcesses, function(player)
			local rankUtil = require(ReplicatedStorage.Shared.Utility.RankUtil)
			if rankUtil:GetRankAsync(player) < 11 then
				player:Kick("This server is restricted to staff members only.")
			end
		end)

		if RunService:IsStudio() and STUDIO_GRANT_ALL_ITEMS then
			local InventoryItemDefinitions =
				require(ReplicatedStorage.Shared.Configuration.InventoryItemDefinitions)
			local Inventory = require(ReplicatedStorage.Shared.Inventory)
			local ITEM_TYPES = { "Nametags", "Pets", "Capsules", "Particles" }

			table.insert(playerAddedProcesses, function(player)
				task.delay(3, function()
					for _, itemType in ITEM_TYPES do
						local definitions = InventoryItemDefinitions[itemType]
						if not definitions then
							continue
						end
						Inventory:GetPlayerInventoryAsync(player, itemType)
							:andThen(function(inv)
								for itemName, itemDef in definitions do
									inv:Insert({ Name = itemName, Tier = itemDef.Tier })
								end
							end)
							:catch(warn)
					end
				end)
			end)
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
			-- Run non-DataService removal hooks first so they can still access profile data.
			for _, process in playerRemovingProcesses do
				if process.Name ~= "DataService" then
					local ok, err = pcall(process.Run, player)
					if not ok then
						warn("[Server] PlayerRemoving hook failed for", process.Name, err)
					end
				end
			end

			-- End profile session last.
			for _, process in playerRemovingProcesses do
				if process.Name == "DataService" then
					local ok, err = pcall(process.Run, player)
					if not ok then
						warn("[Server] PlayerRemoving hook failed for", process.Name, err)
					end
				end
			end
		end)
	end)
	:catch(warn)

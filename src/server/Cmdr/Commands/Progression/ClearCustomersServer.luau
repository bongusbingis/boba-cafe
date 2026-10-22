--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Knit = require(ReplicatedStorage:WaitForChild("Packages").Knit)

return function(_context: any): string
	pcall(function()
		local CustomerService = Knit.GetService("CustomerService")
		if CustomerService then
			if CustomerService.GetWaitingCustomers then
				local waiting = CustomerService:GetWaitingCustomers()
				for _, npc in waiting do
					pcall(function()
						if npc.Destroy then
							npc:Destroy()
						elseif npc.Leave then
							npc:Leave("Dismissed")
						end
					end)
				end
			end

			local activeNpcs = (CustomerService :: any)._npcs
			if activeNpcs then
				for npc in activeNpcs do
					pcall(function()
						if npc.Destroy then
							npc:Destroy()
						elseif npc.Leave then
							npc:Leave("Dismissed")
						end
					end)
				end
			end
		end

		local customersFolder = Workspace:FindFirstChild("Customers")
		if customersFolder then
			for _, child in customersFolder:GetChildren() do
				if child:IsA("Model") then
					child:Destroy()
				end
			end
		end

		local assets = Workspace:FindFirstChild("Assets")
		if assets then
			local npcFolder = assets:FindFirstChild("NPC")
			if npcFolder then
				for _, child in npcFolder:GetChildren() do
					if child:IsA("Model") then
						child:Destroy()
					end
				end
			end
		end
	end)

	return "Dismissed all customers."
end

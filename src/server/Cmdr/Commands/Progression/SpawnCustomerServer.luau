--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)

return function(_context: any, variant: string?): string
	local CustomerService = Knit.GetService("CustomerService")
	local cs = CustomerService :: any

	local ok, err = pcall(function()
		local actualVariant: any = nil
		if variant == "VIP" or variant == "Karen" then
			actualVariant = variant
		end

		local context = cs._context
		if actualVariant ~= nil and context ~= nil then
			local server = ServerScriptService:WaitForChild("Server")
			local modules = server:WaitForChild("Modules")
			local customerModule = modules:WaitForChild("CustomerService")
			local Rules = require(customerModule:WaitForChild("Rules") :: ModuleScript) :: any
			local Npc = require(customerModule:WaitForChild("Npc") :: ModuleScript) :: any
			local OrderSpec = require(Shared:WaitForChild("Ordering"):WaitForChild("OrderSpec") :: ModuleScript) :: any

			local order = Rules.PickOrder()
			local spec, _ = OrderSpec.FromOrderItem(order)
			if spec ~= nil then
				local regular = if cs._regulars then cs:_regulars("RollSpawn", true) else nil
				local look = if regular ~= nil then regular.Look else nil
				local npc = Npc.new(context, order, spec, Rules.PatienceSeconds({ order }), actualVariant, look)
				if npc ~= nil then
					if regular ~= nil and cs._regulars then
						cs:_regulars("Attach", npc, regular)
					end
					cs._npcs[npc] = true
					cs._npcCount = (cs._npcCount or 0) + 1
					if cs._pickRegisterSpot then
						local spot = cs:_pickRegisterSpot()
						cs._npcRegister[npc] = spot
						if cs._registerLines[spot] == nil then
							cs._registerLines[spot] = {}
						end
						table.insert(cs._registerLines[spot], npc)
					end
					table.insert(cs._line, npc)
					npc:Start()
					return
				end
			end
		end

		if cs._spawnIfNeeded then
			cs:_spawnIfNeeded()
		end
	end)

	if not ok then
		warn(string.format("[Cmdr] SpawnCustomer failed: %s", tostring(err)))
		return "Failed to spawn customer: " .. tostring(err)
	end

	return "Customer spawned!"
end

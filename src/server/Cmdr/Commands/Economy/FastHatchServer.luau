--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(_context: any, targets: { Player })
	local CapsuleService = Knit.GetService("CapsuleService")
	local DataService = Knit.GetService("DataService")

	for _, target in targets do
		pcall(function()
			DataService:GetDataAsync(target):andThen(function(proxy: any)
				local data = (proxy.Data ~= nil and proxy.Data) or proxy
				if data.CapsuleHatch then
					proxy:SetValue({ "CapsuleHatch", "HatchReadyTime" }, os.time() - 10)
					CapsuleService:TryCompleteReadyHatch(target)
				end
				if data.HatchingPet then
					proxy:SetValue({ "HatchingPet", "TimeAccumulated" }, 100000)
					CapsuleService:TryCompleteReadyHatch(target)
				end
			end)
		end)
	end

	return "Incubating capsules readied and hatched!"
end

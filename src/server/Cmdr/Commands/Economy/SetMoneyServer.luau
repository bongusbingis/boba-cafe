--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(_context: any, targets: { Player }, amount: number)
	local DataService = Knit.GetService("DataService")
	for _, target in targets do
		pcall(function()
			DataService:GetDataAsync(target):andThen(function(proxy: any)
				proxy:SetValue({ "Currency", "BobaBucks" }, amount)
			end)
		end)
	end

	return string.format("Set BobaBucks to %d for %d player(s).", amount, #targets)
end

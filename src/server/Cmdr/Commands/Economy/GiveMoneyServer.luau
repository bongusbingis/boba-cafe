--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

return function(_context: any, targets: { Player }, amount: number)
	local CurrencyService = Knit.GetService("CurrencyService")
	for _, target in targets do
		pcall(function()
			CurrencyService:Modify(target, "BobaBucks", amount, "CmdrGrant")
		end)
	end

	return string.format("Granted %d BobaBucks to %d player(s).", amount, #targets)
end

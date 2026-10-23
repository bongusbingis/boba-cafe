--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

return function(_context: any, targets: { Player })
	local ModerationService = Knit.GetService("ModerationService")
	for _, target in targets do
		ModerationService:SetFlight(target, false)
	end

	return string.format("Disabled flight for %d player(s).", #targets)
end

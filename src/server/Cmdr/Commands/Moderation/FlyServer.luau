--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

return function(_context: any, targets: { Player })
	local ModerationService = Knit.GetService("ModerationService")
	for _, target in targets do
		ModerationService:SetFlight(target, true)
	end

	return string.format("Enabled flight for %d player(s).", #targets)
end

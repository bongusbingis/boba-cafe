--!strict
return function(_context: any, targets: { Player })
	for _, target in targets do
		local char = target.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Sit = true
			end
		end
	end

	return string.format("Made %d player(s) sit.", #targets)
end

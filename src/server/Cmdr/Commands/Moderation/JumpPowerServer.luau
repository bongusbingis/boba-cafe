--!strict
return function(_context: any, targets: { Player }, power: number)
	local clampedPower = math.clamp(power, 0, 1000)
	for _, target in targets do
		local char = target.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				if hum.UseJumpPower then
					hum.JumpPower = clampedPower
				else
					hum.JumpHeight = clampedPower
				end
			end
		end
	end

	return string.format("Set jump power of %d player(s) to %d.", #targets, clampedPower)
end

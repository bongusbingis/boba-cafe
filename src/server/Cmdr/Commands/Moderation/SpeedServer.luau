--!strict
return function(_context: any, targets: { Player }, speed: number)
	local clampedSpeed = math.clamp(speed, 0, 500)
	for _, target in targets do
		local char = target.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = clampedSpeed
			end
		end
	end

	return string.format("Set walkspeed of %d player(s) to %d.", #targets, clampedSpeed)
end

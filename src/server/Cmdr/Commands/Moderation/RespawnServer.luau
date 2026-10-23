--!strict
return function(_context: any, targets: { Player })
	for _, target in targets do
		pcall(function()
			target:LoadCharacter()
		end)
	end

	return string.format("Respawned %d player(s).", #targets)
end

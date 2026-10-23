return {
	Name = "view",
	Aliases = { "watch", "spectate" },
	Description = "Spectates a player's character camera.",
	Group = "Moderation",
	Args = {
		{
			Type = "player",
			Name = "target",
			Description = "The player to spectate",
		},
	},
	ClientRun = function(_context: any, target: Player)
		local char = target.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local camera = workspace.CurrentCamera
			if hum and camera then
				camera.CameraSubject = hum
				return string.format("Now viewing %s (@%s).", target.DisplayName, target.Name)
			end
		end
		return string.format("Could not view %s (character not loaded).", target.Name)
	end,
}

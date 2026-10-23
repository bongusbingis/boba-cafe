local Players = game:GetService("Players")

return {
	Name = "unview",
	Aliases = { "unspectate" },
	Description = "Resets your camera view back to your character.",
	Group = "Moderation",
	Args = {},
	ClientRun = function(_context: any)
		local localPlayer = Players.LocalPlayer
		local char = localPlayer.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			local camera = workspace.CurrentCamera
			if hum and camera then
				camera.CameraSubject = hum
				return "Camera view reset."
			end
		end
		return "Camera view reset."
	end,
}

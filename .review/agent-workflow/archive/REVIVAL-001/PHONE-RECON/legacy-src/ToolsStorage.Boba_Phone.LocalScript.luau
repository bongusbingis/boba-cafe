local Tool = script.Parent
local UI = game.Players.LocalPlayer.PlayerGui:WaitForChild("BobaPhone")

Tool.Equipped:Connect(function()
	if Tool.Parent:FindFirstChild("Humanoid") then
		local char = Tool.Parent
		local player = game.Players:GetPlayerFromCharacter(char)
		if player then
			UI.Enabled = true
		end
	end
end)

Tool.Unequipped:Connect(function()
	UI.Enabled = false
end)

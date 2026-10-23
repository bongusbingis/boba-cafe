--!strict
return function(_context: any, targets: { Player })
	for _, target in targets do
		task.spawn(function()
			local char = target.Character
			local root = if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
			local prevCFrame = if root then root.CFrame else nil

			target:LoadCharacter()

			if prevCFrame then
				local newChar = target.CharacterAdded:Wait()
				local newRoot = newChar:WaitForChild("HumanoidRootPart", 5) :: BasePart?
				if newRoot then
					newRoot.CFrame = prevCFrame
				end
			end
		end)
	end

	return string.format("Refreshed %d player(s).", #targets)
end

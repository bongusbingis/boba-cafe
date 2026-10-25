local screenGui = script.Parent
local userInputService = game:GetService("UserInputService")

if userInputService.TouchEnabled then
	if screenGui.AbsoluteSize.Y < 500 then
		screenGui.Frame.Position = UDim2.new(1,-50,1,-5)
		screenGui.Frame.Size = UDim2.new(0.5,0,1,26)
		screenGui.Frame.AnchorPoint = Vector2.new(1,1)
	end
end

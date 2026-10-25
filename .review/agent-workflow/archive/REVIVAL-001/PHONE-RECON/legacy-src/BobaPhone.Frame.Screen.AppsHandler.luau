local TweenService = game:GetService("TweenService")

local HomeFrame = script.Parent.Home
local AppsButtons = HomeFrame.Applications
local Apps = script.Parent.Apps

local CurrentApplication = nil

for _,button in pairs(AppsButtons:GetChildren()) do
	local application = Apps:FindFirstChild(button.Name)
	if application then
		if button:IsA("ImageButton") then
			button.MouseButton1Click:Connect(function()
				if not CurrentApplication then
					CurrentApplication = application

					for _,s in pairs(CurrentApplication:GetDescendants()) do
						if s:IsA("BoolValue") and s.Name == "DisableScript" and s.Value then
							s.Parent.Disabled = false
						end
					end

					Apps.Size = UDim2.new(1,0,0,0)
					Apps.Position = UDim2.new(0.5,0,1,0)
					CurrentApplication.Visible = true
					TweenService:Create(Apps,TweenInfo.new(0.3),{Size = UDim2.new(1,0,1,0),Position = UDim2.new(0.5,0,0,0)}):Play()
					wait(0.3)
				end
			end)
		end
	end
end

Apps.CloseApps.MouseButton1Click:Connect(function()
	if CurrentApplication then
		local oldApp = CurrentApplication
		CurrentApplication = nil

		TweenService:Create(Apps,TweenInfo.new(0.3),{Size = UDim2.new(1,0,0,0)}):Play()
		wait(0.3)
		for _,s in pairs(oldApp:GetDescendants()) do
			if s:IsA("BoolValue") and s.Name == "DisableScript" and s.Value then
				s.Parent.Disabled = true
			end
		end
		oldApp.Visible = false
	end
end)

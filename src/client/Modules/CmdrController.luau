--!strict
--[[
	CmdrController.luau
	Knit controller managing the Cmdr developer / admin console (client side).
	Binds activation keys (F2 and Backquote/Tilde ~), configures the client console,
	and provides an on-screen toggle button for authorized mobile moderators.
]]

---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local RankUtil = require(Shared.Utility.RankUtil)
local Styles = require(Shared.UI.Styles)

---> controller declaration
local CmdrController = Knit.CreateController({
	Name = "CmdrController",
})

---> private helpers
local function setupMobileToggleButton(cmdrInstance: any)
	local localPlayer = Players.LocalPlayer
	local playerGui = localPlayer:WaitForChild("PlayerGui")

	if playerGui:FindFirstChild("CmdrMobileGui") then
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CmdrMobileGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 95
	screenGui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "CmdrMobileContainer"
	container.Size = UDim2.fromOffset(118, 32)
	container.Position = UDim2.new(1, -128, 0, 54)
	container.BackgroundTransparency = 1
	container.Active = true
	container.Parent = screenGui

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = container

	local cmdrBtn = Instance.new("TextButton")
	cmdrBtn.Name = "CmdrToggleButton"
	cmdrBtn.Size = UDim2.fromOffset(56, 32)
	cmdrBtn.BackgroundColor3 = Styles.GREEN_MID
	cmdrBtn.Text = "Cmdr"
	cmdrBtn.TextColor3 = Styles.OFFWHITE
	cmdrBtn.FontFace = Styles.FONT_FREDOKA
	cmdrBtn.TextSize = 14
	cmdrBtn.AutoButtonColor = true
	cmdrBtn.Active = true
	cmdrBtn.Parent = container

	local corner1 = Instance.new("UICorner")
	corner1.CornerRadius = UDim.new(0, 8)
	corner1.Parent = cmdrBtn

	local stroke1 = Instance.new("UIStroke")
	stroke1.Color = Styles.GREEN_DEEP
	stroke1.Thickness = 2
	stroke1.Parent = cmdrBtn

	local logsBtn = Instance.new("TextButton")
	logsBtn.Name = "LogsToggleButton"
	logsBtn.Size = UDim2.fromOffset(56, 32)
	logsBtn.BackgroundColor3 = Styles.GREEN_MID
	logsBtn.Text = "Logs"
	logsBtn.TextColor3 = Styles.OFFWHITE
	logsBtn.FontFace = Styles.FONT_FREDOKA
	logsBtn.TextSize = 14
	logsBtn.AutoButtonColor = true
	logsBtn.Active = true
	logsBtn.Parent = container

	local corner2 = Instance.new("UICorner")
	corner2.CornerRadius = UDim.new(0, 8)
	corner2.Parent = logsBtn

	local stroke2 = Instance.new("UIStroke")
	stroke2.Color = Styles.GREEN_DEEP
	stroke2.Thickness = 2
	stroke2.Parent = logsBtn

	-- Dragging support on container so mobile users can reposition anywhere
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart: Vector3? = nil
	local startPos: UDim2? = nil

	local function hookDrag(targetButton: GuiButton)
		targetButton.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				dragging = true
				dragStart = input.Position
				startPos = container.Position

				local connection: any
				connection = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						if connection then
							connection:Disconnect()
							connection = nil
						end
					end
				end)
			end
		end)

		targetButton.InputChanged:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseMovement
			then
				dragInput = input
			end
		end)
	end

	hookDrag(cmdrBtn)
	hookDrag(logsBtn)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging and dragStart and startPos then
			local delta = input.Position - dragStart
			container.Position =
				UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	cmdrBtn.Activated:Connect(function()
		cmdrInstance:Toggle()
	end)

	logsBtn.Activated:Connect(function()
		local ok, logViewer = pcall(function()
			return Knit.GetController("LogViewerController")
		end)
		if ok and logViewer then
			logViewer:Toggle()
		end
	end)
end

---> lifecycle
function CmdrController:KnitStart()
	-- Wait for CmdrClient to be replicated by the server
	local cmdrClient = ReplicatedStorage:WaitForChild("CmdrClient", 15)
	if not cmdrClient then
		warn("[CmdrController] Timed out waiting for CmdrClient in ReplicatedStorage.")
		return
	end

	local Cmdr = require(cmdrClient)
	-- Key binds: Backquote/Tilde (Quote) and F2
	Cmdr:SetActivationKeys({ Enum.KeyCode.Quote, Enum.KeyCode.F2 })
	Cmdr:SetPlaceName("Boba Cafe Dev Console")

	local localPlayer = Players.LocalPlayer
	task.spawn(function()
		local isAllowed = false

		if RunService:IsStudio() then
			isAllowed = true
		else
			local ok, rank = pcall(function()
				return RankUtil:GetRankAsync(localPlayer)
			end)
			if (ok and rank >= 11) or localPlayer:GetAttribute("IsAdmin") == true then
				isAllowed = true
			end
		end

		if not isAllowed then
			Cmdr:SetEnabled(false)
		else
			-- If user is on a touch device (or testing in Studio), show on-screen toggle button
			if UserInputService.TouchEnabled or RunService:IsStudio() then
				setupMobileToggleButton(Cmdr)
			end
		end
	end)
end

return CmdrController

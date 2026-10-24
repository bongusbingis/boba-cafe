--!strict
--[[
    Module: RestockPromptController
    Description: Knit client controller that renders custom ProximityPrompt UI for restockable
                 kitchen stations and displays live stock status with Rainbow/percentage bars (legacy port).
--]]

---> Services

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

---> Constants

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local TWEEN_FAST = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_QUICK = TweenInfo.new(0.06, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local TWEEN_INSTANT = TweenInfo.new(0, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

local COLOR_EMPTY = Color3.fromRGB(253, 102, 102)
local COLOR_FULL = Color3.fromRGB(151, 190, 135)
local COLOR_BG_DARK = Color3.fromRGB(18, 18, 18)

local RAINBOW_COLOR_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.new(1, 0.4, 0.4)),
	ColorSequenceKeypoint.new(0.30, Color3.new(1, 0.4, 0.4)),
	ColorSequenceKeypoint.new(0.301, Color3.new(1, 1, 0.4)),
	ColorSequenceKeypoint.new(0.43, Color3.new(0.4, 1, 0.4)),
	ColorSequenceKeypoint.new(0.55, Color3.new(0.4, 1, 1)),
	ColorSequenceKeypoint.new(0.70, Color3.new(0.4, 0.4, 1)),
	ColorSequenceKeypoint.new(0.87, Color3.new(1, 0.4, 1)),
	ColorSequenceKeypoint.new(1.00, Color3.new(1, 0.4, 1)),
})

local GAMEPAD_BUTTON_IMAGES: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.ButtonX] = "rbxasset://textures/ui/Controls/xboxX.png",
	[Enum.KeyCode.ButtonY] = "rbxasset://textures/ui/Controls/xboxY.png",
	[Enum.KeyCode.ButtonA] = "rbxasset://textures/ui/Controls/xboxA.png",
	[Enum.KeyCode.ButtonB] = "rbxasset://textures/ui/Controls/xboxB.png",
	[Enum.KeyCode.DPadLeft] = "rbxasset://textures/ui/Controls/dpadLeft.png",
	[Enum.KeyCode.DPadRight] = "rbxasset://textures/ui/Controls/dpadRight.png",
	[Enum.KeyCode.DPadUp] = "rbxasset://textures/ui/Controls/dpadUp.png",
	[Enum.KeyCode.DPadDown] = "rbxasset://textures/ui/Controls/dpadDown.png",
	[Enum.KeyCode.ButtonSelect] = "rbxasset://textures/ui/Controls/xboxmenu.png",
	[Enum.KeyCode.ButtonL1] = "rbxasset://textures/ui/Controls/xboxLS.png",
	[Enum.KeyCode.ButtonR1] = "rbxasset://textures/ui/Controls/xboxRS.png",
}

local KEYBOARD_BUTTON_IMAGES: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.Backspace] = "rbxasset://textures/ui/Controls/backspace.png",
	[Enum.KeyCode.Return] = "rbxasset://textures/ui/Controls/return.png",
	[Enum.KeyCode.LeftShift] = "rbxasset://textures/ui/Controls/shift.png",
	[Enum.KeyCode.RightShift] = "rbxasset://textures/ui/Controls/shift.png",
	[Enum.KeyCode.Tab] = "rbxasset://textures/ui/Controls/tab.png",
}

local KEYBOARD_ICON_MAPPING: { [string]: string } = {
	["'"] = "rbxasset://textures/ui/Controls/apostrophe.png",
	[","] = "rbxasset://textures/ui/Controls/comma.png",
	["`"] = "rbxasset://textures/ui/Controls/graveaccent.png",
	["."] = "rbxasset://textures/ui/Controls/period.png",
	[" "] = "rbxasset://textures/ui/Controls/spacebar.png",
}

local KEY_CODE_TO_TEXT: { [Enum.KeyCode]: string } = {
	[Enum.KeyCode.LeftControl] = "Ctrl",
	[Enum.KeyCode.RightControl] = "Ctrl",
	[Enum.KeyCode.LeftAlt] = "Alt",
	[Enum.KeyCode.RightAlt] = "Alt",
	[Enum.KeyCode.F1] = "F1",
	[Enum.KeyCode.F2] = "F2",
	[Enum.KeyCode.F3] = "F3",
	[Enum.KeyCode.F4] = "F4",
	[Enum.KeyCode.F5] = "F5",
	[Enum.KeyCode.F6] = "F6",
	[Enum.KeyCode.F7] = "F7",
	[Enum.KeyCode.F8] = "F8",
	[Enum.KeyCode.F9] = "F9",
	[Enum.KeyCode.F10] = "F10",
	[Enum.KeyCode.F11] = "F11",
	[Enum.KeyCode.F12] = "F12",
}

---> Helpers

local function getScreenGui(): ScreenGui
	local screenGui = PlayerGui:FindFirstChild("ProximityPrompts") :: ScreenGui?
	if not screenGui then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "ProximityPrompts"
		screenGui.ResetOnSpawn = false
		screenGui.Parent = PlayerGui
	end
	return screenGui
end

local function createProgressBarGradient(parent: GuiObject, leftSide: boolean): UIGradient
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.5, 1)
	frame.Position = UDim2.fromScale(if leftSide then 0 else 0.5, 0)
	frame.BackgroundTransparency = 1
	frame.ClipsDescendants = true
	frame.Parent = parent

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(2, 1)
	image.Position = UDim2.fromScale(if leftSide then 0 else -1, 0)
	image.Image = "rbxasset://textures/ui/Controls/RadialFill.png"
	image.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4999, 0),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Rotation = if leftSide then 180 else 0
	gradient.Parent = image

	return gradient
end

local function createCircularProgressBar(): (Frame, NumberValue)
	local bar = Instance.new("Frame")
	bar.Name = "CircularProgressBar"
	bar.Size = UDim2.fromOffset(56, 56)
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5)
	bar.BackgroundTransparency = 1

	local gradLeft = createProgressBarGradient(bar, true)
	local gradRight = createProgressBarGradient(bar, false)

	local progress = Instance.new("NumberValue")
	progress.Name = "Progress"
	progress.Parent = bar
	progress.Changed:Connect(function(value: number)
		local angle = math.clamp(value * 360, 0, 360)
		gradLeft.Rotation = math.clamp(angle, 180, 360)
		gradRight.Rotation = math.clamp(angle, 0, 180)
	end)

	return bar, progress
end

local function hasUnlimitedStock(): boolean
	return LocalPlayer:GetAttribute("PerkUnlimitedStock") == true
end

---> Prompt Builder Function

local function createPrompt(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType, gui: ScreenGui): () -> ()
	local tweensForButtonHoldBegin: { Tween } = {}
	local tweensForButtonHoldEnd: { Tween } = {}
	local tweensForFadeOut: { Tween } = {}
	local tweensForFadeIn: { Tween } = {}

	local tweenInfoFull = TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

	local promptUI = Instance.new("BillboardGui")
	promptUI.Name = "RestockPrompt"
	promptUI.AlwaysOnTop = true

	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromScale(0.5, 1)
	mainFrame.BackgroundTransparency = 1
	mainFrame.BackgroundColor3 = COLOR_BG_DARK
	mainFrame.Parent = promptUI

	local cornerMain = Instance.new("UICorner")
	cornerMain.CornerRadius = UDim.new(0, 10)
	cornerMain.Parent = mainFrame

	local restockFrame = Instance.new("Frame")
	restockFrame.Name = "restockFrame"
	restockFrame.Size = UDim2.fromScale(1, 0.32)
	restockFrame.Position = UDim2.fromScale(0, -0.38)
	restockFrame.BackgroundTransparency = 1
	restockFrame.BackgroundColor3 = COLOR_BG_DARK
	restockFrame.Parent = promptUI

	local cornerRestock = Instance.new("UICorner")
	cornerRestock.CornerRadius = UDim.new(1, 0)
	cornerRestock.Parent = restockFrame

	local restockBar = Instance.new("Frame")
	restockBar.Name = "restockBar"
	restockBar.Size = UDim2.new(1, -6, 1, -6)
	restockBar.Position = UDim2.fromOffset(3, 3)
	restockBar.BackgroundColor3 = COLOR_BG_DARK
	restockBar.BackgroundTransparency = 1
	restockBar.Parent = restockFrame

	local cornerBar = Instance.new("UICorner")
	cornerBar.CornerRadius = UDim.new(1, 0)
	cornerBar.Parent = restockBar

	local restockBarFrame = Instance.new("Frame")
	restockBarFrame.Name = "restockBarFrame"
	restockBarFrame.Size = UDim2.fromScale(1, 1)
	restockBarFrame.BackgroundColor3 = COLOR_FULL
	restockBarFrame.BackgroundTransparency = 1
	restockBarFrame.Parent = restockBar

	local cornerFill = Instance.new("UICorner")
	cornerFill.CornerRadius = UDim.new(1, 0)
	cornerFill.Parent = restockBarFrame

	local rainbowGradient = Instance.new("UIGradient")
	rainbowGradient.Name = "Rainbow"
	rainbowGradient.Color = RAINBOW_COLOR_SEQUENCE
	rainbowGradient.Enabled = false
	rainbowGradient.Parent = restockBarFrame

	local restockBarText = Instance.new("TextLabel")
	restockBarText.Name = "restockBarText"
	restockBarText.Size = UDim2.fromScale(1, 1)
	restockBarText.Font = Enum.Font.FredokaOne
	restockBarText.TextSize = 14
	restockBarText.TextColor3 = Color3.new(1, 1, 1)
	restockBarText.TextStrokeColor3 = COLOR_BG_DARK
	restockBarText.TextStrokeTransparency = 1
	restockBarText.BackgroundTransparency = 1
	restockBarText.TextTransparency = 1
	restockBarText.TextXAlignment = Enum.TextXAlignment.Center
	restockBarText.ZIndex = 3
	restockBarText.Parent = restockBar

	local inputFrame = Instance.new("Frame")
	inputFrame.Name = "InputFrame"
	inputFrame.Size = UDim2.fromScale(1, 1)
	inputFrame.BackgroundTransparency = 1
	inputFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	inputFrame.Parent = mainFrame

	local resizeableInputFrame = Instance.new("Frame")
	resizeableInputFrame.Size = UDim2.fromScale(1, 1)
	resizeableInputFrame.Position = UDim2.fromScale(0.5, 0.5)
	resizeableInputFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	resizeableInputFrame.BackgroundTransparency = 1
	resizeableInputFrame.Parent = inputFrame

	local inputFrameScaler = Instance.new("UIScale")
	inputFrameScaler.Parent = resizeableInputFrame

	local scaleFactor = if inputType == Enum.ProximityPromptInputType.Touch then 1.6 else 1.33
	table.insert(tweensForButtonHoldBegin, TweenService:Create(inputFrameScaler, TWEEN_FAST, { Scale = scaleFactor }))
	table.insert(tweensForButtonHoldEnd, TweenService:Create(inputFrameScaler, TWEEN_FAST, { Scale = 1 }))

	local actionText = Instance.new("TextLabel")
	actionText.Name = "ActionText"
	actionText.Size = UDim2.fromScale(1, 1)
	actionText.Font = Enum.Font.GothamMedium
	actionText.TextSize = 19
	actionText.BackgroundTransparency = 1
	actionText.TextTransparency = 1
	actionText.TextColor3 = Color3.new(1, 1, 1)
	actionText.TextXAlignment = Enum.TextXAlignment.Left
	actionText.Parent = mainFrame

	local objectText = Instance.new("TextLabel")
	objectText.Name = "ObjectText"
	objectText.Size = UDim2.fromScale(1, 1)
	objectText.Font = Enum.Font.GothamMedium
	objectText.TextSize = 14
	objectText.BackgroundTransparency = 1
	objectText.TextTransparency = 1
	objectText.TextColor3 = Color3.fromRGB(180, 180, 180)
	objectText.TextXAlignment = Enum.TextXAlignment.Left
	objectText.Parent = mainFrame

	local roundFrame = Instance.new("Frame")
	roundFrame.Name = "RoundFrame"
	roundFrame.Size = UDim2.fromOffset(48, 48)
	roundFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	roundFrame.Position = UDim2.fromScale(0.5, 0.5)
	roundFrame.BackgroundTransparency = 1
	roundFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	roundFrame.Parent = resizeableInputFrame

	local cornerRound = Instance.new("UICorner")
	cornerRound.CornerRadius = UDim.new(0.5, 0)
	cornerRound.Parent = roundFrame

	table.insert(tweensForFadeOut, TweenService:Create(roundFrame, TWEEN_QUICK, { BackgroundTransparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(roundFrame, TWEEN_QUICK, { BackgroundTransparency = 0.5 }))

	-- Fade tweens
	table.insert(
		tweensForFadeOut,
		TweenService:Create(mainFrame, TWEEN_FAST, { Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1 })
	)
	table.insert(
		tweensForFadeIn,
		TweenService:Create(mainFrame, TWEEN_FAST, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.2 })
	)

	table.insert(tweensForFadeOut, TweenService:Create(restockFrame, TWEEN_FAST, { BackgroundTransparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(restockFrame, TWEEN_FAST, { BackgroundTransparency = 0.2 }))

	table.insert(tweensForFadeOut, TweenService:Create(restockBar, TWEEN_FAST, { BackgroundTransparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(restockBar, TWEEN_FAST, { BackgroundTransparency = 0 }))

	table.insert(tweensForFadeOut, TweenService:Create(restockBarFrame, TWEEN_FAST, { BackgroundTransparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(restockBarFrame, TWEEN_FAST, { BackgroundTransparency = 0 }))

	table.insert(
		tweensForFadeOut,
		TweenService:Create(restockBarText, TWEEN_FAST, { TextTransparency = 1, TextStrokeTransparency = 1 })
	)
	table.insert(
		tweensForFadeIn,
		TweenService:Create(restockBarText, TWEEN_FAST, { TextTransparency = 0, TextStrokeTransparency = 0 })
	)

	table.insert(tweensForFadeOut, TweenService:Create(actionText, TWEEN_FAST, { TextTransparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(actionText, TWEEN_FAST, { TextTransparency = 0 }))

	table.insert(tweensForFadeOut, TweenService:Create(objectText, TWEEN_FAST, { TextTransparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(objectText, TWEEN_FAST, { TextTransparency = 0 }))

	-- Input specific glyphs
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local icon = Instance.new("ImageLabel")
		icon.Name = "ButtonImage"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromScale(0.65, 0.65)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Image = GAMEPAD_BUTTON_IMAGES[prompt.GamepadKeyCode] or "rbxasset://textures/ui/Controls/xboxA.png"
		icon.Parent = resizeableInputFrame
		table.insert(tweensForFadeOut, TweenService:Create(icon, TWEEN_QUICK, { ImageTransparency = 1 }))
		table.insert(tweensForFadeIn, TweenService:Create(icon, TWEEN_QUICK, { ImageTransparency = 0 }))
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		local icon = Instance.new("ImageLabel")
		icon.Name = "ButtonImage"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromScale(0.65, 0.65)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Image = "rbxasset://textures/ui/Controls/TouchTapIcon.png"
		icon.Parent = resizeableInputFrame
		table.insert(tweensForFadeOut, TweenService:Create(icon, TWEEN_QUICK, { ImageTransparency = 1 }))
		table.insert(tweensForFadeIn, TweenService:Create(icon, TWEEN_QUICK, { ImageTransparency = 0 }))
	else
		local keyString = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
		local keyImage = KEYBOARD_BUTTON_IMAGES[prompt.KeyboardKeyCode]
		if not keyImage then
			keyImage = KEYBOARD_ICON_MAPPING[keyString]
		end

		if keyImage then
			local icon = Instance.new("ImageLabel")
			icon.Name = "ButtonImage"
			icon.BackgroundTransparency = 1
			icon.Size = UDim2.fromScale(0.65, 0.65)
			icon.Position = UDim2.fromScale(0.5, 0.5)
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Image = keyImage
			icon.Parent = resizeableInputFrame
			table.insert(tweensForFadeOut, TweenService:Create(icon, TWEEN_QUICK, { ImageTransparency = 1 }))
			table.insert(tweensForFadeIn, TweenService:Create(icon, TWEEN_QUICK, { ImageTransparency = 0 }))
		else
			local mapped = KEY_CODE_TO_TEXT[prompt.KeyboardKeyCode] or keyString
			local btnText = Instance.new("TextLabel")
			btnText.Name = "ButtonText"
			btnText.BackgroundTransparency = 1
			btnText.Size = UDim2.fromScale(1, 1)
			btnText.Font = Enum.Font.GothamBold
			btnText.TextSize = if #mapped > 2 then 14 else 18
			btnText.TextColor3 = Color3.new(1, 1, 1)
			btnText.Text = mapped
			btnText.Parent = resizeableInputFrame
			table.insert(tweensForFadeOut, TweenService:Create(btnText, TWEEN_QUICK, { TextTransparency = 1 }))
			table.insert(tweensForFadeIn, TweenService:Create(btnText, TWEEN_QUICK, { TextTransparency = 0 }))
		end
	end

	-- Touch & click support
	if inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt then
		local textButton = Instance.new("TextButton")
		textButton.Name = "PromptTouchButton"
		textButton.BackgroundTransparency = 1
		textButton.Text = ""
		textButton.Size = UDim2.fromScale(1, 1)
		textButton.Parent = promptUI

		local buttonDown = false
		textButton.InputBegan:Connect(function(input)
			if
				(
					input.UserInputType == Enum.UserInputType.Touch
					or input.UserInputType == Enum.UserInputType.MouseButton1
				) and input.UserInputState ~= Enum.UserInputState.Change
			then
				prompt:InputHoldBegin()
				buttonDown = true
			end
		end)

		textButton.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				if buttonDown then
					buttonDown = false
					prompt:InputHoldEnd()
				end
			end
		end)

		promptUI.Active = true
	end

	-- Hold progress bar
	local circleBar: Frame? = nil
	local progressVal: NumberValue? = nil
	if prompt.HoldDuration > 0 then
		circleBar, progressVal = createCircularProgressBar()
		circleBar.Parent = resizeableInputFrame
		table.insert(tweensForButtonHoldBegin, TweenService:Create(progressVal, tweenInfoFull, { Value = 1 }))
		table.insert(tweensForButtonHoldEnd, TweenService:Create(progressVal, TWEEN_INSTANT, { Value = 0 }))
	end

	local holdBeganConn: RBXScriptConnection? = nil
	local holdEndedConn: RBXScriptConnection? = nil
	if prompt.HoldDuration > 0 then
		holdBeganConn = prompt.PromptButtonHoldBegan:Connect(function()
			for _, tw in tweensForButtonHoldBegin do
				tw:Play()
			end
		end)
		holdEndedConn = prompt.PromptButtonHoldEnded:Connect(function()
			for _, tw in tweensForButtonHoldEnd do
				tw:Play()
			end
		end)
	end

	local triggeredConn = prompt.Triggered:Connect(function()
		for _, tw in tweensForFadeOut do
			tw:Play()
		end
	end)

	local triggerEndedConn = prompt.TriggerEnded:Connect(function()
		for _, tw in tweensForFadeIn do
			tw:Play()
		end
	end)

	-- Update UI from prompt state
	local function updateUIFromPrompt()
		local currentStock = prompt:GetAttribute("CurrentStock") :: number?
		local defaultStock = prompt:GetAttribute("DefaultStock") :: number?
		local isRestockingStation = (prompt:GetAttribute("Theme") == "Restock")
			or (currentStock ~= nil and defaultStock ~= nil)

		local isHoldingBox = LocalPlayer:GetAttribute("Restocking") == true
		local unlimited = hasUnlimitedStock()

		if isRestockingStation and currentStock ~= nil and defaultStock ~= nil then
			restockFrame.Visible = true

			if unlimited and prompt.Name ~= "SinkPrompt" then
				restockBarText.Text = "Unlimited"
				restockBarFrame.Size = UDim2.fromScale(1, 1)
				restockBarFrame.BackgroundColor3 = Color3.new(1, 1, 1)
				rainbowGradient.Enabled = true
				restockBar.BackgroundColor3 = COLOR_BG_DARK
			else
				rainbowGradient.Enabled = false
				local pct = math.clamp(currentStock / defaultStock, 0, 1)
				restockBarText.Text = string.format("%d/%d", currentStock, defaultStock)
				restockBarFrame.Size = UDim2.fromScale(pct, 1)
				restockBarFrame.BackgroundColor3 = COLOR_EMPTY:Lerp(COLOR_FULL, pct)

				if currentStock == 0 then
					restockBar.BackgroundColor3 = COLOR_EMPTY
				else
					restockBar.BackgroundColor3 = COLOR_BG_DARK
				end
			end
		else
			restockFrame.Visible = false
		end

		local displayActionText: string = prompt.ActionText
		if (currentStock ~= nil and currentStock == 0) or isHoldingBox then
			displayActionText = "Restock"
		end

		local actionTextSize =
			TextService:GetTextSize(displayActionText, 19, Enum.Font.GothamMedium, Vector2.new(1000, 1000))
		local objectTextSize =
			TextService:GetTextSize(prompt.ObjectText, 14, Enum.Font.GothamMedium, Vector2.new(1000, 1000))
		local maxTextWidth = math.max(actionTextSize.X, objectTextSize.X)

		local promptHeight = 72
		local promptWidth = 72
		local textPaddingLeft = 72

		if
			(prompt.ActionText ~= nil and prompt.ActionText ~= "")
			or (prompt.ObjectText ~= nil and prompt.ObjectText ~= "")
		then
			promptWidth = maxTextWidth + textPaddingLeft + 24
		end

		local actionTextYOffset = 0
		if prompt.ObjectText ~= nil and prompt.ObjectText ~= "" then
			actionTextYOffset = 9
		end

		actionText.Position = UDim2.new(0.5, textPaddingLeft - promptWidth / 2, 0, actionTextYOffset)
		objectText.Position = UDim2.new(0.5, textPaddingLeft - promptWidth / 2, 0, -10)

		actionText.Text = displayActionText
		objectText.Text = prompt.ObjectText

		promptUI.Size = UDim2.fromOffset(promptWidth, promptHeight)
		promptUI.SizeOffset =
			Vector2.new(prompt.UIOffset.X / promptUI.Size.Width.Offset, prompt.UIOffset.Y / promptUI.Size.Height.Offset)
	end

	local changedConn = prompt.Changed:Connect(updateUIFromPrompt)
	local attrConn = prompt.AttributeChanged:Connect(updateUIFromPrompt)
	local playerAttrConn = LocalPlayer:GetAttributeChangedSignal("Restocking"):Connect(updateUIFromPrompt)
	local perkAttrConn = LocalPlayer:GetAttributeChangedSignal("PerkUnlimitedStock"):Connect(updateUIFromPrompt)

	updateUIFromPrompt()

	promptUI.Adornee = prompt.Parent
	promptUI.Parent = gui

	for _, tw in tweensForFadeIn do
		tw:Play()
	end

	local function cleanup()
		if holdBeganConn then
			holdBeganConn:Disconnect()
		end
		if holdEndedConn then
			holdEndedConn:Disconnect()
		end
		triggeredConn:Disconnect()
		triggerEndedConn:Disconnect()
		changedConn:Disconnect()
		attrConn:Disconnect()
		playerAttrConn:Disconnect()
		perkAttrConn:Disconnect()

		for _, tw in tweensForFadeOut do
			tw:Play()
		end

		task.delay(0.2, function()
			promptUI:Destroy()
		end)
	end

	return cleanup
end

---> Controller Declaration

local RestockPromptController = Knit.CreateController({
	Name = "RestockPromptController",
})

function RestockPromptController:KnitStart()
	local kitchenService = Knit.GetService("KitchenService")
	if kitchenService and kitchenService.SetBackpackEnabled then
		kitchenService.SetBackpackEnabled:Connect(function(enabled: boolean)
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
			end)
		end)
	end

	ProximityPromptService.PromptShown:Connect(
		function(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
			if prompt.Style ~= Enum.ProximityPromptStyle.Custom and prompt:GetAttribute("Theme") ~= "Restock" then
				return
			end

			local gui = getScreenGui()
			local cleanupFunction = createPrompt(prompt, inputType, gui)

			prompt.PromptHidden:Wait()
			cleanupFunction()
		end
	)
end

return RestockPromptController

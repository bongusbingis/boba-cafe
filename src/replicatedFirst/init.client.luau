--[[
    Loading screen.

    Lives in ReplicatedFirst so it can cover the screen before the rest of the game
    replicates. Deliberately does NOT use React: the React packages live in
    ReplicatedStorage and may not have replicated yet when this runs, which is the whole
    reason ReplicatedFirst exists.

    Replaces V3's four duplicated loading screens; the seasonal differences come from
    Shared.Configuration.LoadingConfig.
--]]

---> services
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

---> config
-- Shared may not exist yet this early, so wait for it rather than indexing.
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LoadingConfig = require(Shared:WaitForChild("Configuration"):WaitForChild("LoadingConfig"))

---> constants
local FADE_TIME = 0.6

---> setup

ReplicatedFirst:RemoveDefaultLoadingScreen()

local variant = LoadingConfig.getVariant()
local startedAt = os.clock()

local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "LoadingScreen"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 1_000_000
screen.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.BackgroundColor3 = variant.Background
backdrop.BorderSizePixel = 0
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Parent = screen

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
title.Position = UDim2.fromScale(0.5, 0.38)
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Size = UDim2.fromScale(0.6, 0.14)
title.Text = variant.Title
title.TextColor3 = variant.Accent
title.TextScaled = true
title.Parent = backdrop

local fact = Instance.new("TextLabel")
fact.BackgroundTransparency = 1
fact.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
fact.Position = UDim2.fromScale(0.5, 0.56)
fact.AnchorPoint = Vector2.new(0.5, 0.5)
fact.Size = UDim2.fromScale(0.7, 0.07)
fact.Text = ""
fact.TextColor3 = variant.Accent
fact.TextScaled = true
fact.TextTransparency = 0.15
fact.TextWrapped = true
fact.Parent = backdrop

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
status.Position = UDim2.fromScale(0.5, 0.9)
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.Size = UDim2.fromScale(0.5, 0.05)
status.Text = "Loading..."
status.TextColor3 = variant.Accent
status.TextScaled = true
status.TextTransparency = 0.4
status.Parent = backdrop

---> rotating facts

local running = true

task.spawn(function()
	local facts = LoadingConfig.Facts
	if #facts == 0 then
		return
	end

	-- Start somewhere random so rejoining does not always show the same first fact.
	local index = math.random(1, #facts)

	while running do
		fact.Text = facts[index]
		index = (index % #facts) + 1
		task.wait(LoadingConfig.FACT_INTERVAL)
	end
end)

---> teardown

task.spawn(function()
	-- Preload what has replicated so the first frame is not a texture pop-in.
	pcall(function()
		ContentProvider:PreloadAsync({ backdrop })
	end)

	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	-- Hold briefly so the screen does not flash on a fast join.
	local elapsed = os.clock() - startedAt
	if elapsed < LoadingConfig.MIN_DISPLAY_TIME then
		task.wait(LoadingConfig.MIN_DISPLAY_TIME - elapsed)
	end

	running = false
	status.Text = "Ready!"

	local fadeInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(backdrop, fadeInfo, { BackgroundTransparency = 1 }):Play()

	for _, label in { title, fact, status } do
		TweenService:Create(label, fadeInfo, { TextTransparency = 1 }):Play()
	end

	task.wait(FADE_TIME)
	screen:Destroy()
end)

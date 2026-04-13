local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

local Nametags = require(Shared.Configuration.InventoryItemDefinitions.Nametags)

---> Per-player overhead handles
local cosmetics: { [number]: { Nickname: string, Nametag: string? } } = {}
local rerenders: { [number]: (nickname: string, nametag: string?) -> () } = {}
local guiHandles: { [number]: BillboardGui } = {}
local animationStops: { [number]: () -> () } = {}

local function destroyOverhead(userId: number)
	if animationStops[userId] then
		animationStops[userId]()
		animationStops[userId] = nil
	end
	if guiHandles[userId] then
		guiHandles[userId]:Destroy()
		guiHandles[userId] = nil
	end
	rerenders[userId] = nil
end

---> Starts the color animation on a TextLabel directly.
---> Returns a stop function that cancels any active tween and exits the loop.
local function startAnimation(label: TextLabel, animation: { Frames: { any } }?, staticColor: Color3): () -> ()
	local running = true
	local activeTween: Tween? = nil

	local function stop()
		running = false
		local tween = activeTween
		activeTween = nil
		if tween then
			tween:Cancel()
			tween:Destroy()
		end
	end

	if not animation or #animation.Frames < 2 then
		label.TextColor3 = staticColor
		label.TextTransparency = 0
		return stop
	end

	local frames = animation.Frames
	label.TextColor3 = frames[1].Color
	label.TextTransparency = frames[1].Transparency or 0

	task.spawn(function()
		local frameIndex = 1

		while running and label.Parent do
			local frame = frames[frameIndex]
			local nextIndex = (frameIndex % #frames) + 1
			local nextFrame = frames[nextIndex]

			if frame.Hold > 0 then
				task.wait(frame.Hold)
				if not running or not label.Parent then
					break
				end
			end

			if frame.Transition and frame.Transition > 0 then
				local goal: { [string]: any } = { TextColor3 = nextFrame.Color }
				if nextFrame.Transparency ~= nil then
					goal.TextTransparency = nextFrame.Transparency
				end

				local tween = TweenService:Create(
					label,
					TweenInfo.new(frame.Transition, Enum.EasingStyle.Linear),
					goal
				)
				activeTween = tween
				tween:Play()
				tween.Completed:Wait()
				tween:Destroy()
				activeTween = nil
			else
				label.TextColor3 = nextFrame.Color
				label.TextTransparency = nextFrame.Transparency or 0
			end

			frameIndex = nextIndex
		end
	end)

	return stop
end

local function buildOverhead(player: Player, character: Model)
	destroyOverhead(player.UserId)

	local head = character:WaitForChild("Head") :: BasePart

	local uiHandle = Instance.new("BillboardGui")
	uiHandle.Adornee = head
	uiHandle.Size = UDim2.fromScale(4, 2.5)
	uiHandle.SizeOffset = Vector2.new(0, 1.125)
	uiHandle.Parent = Players.LocalPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = uiHandle

	local usernameLabel = Instance.new("TextLabel")
	usernameLabel.BackgroundTransparency = 1
	usernameLabel.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	usernameLabel.Position = UDim2.fromScale(0, 0.725)
	usernameLabel.Size = UDim2.fromScale(1, 0.15)
	usernameLabel.Text = player.Name
	usernameLabel.TextColor3 = Color3.new(1, 1, 1)
	usernameLabel.TextScaled = true
	usernameLabel.Parent = frame

	local roleLabel = Instance.new("TextLabel")
	roleLabel.BackgroundTransparency = 1
	roleLabel.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic)
	roleLabel.Position = UDim2.fromScale(0, 0.85)
	roleLabel.Size = UDim2.fromScale(1, 0.15)
	roleLabel.Text = "Customer"
	roleLabel.TextColor3 = Color3.new(1, 1, 1)
	roleLabel.TextScaled = true
	roleLabel.Parent = frame

	---> Nickname label: TweenService owns its color exclusively
	local nicknameLabel = Instance.new("TextLabel")
	nicknameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nicknameLabel.BackgroundTransparency = 1
	nicknameLabel.FontFace = Font.new("rbxasset://fonts/families/DenkOne.json")
	nicknameLabel.Position = UDim2.fromScale(0.5, 0.45)
	nicknameLabel.Size = UDim2.fromScale(3, 0.3)
	nicknameLabel.TextScaled = true
	nicknameLabel.Parent = frame

	guiHandles[player.UserId] = uiHandle

	local currentStop: (() -> ())? = nil

	local function rerender(nickname: string, nametag: string?)
		local nametagDef = nametag and Nametags[nametag]
		local staticColor = (nametagDef and nametagDef.Color) or Color3.new(1, 1, 1)

		nicknameLabel.Text = nickname ~= "" and nickname or player.Name

		if currentStop then
			currentStop()
		end
		currentStop = startAnimation(nicknameLabel, nametagDef and nametagDef.Animation, staticColor)
	end

	animationStops[player.UserId] = function()
		if currentStop then
			currentStop()
			currentStop = nil
		end
	end

	rerenders[player.UserId] = rerender

	local cached = cosmetics[player.UserId]
	rerender(
		cached and cached.Nickname or "",
		cached and cached.Nametag
	)
end

local function playerAdded(player: Player)
	if player.Character then
		buildOverhead(player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		buildOverhead(player, character)
	end)
end

Knit.OnStart():andThen(function()
	local CosmeticsService = Knit.GetService("CosmeticsService")

	CosmeticsService:GetAllPlayerCosmeticsAsync():andThen(function(snapshot)
		cosmetics = snapshot

		for _, player in Players:GetPlayers() do
			playerAdded(player)
		end
		Players.PlayerAdded:Connect(playerAdded)
	end)

	CosmeticsService.CosmeticsChanged:Connect(function(userId: number, nickname: string, nametag: string?)
		cosmetics[userId] = { Nickname = nickname, Nametag = nametag }
		if rerenders[userId] then
			rerenders[userId](nickname, nametag)
		end
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		cosmetics[player.UserId] = nil
		destroyOverhead(player.UserId)
	end)
end)

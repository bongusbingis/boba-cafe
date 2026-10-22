local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

local RankUtil = require(Shared.Utility.RankUtil)
local Nametags = require(Shared.Configuration.InventoryItemDefinitions.Nametags)
local OverheadEmojis = require(Shared.Configuration.OverheadEmojis)
local PassCosmetics = require(Shared.Configuration.PassCosmetics)

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

				local tween = TweenService:Create(label, TweenInfo.new(frame.Transition, Enum.EasingStyle.Linear), goal)
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
	usernameLabel.FontFace =
		Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	usernameLabel.Position = UDim2.fromScale(0, 0.725)
	usernameLabel.Size = UDim2.fromScale(1, 0.15)
	usernameLabel.Text = player.Name
	usernameLabel.TextColor3 = Color3.new(1, 1, 1)
	usernameLabel.TextScaled = true
	usernameLabel.Parent = frame

	local roleLabel = Instance.new("TextLabel")
	roleLabel.BackgroundTransparency = 1
	roleLabel.FontFace =
		Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	roleLabel.Position = UDim2.fromScale(0, 0.85)
	roleLabel.Size = UDim2.fromScale(1, 0.15)
	roleLabel.TextColor3 = Color3.new(1, 1, 1)
	roleLabel.TextScaled = true
	roleLabel.RichText = true
	roleLabel.Parent = frame

	---> Level title line, under the name (copy of the role line style)
	-- local titleLabel = Instance.new("TextLabel")
	-- titleLabel.BackgroundTransparency = 1
	-- titleLabel.FontFace =
	-- 	Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic)
	-- titleLabel.Position = UDim2.fromScale(0, 1)
	-- titleLabel.Size = UDim2.fromScale(1, 0.15)
	-- titleLabel.TextColor3 = Color3.new(1, 1, 1)
	-- titleLabel.TextScaled = true
	-- titleLabel.Parent = frame

	local _rank = nil
	if RankUtil.IsMR(player) then
		_rank = RankUtil:GetRoleAsync(player)
		_rank = `<font color="rgb(250, 239, 37)">{_rank}</font>`
		-- local rankLabel = Instance.new("TextLabel")
		-- rankLabel.BackgroundTransparency = 1
		-- rankLabel.FontFace =
		-- 	Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic)
		-- rankLabel.Position = UDim2.fromScale(0, 0.975)
		-- rankLabel.Size = UDim2.fromScale(1, 0.15)
		-- rankLabel.TextColor3 = Color3.new(1, 1, 1)
		-- rankLabel.TextScaled = true
		-- rankLabel.Parent = frame
		-- rankLabel.Text = RankUtil:GetRoleAsync(player)
	end

	local function refreshTitle()
		--local isVeteran = player:GetAttribute("IsVeteran") == true
		-- The equipped title is the earned cosmetic the player chose; an empty
		-- string means explicitly unequipped. The level title is only a fallback
		-- until ProgressionService has loaded and set EquippedTitle.
		local rawEquippedTitle = player:GetAttribute("EquippedTitle")
		local rawLevelTitle = player:GetAttribute("LevelTitle")
		local levelTitle: string? = nil
		if typeof(rawEquippedTitle) == "string" then
			levelTitle = if rawEquippedTitle ~= "" then rawEquippedTitle else nil
		elseif typeof(rawLevelTitle) == "string" and rawLevelTitle ~= "" then
			levelTitle = rawLevelTitle
		end

		if _rank and levelTitle then
			roleLabel.Text = _rank .. " • " .. levelTitle
		elseif _rank then
			roleLabel.Text = _rank
		elseif levelTitle then
			roleLabel.Text = levelTitle
		else
			roleLabel.Text = ""
		end
		roleLabel.Visible = roleLabel.Text ~= ""
	end
	refreshTitle()
	local titleConn = player:GetAttributeChangedSignal("LevelTitle"):Connect(refreshTitle)
	local equippedConn = player:GetAttributeChangedSignal("EquippedTitle"):Connect(refreshTitle)
	local veteranConn = player:GetAttributeChangedSignal("IsVeteran"):Connect(refreshTitle)
	roleLabel.Destroying:Connect(function()
		titleConn:Disconnect()
		equippedConn:Disconnect()
		veteranConn:Disconnect()
	end)

	---> Emoji row label: sits above the nickname text, same Y size as usernameLabel
	local emojiLabel = Instance.new("TextLabel")
	emojiLabel.AnchorPoint = Vector2.new(0.5, 0)
	emojiLabel.BackgroundTransparency = 1
	emojiLabel.FontFace =
		Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	emojiLabel.Position = UDim2.fromScale(0.5, 0.30)
	emojiLabel.Size = UDim2.fromScale(1, 0.175)
	emojiLabel.TextColor3 = Color3.new(1, 1, 1)
	emojiLabel.TextScaled = true
	emojiLabel.Text = ""
	emojiLabel.Visible = false
	emojiLabel.Parent = frame

	local function refreshEmojis()
		task.spawn(function()
			local emojiString = OverheadEmojis.GetEmojiString(player)
			if emojiLabel.Parent then
				emojiLabel.Text = emojiString
				emojiLabel.Visible = emojiString ~= ""
			end
		end)
	end
	refreshEmojis()
	local emojiAttrConn = player.AttributeChanged:Connect(function()
		refreshEmojis()
	end)
	emojiLabel.Destroying:Connect(function()
		emojiAttrConn:Disconnect()
	end)

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
		local animation = nametagDef and nametagDef.Animation
		---> Rainbow Pack owners get the rainbow nametag unless they equipped another one
		if nametagDef == nil and player:GetAttribute(PassCosmetics.RAINBOW_ATTRIBUTE) == true then
			animation = PassCosmetics.RAINBOW_ANIMATION
		end

		nicknameLabel.Text = nickname ~= "" and nickname or player.Name

		if currentStop then
			currentStop()
		end
		currentStop = startAnimation(nicknameLabel, animation, staticColor)
	end

	animationStops[player.UserId] = function()
		if currentStop then
			currentStop()
			currentStop = nil
		end
	end

	rerenders[player.UserId] = rerender

	local cached = cosmetics[player.UserId]
	rerender(cached and cached.Nickname or "", cached and cached.Nametag)

	local rainbowConn = player:GetAttributeChangedSignal(PassCosmetics.RAINBOW_ATTRIBUTE):Connect(function()
		local current = cosmetics[player.UserId]
		rerender(current and current.Nickname or "", current and current.Nametag)
	end)
	nicknameLabel.Destroying:Connect(function()
		rainbowConn:Disconnect()
	end)
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

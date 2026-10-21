--!strict
--[[
	CafeUpgradeService/Builders.luau
	BIG-B2: code-built cafe upgrade models (no authored models exist). Simple parts only,
	every model tagged BuiltBy = CafeUpgradeConfig.BUILT_BY. Placement comes from
	CafeUpgradeConfig.PLACEMENT; Jack adjusts in Studio.
]]

---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

---> dependencies
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CafeUpgradeConfig = require(Shared.Configuration.CafeUpgradeConfig)
local Styles = require(Shared.UI.Styles)

---> constants
local BUILT_BY = CafeUpgradeConfig.BUILT_BY
local WOOD = Color3.fromRGB(120, 82, 52)
local WOOD_DARK = Color3.fromRGB(86, 58, 38)
local TERRACOTTA = Color3.fromRGB(196, 110, 72)
local SOIL = Color3.fromRGB(70, 48, 34)
local LEAF = Color3.fromRGB(88, 150, 76)
local LEAF_LIGHT = Color3.fromRGB(120, 178, 96)
local BULB_COLORS = { Color3.fromRGB(255, 226, 160), Styles.GOLD_MID, Styles.ROSE } :: { Color3 }
local CABLE = Color3.fromRGB(45, 45, 45)
local BULB_SPACING = 2
local LIGHT_EVERY = 4
local SAG = 1.2
local CYLINDER_UP = CFrame.Angles(0, 0, math.rad(90)) -- Roblox cylinders run along X

local Builders = {}

---> private
local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function model(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("BuiltBy", BUILT_BY)
	return m
end

local function add(parent: Instance, child: Instance): Instance
	child.Parent = parent
	return child
end

---> public

function Builders.Plant(cf: CFrame, index: number): Model
	local m = model(`Plant{index}`)
	local pot = part({
		Name = "Pot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 2.2, 2.2),
		Color = TERRACOTTA,
		CanCollide = true,
		CFrame = cf * CFrame.new(0, 1, 0) * CYLINDER_UP,
	})
	add(m, pot)
	add(
		m,
		part({
			Name = "Soil",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 2, 2),
			Color = SOIL,
			Material = Enum.Material.Ground,
			CFrame = cf * CFrame.new(0, 2, 0) * CYLINDER_UP,
		})
	)
	local leaves = {
		{ Offset = Vector3.new(0, 3.6, 0), Size = 2.6, Color = LEAF },
		{ Offset = Vector3.new(0.7, 3, 0.4), Size = 1.8, Color = LEAF_LIGHT },
		{ Offset = Vector3.new(-0.6, 3.1, -0.5), Size = 1.9, Color = LEAF_LIGHT },
	}
	for i, leaf in leaves do
		add(
			m,
			part({
				Name = `Leaves{i}`,
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * leaf.Size,
				Color = leaf.Color,
				Material = Enum.Material.Grass,
				CFrame = cf * CFrame.new(leaf.Offset),
			})
		)
	end
	m.PrimaryPart = pot
	return m
end

function Builders.LightStrand(from: Vector3, to: Vector3, index: number): Model
	local m = model(`FairyLights{index}`)
	local span = to - from
	local length = span.Magnitude
	local bulbCount = math.max(2, math.floor(length / BULB_SPACING))
	local previous: Vector3? = nil
	for i = 0, bulbCount do
		local t = i / bulbCount
		-- Parabolic sag, deepest in the middle.
		local point = from + span * t - Vector3.new(0, SAG * 4 * t * (1 - t), 0)
		if previous then
			local mid = (previous + point) / 2
			local segment = (point - previous).Magnitude
			add(
				m,
				part({
					Name = "Cable",
					Size = Vector3.new(0.08, 0.08, segment),
					Color = CABLE,
					CFrame = CFrame.lookAt(mid, point),
				})
			)
		end
		local bulb = part({
			Name = "Bulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.45,
			Color = BULB_COLORS[(i % #BULB_COLORS) + 1],
			Material = Enum.Material.Neon,
			CFrame = CFrame.new(point - Vector3.new(0, 0.25, 0)),
		})
		if i % LIGHT_EVERY == 0 then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 214, 150)
			light.Range = 10
			light.Brightness = 0.9
			light.Shadows = false
			light.Parent = bulb
		end
		add(m, bulb)
		previous = point
	end
	return m
end

function Builders.TipJar(cf: CFrame, level: number): Model
	local m = model("TipJar")
	local s = 0.8 + 0.35 * level
	local height = 1.6 * s
	local width = 1.2 * s
	local jar = part({
		Name = "Jar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, width, width),
		Color = Color3.fromRGB(210, 235, 240),
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		CFrame = cf * CFrame.new(0, height / 2, 0) * CYLINDER_UP,
	})
	add(m, jar)
	add(
		m,
		part({
			Name = "Rim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15 * s, width * 1.05, width * 1.05),
			Color = Styles.GOLD_DEEP,
			Material = Enum.Material.Metal,
			CFrame = cf * CFrame.new(0, height, 0) * CYLINDER_UP,
		})
	)
	-- Coins fill the jar a little more each level.
	local coinRows = 1 + level
	for row = 1, coinRows do
		add(
			m,
			part({
				Name = "Coins",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.18 * s, width * 0.8, width * 0.8),
				Color = if row % 2 == 0 then Styles.GOLD else Styles.GOLD_MID,
				Material = Enum.Material.Metal,
				CFrame = cf * CFrame.new(0, 0.12 * s + (row - 1) * 0.2 * s, 0) * CYLINDER_UP,
			})
		)
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(110, 30)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height / 2 + 0.9, 0)
	billboard.MaxDistance = 30
	billboard.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Styles.GREEN
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Styles.FONT_FREDOKA
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = `Tips Lv {level}`
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Styles.CORNER_BUTTON
	corner.Parent = label
	label.Parent = billboard
	billboard.Parent = jar

	m.PrimaryPart = jar
	return m
end

function Builders.Jukebox(cf: CFrame, level: number): Model
	local m = model("Jukebox")
	local body = part({
		Name = "Body",
		Size = Vector3.new(4, 5, 2.4),
		Color = WOOD,
		Material = Enum.Material.Wood,
		CanCollide = true,
		CFrame = cf * CFrame.new(0, 2.5, 0),
	})
	add(m, body)
	add(
		m,
		part({
			Name = "Arch",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.4, 4, 4),
			Color = WOOD,
			Material = Enum.Material.Wood,
			CFrame = cf * CFrame.new(0, 5, 0) * CFrame.Angles(0, math.rad(90), 0),
		})
	)
	local panel = part({
		Name = "Panel",
		Size = Vector3.new(3, 2.2, 0.2),
		Color = Styles.ROSE,
		Material = Enum.Material.Neon,
		CFrame = cf * CFrame.new(0, 4.4, -1.25),
	})
	add(m, panel)
	add(
		m,
		part({
			Name = "Grille",
			Size = Vector3.new(3, 1.8, 0.2),
			Color = WOOD_DARK,
			Material = Enum.Material.DiamondPlate,
			CFrame = cf * CFrame.new(0, 1.6, -1.25),
		})
	)
	local light = Instance.new("PointLight")
	light.Color = Styles.ROSE
	light.Range = if level >= 2 then 18 else 10
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = panel

	if level >= 2 then
		-- Party mode: the panel and its light drift between brand colours, with sparkles.
		local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(panel, tweenInfo, { Color = Styles.GREEN_LIGHT }):Play()
		TweenService:Create(light, tweenInfo, { Color = Styles.GREEN_LIGHT }):Play()
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Rate = 4
		sparkles.Lifetime = NumberRange.new(1.5, 2.5)
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.SpreadAngle = Vector2.new(35, 35)
		sparkles.Size = NumberSequence.new(0.35, 0)
		sparkles.LightEmission = 1
		sparkles.Color = ColorSequence.new(Styles.GOLD, Styles.ROSE)
		sparkles.EmissionDirection = Enum.NormalId.Top
		sparkles.Parent = panel
	end

	m.PrimaryPart = body
	return m
end

--- The board doubles as the plaque. Returns the model, the prompt, and the label that
--- lists contributors.
function Builders.Board(cf: CFrame): (Model, ProximityPrompt, TextLabel)
	local m = model("UpgradeBoard")
	for i, x in { -2.6, 2.6 } do
		add(
			m,
			part({
				Name = `Post{i}`,
				Size = Vector3.new(0.4, 7, 0.4),
				Color = WOOD_DARK,
				Material = Enum.Material.Wood,
				CanCollide = true,
				CFrame = cf * CFrame.new(x, 3.5, 0),
			})
		)
	end
	local board = part({
		Name = "Plaque",
		Size = Vector3.new(6, 4.6, 0.3),
		Color = WOOD,
		Material = Enum.Material.Wood,
		CanCollide = true,
		CFrame = cf * CFrame.new(0, 4.4, -0.1),
	})
	add(m, board)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "PlaqueGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = board

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Styles.OFFWHITE
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.94, 0.92)
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = Styles.CORNER_CARD
	frameCorner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Styles.GREEN_DIM
	stroke.Thickness = 5
	stroke.Parent = frame
	frame.Parent = gui

	-- UI-REVISION: the title is the Banner ribbon (Components/Buttons/Banner images,
	-- GREEN), as on the dialogs and OrderQueue, instead of a flat green bar.
	local title = Instance.new("Frame")
	title.Name = "Title"
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0.5, 0.02)
	title.Size = UDim2.fromScale(0.86, 0.2)
	title.Parent = frame

	local ribbonBack = Instance.new("ImageLabel")
	ribbonBack.AnchorPoint = Vector2.new(0.5, 0)
	ribbonBack.BackgroundTransparency = 1
	ribbonBack.Image = "http://www.roblox.com/asset/?id=13369767169"
	ribbonBack.ImageColor3 = Styles.GREEN
	ribbonBack.Position = UDim2.fromScale(0.5, 0.1)
	ribbonBack.Size = UDim2.fromScale(1, 0.875)
	ribbonBack.Parent = title

	local ribbonFront = Instance.new("ImageLabel")
	ribbonFront.AnchorPoint = Vector2.new(0.5, 0)
	ribbonFront.BackgroundTransparency = 1
	ribbonFront.Image = "http://www.roblox.com/asset/?id=13369762471"
	ribbonFront.ImageColor3 = Styles.GREEN
	ribbonFront.Position = UDim2.fromScale(0.5, 0)
	ribbonFront.Size = UDim2.fromScale(0.845523, 0.758506)
	ribbonFront.ZIndex = 2
	ribbonFront.Parent = title

	local titleText = Instance.new("TextLabel")
	titleText.AnchorPoint = Vector2.new(0, 0.5)
	titleText.BackgroundTransparency = 1
	titleText.Position = UDim2.fromScale(0, 0.5)
	titleText.Size = UDim2.fromScale(1, 0.8)
	titleText.FontFace = Styles.FONT_FREDOKA
	titleText.TextScaled = true
	titleText.TextColor3 = Color3.new(1, 1, 1)
	titleText.Text = "Cafe Upgrades"
	titleText.ZIndex = 3
	titleText.Parent = ribbonFront

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromScale(0.05, 0.23)
	hint.Size = UDim2.fromScale(0.9, 0.08)
	hint.FontFace = Styles.FONT_FREDOKA
	hint.TextScaled = true
	hint.TextColor3 = Styles.GREEN_LIGHT
	hint.Text = "Upgrade the cafe for everyone here! Thanks to:"
	hint.Parent = frame

	local list = Instance.new("TextLabel")
	list.Name = "Contributors"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.05, 0.32)
	list.Size = UDim2.fromScale(0.9, 0.64)
	list.FontFace = Styles.FONT_FREDOKA
	list.TextSize = 22
	list.TextWrapped = true
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Styles.GREEN_DEEP
	list.Text = ""
	list.Parent = frame

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Cafe Upgrades"
	prompt.ActionText = "Upgrade"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = CafeUpgradeConfig.PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("BuiltBy", BUILT_BY)
	prompt.Parent = board

	m.PrimaryPart = board
	return m, prompt, list
end

return Builders

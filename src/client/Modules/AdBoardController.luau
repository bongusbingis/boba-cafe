---> services
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local Knit = require(Packages.Knit)
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> config
local AdBoardConfig = require(Shared.Configuration.AdBoardConfig)

---> components
local Header = require(UI.Components.AdBoard.Header)
local PassBoard = require(UI.Components.AdBoard.PassBoard)
local CelebrityBoard = require(UI.Components.AdBoard.CelebrityBoard)

---> module declaration
local AdBoardController = Knit.CreateController({
	Name = "AdBoardController",
	Roots = {},
})

---> private
local c = React.createElement

--- Product info is identical for every player, so one lookup per board is enough.
--- Returns nil when the lookup fails; the board then falls back to its config text.
local function fetchInfo(kind: string, id: number)
	if not id or id == 0 then
		return nil
	end

	local infoType = if kind == "Product" then Enum.InfoType.Product else Enum.InfoType.GamePass

	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(id, infoType)
	end)

	return ok and info or nil
end

--- Replaces any SurfaceGui already on `adornee` with a fresh one, so leftover
--- hand-built GUIs from the old place are cleaned up rather than layered under ours.
local function makeSurface(adornee: BasePart, name: string, pixelsPerStud: number): SurfaceGui
	for _, existing in adornee:GetChildren() do
		if existing:IsA("SurfaceGui") then
			existing:Destroy()
		end
	end

	local surface = Instance.new("SurfaceGui")
	surface.Name = name
	surface.ClipsDescendants = true
	surface.Face = AdBoardConfig.SURFACE_FACE
	surface.LightInfluence = 1
	surface.PixelsPerStud = pixelsPerStud
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	surface.Adornee = adornee
	surface.Parent = adornee

	return surface
end

--- Header strip and body panel are separate parts in the build, so each needs its own
--- adornee. Picks the shortest part as the header and the tallest as the body.
local function findSurfaces(board: Model): (BasePart?, BasePart?)
	local header, body

	for _, child in board:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end

		-- The body panel is much taller than the header strip.
		if not body or child.Size.Y > body.Size.Y then
			if body and (not header or body.Size.Y < header.Size.Y) then
				header = body
			end
			body = child
		elseif not header or child.Size.Y < header.Size.Y then
			header = child
		end
	end

	return header, body
end

function AdBoardController:_mountBoard(board: Model, definition)
	local header, body = findSurfaces(board)
	if not body then
		warn(`[AdBoardController] Board '{board.Name}' has no part to render onto.`)
		return
	end

	local colorValue = board:FindFirstChild("MainColor")
	local color = (colorValue and colorValue:IsA("Color3Value") and colorValue.Value)
		or AdBoardConfig.DEFAULT_COLOR

	local function promptPurchase(productId: number?)
		local id = productId or definition.Id
		if not id or id == 0 then
			return
		end

		if definition.Kind == "Product" or productId then
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
		else
			MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, id)
		end
	end

	---> body
	local bodySurface = makeSurface(body, "SurfaceGui", AdBoardConfig.BODY_PIXELS_PER_STUD)
	local bodyRoot = ReactRoblox.createRoot(bodySurface)
	table.insert(self.Roots, bodyRoot)

	local title, subtitle

	if definition.Kind == "Celebrity" then
		title = definition.Title or "Celebrity"
		subtitle = "Subscription"
		bodyRoot:render(c(CelebrityBoard, {
			OnPurchase = promptPurchase,
		}))
	else
		local info = fetchInfo(definition.Kind, definition.Id)

		title = definition.Title or (info and info.Name) or board.Name
		subtitle = if definition.Kind == "Product" then "Product" else "Game Pass"

		bodyRoot:render(c(PassBoard, {
			Description = definition.Description or (info and info.Description) or "",
			Image = if info and info.IconImageAssetId and info.IconImageAssetId ~= 0
				then `rbxassetid://{info.IconImageAssetId}`
				else "rbxasset://textures/ui/GuiImagePlaceholder.png",
			Price = tostring((info and info.PriceInRobux) or 0),
			Color = color,
			OnPurchase = promptPurchase,
		}))
	end

	---> header
	if header then
		local headerSurface = makeSurface(header, "SurfaceGui", AdBoardConfig.HEADER_PIXELS_PER_STUD)
		local headerRoot = ReactRoblox.createRoot(headerSurface)
		table.insert(self.Roots, headerRoot)

		headerRoot:render(c(Header, {
			Title = title,
			Subtitle = subtitle,
		}))
	end

	---> clicking the board itself also opens the prompt, as it did in V3
	local clickDetector = board:FindFirstChildWhichIsA("ClickDetector")
	if clickDetector then
		clickDetector.MouseClick:Connect(function()
			promptPurchase(nil)
		end)
	end
end

function AdBoardController:_getFolder(): Instance?
	local node: Instance = workspace

	for _, segment in AdBoardConfig.FOLDER_PATH do
		local nextNode = node:FindFirstChild(segment)
		if not nextNode then
			return nil
		end
		node = nextNode
	end

	return node
end

---> lifecycle

function AdBoardController:KnitStart()
	task.spawn(function()
		local folder = self:_getFolder()

		if not folder then
			warn(
				`[AdBoardController] No workspace.{table.concat(AdBoardConfig.FOLDER_PATH, ".")} folder — ad boards disabled.`
			)
			return
		end

		-- Boards may sit in category sub-folders (Gamepasses/, Products/), so match on
		-- name anywhere in the tree rather than assuming a flat layout.
		for _, descendant in folder:GetDescendants() do
			if not descendant:IsA("Model") then
				continue
			end

			local definition = AdBoardConfig.Boards[descendant.Name]
			if not definition then
				continue
			end

			-- One bad board must not stop the others rendering.
			local ok, err = pcall(function()
				self:_mountBoard(descendant, definition)
			end)

			if not ok then
				warn(`[AdBoardController] Board '{descendant.Name}' failed to mount: {err}`)
			end
		end
	end)
end

return AdBoardController

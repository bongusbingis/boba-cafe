---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local Knit = require(Packages.Knit)
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

---> components
local Leaderboard = require(UI.Components.Leaderboard)

---> config
local LeaderboardConfig = require(Shared.Configuration.LeaderboardConfig)

---> module declaration
local LeaderboardController = Knit.CreateController({
	Name = "LeaderboardController",
	Roots = {},
})

---> private
local c = React.createElement

--- The part a board's standings render onto: the largest face in the model, which is
--- the display panel rather than the header strip or trim.
local function findDisplayPart(board: Model): BasePart?
	local best: BasePart? = nil

	for _, child in board:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end

		if not best or (child.Size.X * child.Size.Y) > (best.Size.X * best.Size.Y) then
			best = child
		end
	end

	return best
end

--- One React root per board, created lazily and reused across refreshes.
function LeaderboardController:_getRoot(board: Model)
	local existing = self.Roots[board]
	if existing then
		return existing
	end

	local part = findDisplayPart(board)
	if not part then
		warn(`[LeaderboardController] Board '{board.Name}' has no part to render onto.`)
		return nil
	end

	-- Replace any leftover SurfaceGui so old hand-built ones do not show through.
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end

	local surface = Instance.new("SurfaceGui")
	surface.Name = "LeaderboardGui"
	surface.Face = Enum.NormalId.Front
	surface.LightInfluence = 0
	surface.PixelsPerStud = 50
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	surface.Adornee = part
	surface.Parent = part

	local root = ReactRoblox.createRoot(surface)
	self.Roots[board] = root
	return root
end

function LeaderboardController:_render(payload)
	local board = payload and payload.Board
	if not board or not board:IsDescendantOf(workspace) then
		return
	end

	local root = self:_getRoot(board)
	if not root then
		return
	end

	local definition = LeaderboardConfig.Boards[board.Name]

	root:render(c(Leaderboard, {
		Title = board.Name,
		Caption = payload.Caption,
		Rows = payload.Rows,
		Color = definition and definition.Color or nil,
	}))
end

---> lifecycle

function LeaderboardController:KnitStart()
	local leaderboardService = Knit.GetService("LeaderboardService")

	leaderboardService.BoardUpdated:Connect(function(payload)
		self:_render(payload)
	end)

	-- Boards refresh on a slow interval, so fetch whatever is already cached rather
	-- than showing nothing until the next refresh.
	task.spawn(function()
		local ok, payloads = leaderboardService:GetBoards():await()
		if not ok or not payloads then
			return
		end

		for _, payload in payloads do
			self:_render(payload)
		end
	end)
end

return LeaderboardController

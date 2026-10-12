---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

---> module declaration
local MopWhackController = Knit.CreateController({
	Name = "MopWhackController",
})

---> constants

-- Kept in step with MopWhackService.MAX_HIT_DISTANCE. The server re-checks range, so a
-- mismatch here only affects who gets picked, never whether the hit is allowed.
local MAX_HIT_DISTANCE = 15

-- How far off straight-ahead a target can be and still count, as a dot product against
-- the character's look vector. ~0.35 is a forward cone of roughly 70 degrees each side.
local MIN_FACING_DOT = 0.35

local TOOL_NAME = "Mop Whack"

---> private

local LocalPlayer = Players.LocalPlayer

--- The player most directly in front of the local character, within range.
local function findTarget(): Player?
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end

	local origin = (root :: BasePart).Position
	local look = (root :: BasePart).CFrame.LookVector

	local best, bestScore = nil, MIN_FACING_DOT

	for _, player in Players:GetPlayers() do
		if player == LocalPlayer then
			continue
		end

		local otherCharacter = player.Character
		local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
		local humanoid = otherCharacter and otherCharacter:FindFirstChildWhichIsA("Humanoid")

		if not otherRoot or not humanoid or humanoid.Health <= 0 then
			continue
		end

		local offset = (otherRoot :: BasePart).Position - origin
		if offset.Magnitude > MAX_HIT_DISTANCE then
			continue
		end

		-- Prefer whoever is closest to straight ahead rather than merely closest.
		local score = look:Dot(offset.Unit)
		if score > bestScore then
			best, bestScore = player, score
		end
	end

	return best
end

function MopWhackController:_bindTool(tool: Tool)
	tool.Activated:Connect(function()
		local target = findTarget()
		if not target then
			return
		end

		-- Fire and forget: the server owns cooldown, range and immunity.
		Knit.GetService("MopWhackService"):DoHit(target)
	end)
end

function MopWhackController:_watch(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child.Name == TOOL_NAME then
			self:_bindTool(child)
		end
	end

	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child.Name == TOOL_NAME then
			self:_bindTool(child)
		end
	end)
end

---> lifecycle

function MopWhackController:KnitStart()
	-- The tool moves between Backpack and Character as it is equipped, and both are
	-- rebuilt on respawn, so watch each one every time it appears.
	local function watchBackpack()
		local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
		if backpack then
			self:_watch(backpack)
		end
	end

	watchBackpack()
	LocalPlayer.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			self:_watch(child)
		end
	end)

	local function watchCharacter(character: Model)
		self:_watch(character)
		watchBackpack()
	end

	if LocalPlayer.Character then
		watchCharacter(LocalPlayer.Character)
	end
	LocalPlayer.CharacterAdded:Connect(watchCharacter)
end

return MopWhackController

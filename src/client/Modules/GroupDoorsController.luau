---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local RankUtil = require(Shared.Utility.RankUtil)

---> module declaration
local GroupDoorsController = Knit.CreateController({
	Name = "GroupDoorsController",
})

---> constants

--- Folder under workspace.Assets holding rank-gated doors. Each child is a BasePart (or
--- a Model of them) with a `MinRank` IntValue or attribute.
local DOORS_FOLDER = "GroupDoors"
local RANK_ATTRIBUTE = "MinRank"

---> private
local LocalPlayer = Players.LocalPlayer

--- Rank required to pass a door, from an attribute or a child IntValue.
local function getRequiredRank(door: Instance): number?
	local attribute = door:GetAttribute(RANK_ATTRIBUTE)
	if typeof(attribute) == "number" then
		return attribute
	end

	local value = door:FindFirstChild(RANK_ATTRIBUTE)
	if value and value:IsA("IntValue") then
		return value.Value
	end

	return nil
end

--- Doors are made non-collidable for players who out-rank them. This is presentation
--- only — anything that actually matters is gated server-side, since a client can
--- always change its own CanCollide.
local function applyDoor(door: Instance, rank: number)
	local required = getRequiredRank(door)
	if not required then
		return
	end

	local passable = rank >= required

	if door:IsA("BasePart") then
		door.CanCollide = not passable
		door.LocalTransparencyModifier = if passable then 0.6 else 0
		return
	end

	for _, part in door:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = not passable
			part.LocalTransparencyModifier = if passable then 0.6 else 0
		end
	end
end

---> lifecycle

function GroupDoorsController:KnitStart()
	task.spawn(function()
		local assets = workspace:WaitForChild("Assets", 30)
		local folder = assets and assets:FindFirstChild(DOORS_FOLDER)

		if not folder then
			-- The folder is deferred with the rest of the build; stay quiet-ish.
			warn(`[GroupDoorsController] No workspace.Assets.{DOORS_FOLDER} — group doors disabled.`)
			return
		end

		local rank = RankUtil:GetRankAsync(LocalPlayer)

		local function applyAll()
			for _, door in folder:GetChildren() do
				applyDoor(door, rank)
			end
		end

		applyAll()
		folder.ChildAdded:Connect(function(door)
			applyDoor(door, rank)
		end)

		-- Rank can change mid-session (claiming a pass rank), so re-apply on respawn,
		-- which is when the cache has usually been invalidated.
		LocalPlayer.CharacterAdded:Connect(function()
			rank = RankUtil:GetRankAsync(LocalPlayer)
			applyAll()
		end)
	end)
end

return GroupDoorsController

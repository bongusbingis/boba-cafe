--[[
	BobaPhoneService (REVIVAL-001 BOBA-PHONE D10 + R3)
	Gives every player one Boba Phone Tool cloned from the authored
	ReplicatedStorage.ToolsStorage["Boba Phone"]. The clone's legacy
	LocalScript is destroyed (the React controller replaces it); the clone
	carries BobaPhone = true and BuiltBy = "Muse".

	R3 (Jack, 2026-10-21): the phone and ClockedIn are mutually exclusive.
	On clock-in the phone is unequipped and removed from Backpack and
	StarterGear; on clock-out it is granted again. Nothing here touches the
	serve path, prices, levels, or ActivityScript.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

local BobaPhoneService = Knit.CreateService({
	Name = "BobaPhoneService",
	Client = {},
})

local TOOL_NAME = "Boba Phone"
local TOOLS_STORAGE_NAME = "ToolsStorage"
local CLOCKED_IN_ATTRIBUTE = "ClockedIn"
local BUILT_BY = "Muse"

local warnedMissingTool = false

local function warnMissingOnce(message: string)
	if warnedMissingTool then
		return
	end
	warnedMissingTool = true
	warn("[BobaPhoneService] " .. message)
end

-- Strips the legacy toggle script and marks the clone. Pure on the instance:
-- destroys every descendant LocalScript, sets BobaPhone and BuiltBy.
function BobaPhoneService.prepareClone(tool: Tool): Tool
	for _, descendant in tool:GetDescendants() do
		if descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
	tool:SetAttribute("BobaPhone", true)
	tool:SetAttribute("BuiltBy", BUILT_BY)
	return tool
end

local function findPhone(container: Instance?): Tool?
	if not container then
		return nil
	end
	local child = container:FindFirstChild(TOOL_NAME)
	if child and child:IsA("Tool") then
		return child
	end
	return nil
end

local function hasPhone(player: Player): boolean
	return findPhone(player:FindFirstChild("Backpack")) ~= nil
		or findPhone(player.Character) ~= nil
		or findPhone(player:FindFirstChild("StarterGear")) ~= nil
end

local function removePhone(player: Player)
	for _, container in { player:FindFirstChild("Backpack"), player.Character, player:FindFirstChild("StarterGear") } do
		local phone = findPhone(container)
		if phone then
			phone:Destroy()
		end
	end
end

local function grantPhone(player: Player)
	if hasPhone(player) then
		return
	end
	local storage = ReplicatedStorage:WaitForChild(TOOLS_STORAGE_NAME, 10)
	if not storage then
		warnMissingOnce(TOOLS_STORAGE_NAME .. " not found; Boba Phone not granted.")
		return
	end
	local template = storage:FindFirstChild(TOOL_NAME)
	if not template or not template:IsA("Tool") then
		warnMissingOnce(TOOLS_STORAGE_NAME .. '["' .. TOOL_NAME .. '"] not found; Boba Phone not granted.')
		return
	end
	-- StarterGear survives respawn; Backpack covers the current life. Never
	-- grant twice: each container keeps at most one phone.
	for _, container in { player:FindFirstChild("StarterGear"), player:FindFirstChild("Backpack") } do
		if container and not findPhone(container) then
			local clone = (template :: Tool):Clone()
			BobaPhoneService.prepareClone(clone)
			clone.Parent = container
		end
	end
end

-- One phone while clocked out, none while clocked in (R3). With the default
-- ClockedIn = true, a new barista's grant is removed again as soon as
-- ShiftService sets the attribute; clocking out grants it back.
local function syncPhone(player: Player)
	if player:GetAttribute(CLOCKED_IN_ATTRIBUTE) == true then
		removePhone(player)
	else
		grantPhone(player)
	end
end

function BobaPhoneService:PlayerAdded(player: Player)
	syncPhone(player)
	player:GetAttributeChangedSignal(CLOCKED_IN_ATTRIBUTE):Connect(function()
		syncPhone(player)
	end)
end

function BobaPhoneService:KnitStart()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			syncPhone(player)
		end)
	end
end

return BobaPhoneService

--!strict
--[[
    Module: VipElevatorService
    Description: Ports the legacy ElevatorScript (REVIVAL-001 PASS-PORT lane B).
                 Place-authored content (dev place):
                   workspace.OldScriptables.ElevatorFolder.Floors.Floor1 / Floor2
                     .CallElevator.ProximityPrompt  -- call button on that floor
                     .Teleport                      -- arrival pad on that floor
                     .Configuration.GamePass        -- IntValue, pass id required to arrive (Floor2 = 12385781)
                 Using a floor's prompt sends the player to the OTHER floor's Teleport pad.
                 The old script only fired a replica to the client and never checked
                 the pass; the gate was the Floor2 Configuration.GamePass value, which
                 is enforced here. Arriving on a floor whose GamePass is set needs
                 PerkService:HasPerk(player, "VipLounge"); non-owners get the Roblox
                 pass purchase prompt instead. Going down is always free.
                 The legacy ElevatorScript is Disabled = true in the place and must stay so.
--]]

---> services

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

---> dependencies

local Knit = require(Packages.Knit)
local WorldPath = require(Shared.Utility.WorldPath)
local GamepassUtil = require(Shared.Utility.GamepassUtil)

---> constants

local VIP_PERK = "VipLounge"
local FLOORS_PATH = { "OldScriptables", "ElevatorFolder", "Floors" }
local FLOOR_NAMES = { "Floor1", "Floor2" }
local FLOOR_TIMEOUT_SECONDS = 10
local ARRIVAL_LIFT = Vector3.new(0, 3, 0) -- Teleport pads are 1 stud thick, non-colliding
local COOLDOWN_SECONDS = 2
local PROMPT_COOLDOWN_SECONDS = 5

---> service

local VipElevatorService = Knit.CreateService({
	Name = "VipElevatorService",
	Client = {},

	_lastUse = {} :: { [Player]: number },
	_lastPrompt = {} :: { [Player]: number },
})

---> private

-- The pass id gating arrival on a floor, or nil when the floor is open.
local function requiredPassId(floor: Instance): number?
	local value = WorldPath.find(floor, { "Configuration", "GamePass" })
	if value ~= nil and value:IsA("IntValue") and (value :: IntValue).Value > 0 then
		return (value :: IntValue).Value
	end
	return nil
end

function VipElevatorService:_canArrive(player: Player, passId: number?): boolean
	if passId == nil then
		return true
	end
	return self._perks:HasPerk(player, VIP_PERK)
end

function VipElevatorService:_ride(player: Player, destination: Instance, passId: number?)
	local now = os.clock()
	if now - (self._lastUse[player] or -math.huge) < COOLDOWN_SECONDS then
		return
	end
	local character = player.Character
	local pad = destination:FindFirstChild("Teleport")
	if character == nil or pad == nil or not pad:IsA("BasePart") then
		return
	end
	self._lastUse[player] = now

	if not self:_canArrive(player, passId) then
		if now - (self._lastPrompt[player] or -math.huge) >= PROMPT_COOLDOWN_SECONDS and passId ~= nil then
			self._lastPrompt[player] = now
			pcall(function()
				MarketplaceService:PromptGamePassPurchase(player, passId)
			end)
		end
		return
	end

	-- The yield in HasPerk can outlive the character.
	if player.Character ~= character or character.Parent == nil then
		return
	end
	character:PivotTo(CFrame.new((pad :: BasePart).Position + ARRIVAL_LIFT))
end

function VipElevatorService:_wire(floors: Instance)
	local byName: { [string]: Instance } = {}
	for _, name in FLOOR_NAMES do
		local floor = floors:FindFirstChild(name)
		if floor == nil then
			warn(
				`[VipElevatorService] workspace.OldScriptables.ElevatorFolder.Floors.{name} is missing; elevator disabled.`
			)
			return
		end
		byName[name] = floor
	end

	for i, name in FLOOR_NAMES do
		local from = byName[name]
		local destination = byName[FLOOR_NAMES[3 - i]]
		local prompt = WorldPath.find(from, { "CallElevator", "ProximityPrompt" })
		if prompt == nil or not prompt:IsA("ProximityPrompt") then
			warn(
				`[VipElevatorService] Floors.{name}.CallElevator.ProximityPrompt is missing; that call button is dead.`
			)
			continue
		end
		local passId = requiredPassId(destination)
		local proximityPrompt = prompt :: ProximityPrompt
		proximityPrompt.Triggered:Connect(function(player: Player)
			self:_ride(player, destination, passId)
		end)
	end
end

---> lifecycle

function VipElevatorService:KnitStart()
	self._perks = Knit.GetService("PerkService")

	-- In-session purchase: the pass cache would still say "not owned" until rejoin.
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, wasPurchased: boolean)
			if not wasPurchased then
				return
			end
			local ok, owns = pcall(function()
				return (GamepassUtil :: any):GrantPassToCache(player, passId)
			end)
			if not ok then
				warn(`[VipElevatorService] could not cache pass {passId}: {owns}`)
			end
		end
	)

	Players.PlayerRemoving:Connect(function(player)
		self._lastUse[player] = nil
		self._lastPrompt[player] = nil
	end)

	task.spawn(function()
		local floors = WorldPath.waitFor(Workspace, FLOORS_PATH, FLOOR_TIMEOUT_SECONDS)
		if floors == nil then
			warn("[VipElevatorService] workspace.OldScriptables.ElevatorFolder.Floors not found; elevator disabled.")
			return
		end
		self:_wire(floors)
	end)
end

return VipElevatorService

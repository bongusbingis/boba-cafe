---> Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local WorldPath = require(Shared.Utility.WorldPath)

---> Constants

local OPEN_LEVEL = 3 -- Q20; design 5.3 L3: break areas open at this Level
local LEVEL_ATTRIBUTE = "Level"
local GATES_PATH = { "AreaLimits", "BreakGates" }
local GATES_TIMEOUT_SECONDS = 10
local LOCAL_FOLDER_NAME = "AreaLimitsLocal"
local TEMPLATE_NAME = "Gate_Template" -- parked template part, never cloned
local CLOCKED_IN_ATTRIBUTE = "ClockedIn" -- owned by ShiftService
local WELCOME_TEXT = "Welcome to Boba Cafe! Follow the gold glow to make your first drink."

---> Controller

local AreaController = Knit.CreateController({
	Name = "AreaController",
})

local LocalPlayer = Players.LocalPlayer

local function applyGates(gates: Instance)
	local existing = Workspace:FindFirstChild(LOCAL_FOLDER_NAME)
	local level = LocalPlayer:GetAttribute(LEVEL_ATTRIBUTE) or 1

	if level >= OPEN_LEVEL then
		if existing then
			existing:Destroy()
		end
		return
	end

	if existing then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = LOCAL_FOLDER_NAME
	for _, gate in gates:GetChildren() do
		if gate.Name ~= TEMPLATE_NAME then
			gate:Clone().Parent = folder
		end
	end
	folder.Parent = Workspace
end

local welcomeShown = false

local function tryWelcome()
	if welcomeShown or LocalPlayer:GetAttribute(CLOCKED_IN_ATTRIBUTE) ~= true then
		return
	end
	Knit.GetController("DataController"):GetDataAsync():andThen(function(playerData)
		if welcomeShown or LocalPlayer:GetAttribute(CLOCKED_IN_ATTRIBUTE) ~= true then
			return
		end
		local stats = playerData.Statistics
		if not stats or stats.ShiftsCompleted ~= 0 then
			return
		end
		welcomeShown = true
		Knit.GetController("DialogController"):Toast(WELCOME_TEXT)
	end)
end

function AreaController:KnitStart()
	LocalPlayer:GetAttributeChangedSignal(CLOCKED_IN_ATTRIBUTE):Connect(tryWelcome)
	tryWelcome()

	local gates = WorldPath.waitFor(ReplicatedStorage, GATES_PATH, GATES_TIMEOUT_SECONDS)
	if not gates then
		-- Never block or kick: missing content means no gates.
		warn("[AreaController] ReplicatedStorage.AreaLimits.BreakGates not found; break areas stay open")
		return
	end

	local function refresh()
		applyGates(gates)
	end

	LocalPlayer:GetAttributeChangedSignal(LEVEL_ATTRIBUTE):Connect(refresh)
	refresh()
end

return AreaController

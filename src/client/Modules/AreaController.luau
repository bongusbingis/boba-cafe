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

function AreaController:KnitStart()
	local gates = WorldPath.waitFor(ReplicatedStorage, GATES_PATH, GATES_TIMEOUT_SECONDS)
	if not gates then
		-- Never block or kick: missing content means no gates.
		warn("[AreaController] ReplicatedStorage.AreaLimits.BreakGates not found; break areas stay open")
		return
	end

	local lastLevel: number? = nil
	local function refresh()
		applyGates(gates)
		local level = LocalPlayer:GetAttribute(LEVEL_ATTRIBUTE)
		if typeof(level) ~= "number" then
			return
		end
		if lastLevel ~= nil and lastLevel < OPEN_LEVEL and level >= OPEN_LEVEL then
			pcall(function()
				Knit.GetController("DialogController"):Toast("Break areas are open!")
			end)
		end
		lastLevel = level
	end

	LocalPlayer:GetAttributeChangedSignal(LEVEL_ATTRIBUTE):Connect(refresh)
	refresh()
end

return AreaController

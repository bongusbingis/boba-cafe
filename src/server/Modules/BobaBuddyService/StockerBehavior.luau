--!strict
--[[
	StockerBehavior
	Autonomous chore behavior for Boba Buddy: Stocker.
	Scans for depleted kitchen stations (< 50% stock) within 30 studs of owner,
	walks to them, replenishes stock, and applies audio/visual updates without stat credit.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local BobaBuddyConfig = require(Shared.Configuration.BobaBuddyConfig)
local KitchenConfig = require(Shared.Configuration.KitchenConfig)

local StockerBehavior = {}

local function updateStationVisual(model: Model, currentStock: number, _defaultStock: number)
	local isDepleted = currentStock <= 0
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name == "DepletedIndicator" then
			desc.Transparency = if isDepleted then 0 else 1
		end
	end
end

function StockerBehavior.Start(model: Model, owner: Player, setBusy: (boolean) -> ()): () -> ()
	local running = true
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")

	task.spawn(function()
		while running and model.Parent do
			task.wait(BobaBuddyConfig.STOCKER.CHECK_INTERVAL_SECONDS)
			if not running or not model.Parent then
				break
			end

			local ownerChar = owner.Character
			local ownerRoot = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not ownerRoot or not root or not humanoid then
				continue
			end

			local kitchenService = Knit.GetService("KitchenService")
			local kitchen = workspace:FindFirstChild("Assets") and workspace.Assets:FindFirstChild("Kitchen")
			if not kitchenService or not kitchen then
				continue
			end

			-- Find nearest eligible station below 50% stock within 30 studs of owner
			local bestStation: Model? = nil
			local bestPrompt: ProximityPrompt? = nil
			local bestDist = BobaBuddyConfig.STOCKER.RANGE_STUDS
			local bestPos: Vector3? = nil

			for _, desc in kitchen:GetDescendants() do
				if desc:IsA("ProximityPrompt") and desc:GetAttribute("DefaultStock") ~= nil then
					local defaultStock = desc:GetAttribute("DefaultStock") :: number
					local currentStock = (desc:GetAttribute("CurrentStock") or 0) :: number
					local stationModel = desc:FindFirstAncestorOfClass("Model")
					if
						stationModel
						and defaultStock > 0
						and (currentStock / defaultStock) <= BobaBuddyConfig.STOCKER.STOCK_THRESHOLD_PERCENT
					then
						if not stationModel:GetAttribute("ClaimedByRestocker") then
							local stationPart = stationModel.PrimaryPart or desc.Parent :: BasePart?
							if stationPart and stationPart:IsA("BasePart") then
								local distToOwner = (stationPart.Position - ownerRoot.Position).Magnitude
								if distToOwner <= bestDist then
									bestDist = distToOwner
									bestStation = stationModel
									bestPrompt = desc
									bestPos = stationPart.Position
								end
							end
						end
					end
				end
			end

			if not bestStation or not bestPrompt or not bestPos then
				continue
			end

			-- Claim station
			bestStation:SetAttribute("ClaimedByRestocker", true)
			setBusy(true)

			-- Walk to station
			humanoid:MoveTo(bestPos)
			local reached = false
			local moveConn
			moveConn = humanoid.MoveToFinished:Connect(function()
				reached = true
			end)

			local startMove = os.clock()
			while not reached and os.clock() - startMove < 6 do
				if not running or not model.Parent or not bestStation.Parent then
					break
				end
				local currentDist = (root.Position - bestPos).Magnitude
				if currentDist <= 5 then
					break
				end
				task.wait(0.2)
			end
			if moveConn then
				moveConn:Disconnect()
			end

			-- Restock station if still valid
			if running and model.Parent and bestStation.Parent and bestPrompt.Parent then
				task.wait(1.0) -- Short restock action

				local defaultStock = (
					bestPrompt:GetAttribute("DefaultStock") or KitchenConfig.DEFAULT_STATION_STOCK
				) :: number
				bestPrompt:SetAttribute("CurrentStock", defaultStock)
				updateStationVisual(bestStation, defaultStock, defaultStock)

				-- Play SFX/UI/Serve
				pcall(function()
					local sfx = SoundService:FindFirstChild("SFX")
					local ui = sfx and sfx:FindFirstChild("UI")
					local serveSound = ui and ui:FindFirstChild("Serve")
					if serveSound and serveSound:IsA("Sound") then
						serveSound:Play()
					end
				end)
			end

			if bestStation and bestStation.Parent then
				bestStation:SetAttribute("ClaimedByRestocker", nil)
			end
			setBusy(false)

			-- Cooldown before next restock check
			task.wait(BobaBuddyConfig.STOCKER.COOLDOWN_SECONDS)
		end
	end)

	return function()
		running = false
	end
end

return StockerBehavior

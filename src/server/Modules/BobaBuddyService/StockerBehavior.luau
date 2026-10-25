--!strict
--[[
	StockerBehavior
	Autonomous chore behavior for Boba Buddy: Stocker.
	Scans for depleted kitchen stations (< 50% stock) within 30 studs of owner,
	navigates to grab a supply box, carries the box back to the depleted station via PathfindingService,
	and restocks the shelf.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local BobaBuddyConfig = require(Shared.Configuration.BobaBuddyConfig)
local KitchenConfig = require(Shared.Configuration.KitchenConfig)
local Navigator = require(script.Parent.Navigator)

local StockerBehavior = {}

local function updateStationVisual(model: Model, currentStock: number, _defaultStock: number)
	local isDepleted = currentStock <= 0
	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") and desc.Name == "DepletedIndicator" then
			desc.Transparency = if isDepleted then 0 else 1
		end
	end
end

local function createMockBox(character: Model, restockingGiver: Model?): Instance?
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return nil
	end

	local storage = ReplicatedStorage:FindFirstChild("SharedStorage")
	local stockingStorage = storage and storage:FindFirstChild("StockingStorage")
	local authoredBox = stockingStorage and stockingStorage:FindFirstChild("Box")

	local meshBoxes = restockingGiver and restockingGiver:FindFirstChild("Meshes/boxes")
	local boxPart: BasePart
	if authoredBox and authoredBox:IsA("Accessory") then
		local handle = authoredBox:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			boxPart = handle:Clone()
		else
			local part = Instance.new("Part")
			part.Size = Vector3.new(1.3, 1.3, 1.3)
			boxPart = part
		end
	elseif authoredBox and authoredBox:IsA("BasePart") then
		boxPart = authoredBox:Clone()
		boxPart.Size = Vector3.new(1.3, 1.3, 1.3)
	elseif meshBoxes and meshBoxes:IsA("BasePart") then
		boxPart = meshBoxes:Clone()
		boxPart.Size = Vector3.new(1.3, 1.0, 1.3)
	else
		local part = Instance.new("Part")
		part.Name = "RestockBox"
		part.Size = Vector3.new(1.4, 1.1, 1.3)
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(190, 145, 95)
		boxPart = part
	end

	boxPart.Name = "CarriedRestockBox"
	boxPart.CanCollide = false
	boxPart.Massless = true
	boxPart.Anchored = false
	pcall(function()
		boxPart.CollisionGroup = "NPC"
	end)
	boxPart.CFrame = hrp.CFrame * CFrame.new(0, -0.2, -1.2)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = boxPart
	weld.Parent = boxPart

	boxPart.Parent = character
	return boxPart
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

			local restockingGiver = kitchen:FindFirstChild("Givers")
				and kitchen.Givers:FindFirstChild("Restocking") :: Model?

			-- Find eligible station below threshold within range of owner (lowest fraction prioritized)
			local bestStation: Model? = nil
			local bestPrompt: ProximityPrompt? = nil
			local lowestFraction = 1.0
			local bestDist = BobaBuddyConfig.STOCKER.RANGE_STUDS
			local bestPos: Vector3? = nil

			for _, desc in kitchen:GetDescendants() do
				if desc:IsA("ProximityPrompt") and desc:GetAttribute("DefaultStock") ~= nil then
					local defaultStock = desc:GetAttribute("DefaultStock") :: number
					local currentStock = (desc:GetAttribute("CurrentStock") or 0) :: number
					local stationModel = desc:FindFirstAncestorOfClass("Model")
					if stationModel and defaultStock > 0 and currentStock < defaultStock then
						local fraction = currentStock / defaultStock
						if fraction <= BobaBuddyConfig.STOCKER.STOCK_THRESHOLD_PERCENT then
							if not stationModel:GetAttribute("ClaimedByRestocker") then
								local stationPart = stationModel.PrimaryPart or desc.Parent :: BasePart?
								if stationPart and stationPart:IsA("BasePart") then
									local distToOwner = (stationPart.Position - ownerRoot.Position).Magnitude
									if distToOwner <= BobaBuddyConfig.STOCKER.RANGE_STUDS then
										-- Prioritize lowest stock fraction first, then closer distance
										if
											fraction < lowestFraction
											or (fraction == lowestFraction and distToOwner < bestDist)
										then
											lowestFraction = fraction
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
				end
			end

			if not bestStation or not bestPrompt or not bestPos then
				continue
			end

			-- Claim station
			bestStation:SetAttribute("ClaimedByRestocker", true)
			setBusy(true)

			-- 1. Navigate directly to the station that needs restocking
			local reached = Navigator.WalkTo(model, bestPos, {
				ArriveRadius = 4,
				Timeout = 8,
				ShouldAbort = function()
					return not running or not model.Parent or not bestStation.Parent
				end,
			})

			-- 2. Restock station with the restocking box
			if reached and running and model.Parent and bestStation.Parent and bestPrompt.Parent then
				local boxInstance = createMockBox(model, restockingGiver)
				task.wait(1.0) -- Restocking action duration

				if boxInstance and boxInstance.Parent then
					boxInstance:Destroy()
				end

				local defaultStock = (
					bestPrompt:GetAttribute("DefaultStock") or KitchenConfig.GetDefaultStock(bestStation.Name)
				) :: number
				bestPrompt:SetAttribute("CurrentStock", defaultStock)
				updateStationVisual(bestStation, defaultStock, defaultStock)

				-- Play SFX
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

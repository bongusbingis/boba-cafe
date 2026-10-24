--!strict
--[[
	CleanerBehavior
	Autonomous chore behavior for Boba Buddy: Cleaner.
	Scans for mopping spills within 25 studs of owner, walks to them,
	plays cleaning animation, and cleans the spill without player quest/stat credit.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local BobaBuddyConfig = require(Shared.Configuration.BobaBuddyConfig)

local CleanerBehavior = {}

function CleanerBehavior.Start(model: Model, owner: Player, setBusy: (boolean) -> ()): () -> ()
	local running = true
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")

	task.spawn(function()
		while running and model.Parent do
			task.wait(BobaBuddyConfig.CLEANER.CHECK_INTERVAL_SECONDS)
			if not running or not model.Parent then
				break
			end

			local ownerChar = owner.Character
			local ownerRoot = ownerChar and ownerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not ownerRoot or not root or not humanoid then
				continue
			end

			local spillService = Knit.GetService("SpillService")
			if not spillService or not spillService.Spills or not spillService.Spills.Mopping then
				continue
			end

			-- Find nearest eligible spill within 25 studs of owner
			local bestSpill = nil
			local bestDist = BobaBuddyConfig.CLEANER.RANGE_STUDS
			local bestPos = nil

			for _, regionSpills in pairs(spillService.Spills.Mopping) do
				for _, spill in pairs(regionSpills) do
					if
						typeof(spill) == "table"
						and not spill.Cleaning
						and spill.Object
						and spill.Object.PrimaryPart
					then
						if not spill.Object:GetAttribute("ClaimedByBuddy") then
							local spillPos = spill.Object.PrimaryPart.Position
							local distToOwner = (spillPos - ownerRoot.Position).Magnitude
							if distToOwner <= bestDist then
								bestDist = distToOwner
								bestSpill = spill
								bestPos = spillPos
							end
						end
					end
				end
			end

			if not bestSpill or not bestPos then
				continue
			end

			-- Claim spill
			bestSpill.Object:SetAttribute("ClaimedByBuddy", true)
			setBusy(true)

			-- Move to spill
			humanoid:MoveTo(bestPos)
			local reached = false
			local moveConn
			moveConn = humanoid.MoveToFinished:Connect(function()
				reached = true
			end)

			local startMove = os.clock()
			while not reached and os.clock() - startMove < 6 do
				if not running or not model.Parent or not bestSpill.Object or not bestSpill.Object.Parent then
					break
				end
				local currentDist = (root.Position - bestPos).Magnitude
				if currentDist <= 4 then
					break
				end
				task.wait(0.2)
			end
			if moveConn then
				moveConn:Disconnect()
			end

			-- Clean spill if still valid
			if running and model.Parent and bestSpill.Object and bestSpill.Object.Parent and not bestSpill.Cleaning then
				-- Play cleaning animation if present
				local animator = humanoid:FindFirstChildOfClass("Animator")
				local mopAnimObj = bestSpill.Object:FindFirstChild("MoppingAnim")
				local track: AnimationTrack? = nil
				if
					animator
					and mopAnimObj
					and mopAnimObj:IsA("ObjectValue")
					and mopAnimObj.Value
					and mopAnimObj.Value:IsA("Animation")
				then
					pcall(function()
						track = animator:LoadAnimation(mopAnimObj.Value)
						if track then
							track:Play()
						end
					end)
				end

				task.wait(BobaBuddyConfig.CLEANER.MOP_DURATION_SECONDS)

				if track then
					track:Stop()
					track:Destroy()
				end

				-- Clean the spill (CleanedBy stays nil so no player stat/quest credit, but cafe cleanliness rises)
				pcall(function()
					bestSpill:Clean()
				end)
			end

			setBusy(false)

			-- Cooldown before next clean
			task.wait(BobaBuddyConfig.CLEANER.COOLDOWN_SECONDS)
		end
	end)

	return function()
		running = false
	end
end

return CleanerBehavior

--!strict
--[[
	CleanerBehavior
	Autonomous chore behavior for Boba Buddy: Cleaner.
	Scans for mopping spills within 25 studs of owner, navigates to them via PathfindingService,
	plays cleaning animation, and cleans the spill without player quest/stat credit.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local BobaBuddyConfig = require(Shared.Configuration.BobaBuddyConfig)
local Navigator = require(script.Parent.Navigator)

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

			-- Navigate to spill using PathfindingService
			local reached = Navigator.WalkTo(model, bestPos, {
				ArriveRadius = 4,
				Timeout = 8,
				ShouldAbort = function()
					return not running or not model.Parent or not bestSpill.Object or not bestSpill.Object.Parent
				end,
			})

			-- Clean spill if still valid
			if
				reached
				and running
				and model.Parent
				and bestSpill.Object
				and bestSpill.Object.Parent
				and not bestSpill.Cleaning
			then
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

				-- Clean spill
				local ok, err = pcall(function()
					if typeof(bestSpill.Clean) == "function" then
						bestSpill:Clean()
					elseif typeof(spillService.Clean) == "function" then
						spillService:Clean(bestSpill)
					end
				end)
				if not ok then
					warn(`[BobaBuddy Cleaner] Failed to clean spill: {err}`)
				end
			end

			if bestSpill and bestSpill.Object and bestSpill.Object.Parent then
				bestSpill.Object:SetAttribute("ClaimedByBuddy", nil)
			end
			setBusy(false)

			-- Cooldown before next clean check
			task.wait(BobaBuddyConfig.CLEANER.COOLDOWN_SECONDS)
		end
	end)

	return function()
		running = false
	end
end

return CleanerBehavior

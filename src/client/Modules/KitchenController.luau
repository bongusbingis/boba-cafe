---> Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local GamepassUtil = require(Shared.Utility.GamepassUtil)
local WorldPath = require(Shared.Utility.WorldPath)

---> Constants

local INSTANT_BREW_HOLD_DURATION = 0.5
local INSTANT_BREW_PASS_NAME = "Instant Brew"
local KITCHEN_TIMEOUT_SECONDS = 30

---> Controller

local KitchenController = Knit.CreateController({
	Name = "KitchenController",
})

local function applyInstantBrew(kitchenFolder: Instance)
	for _, descendant in kitchenFolder:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			descendant.HoldDuration = INSTANT_BREW_HOLD_DURATION
		end
	end

	kitchenFolder.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then
			descendant.HoldDuration = INSTANT_BREW_HOLD_DURATION
		end
	end)
end

function KitchenController:KnitStart()
	local player = Players.LocalPlayer

	local owns = GamepassUtil:PlayerOwnsPassAsync(player, INSTANT_BREW_PASS_NAME)
	if not owns then
		return
	end

	-- Bounded wait: a missing kitchen only disables the Instant Brew perk.
	local kitchen = WorldPath.waitFor(workspace, { "Assets", "Kitchen" }, KITCHEN_TIMEOUT_SECONDS)
	if not kitchen then
		warn("[KitchenController] workspace.Assets.Kitchen not found; Instant Brew hold times not applied.")
		return
	end
	applyInstantBrew(kitchen)
end

return KitchenController

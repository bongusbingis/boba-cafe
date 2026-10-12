---> Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> Dependencies

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local GamepassUtil = require(Shared.Utility.GamepassUtil)

---> Constants

local INSTANT_BREW_HOLD_DURATION = 0.5
local INSTANT_BREW_PASS_NAME = "Instant Brew"

---> Controller

local KitchenController = Knit.CreateController({
	Name = "KitchenController",
})

local function applyInstantBrew(kitchenFolder: Folder)
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

	local kitchen = workspace:WaitForChild("Assets"):WaitForChild("Kitchen")
	applyInstantBrew(kitchen)
end

return KitchenController

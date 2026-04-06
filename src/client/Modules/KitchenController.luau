--[[
    Module: KitchenController
    Description: Client-side controller that receives kitchen interaction signals from the server.

    This controller is intentionally minimal. Its only responsibility is to listen
    for server-fired signals related to kitchen interactions and route them to the
    appropriate client-side systems. UI feedback, sounds, and animations should be
    wired up here as those systems are built out.
--]]

---> Requires

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

---> Controller

local KitchenController = Knit.CreateController({
    Name = "KitchenController",
})

---> Lifecycle

function KitchenController:KnitStart()
    local KitchenService = Knit.GetService("KitchenService")

    KitchenService.InteractionFailed:Connect(function(itemName: string, reason: string)
        -- TODO: UI feedback (toast / dialog)
        -- TODO: Sound effect
        -- TODO: Client animation cancel
        warn("[KITCHEN] Interaction failed for", itemName, reason)
    end)
end

return KitchenController

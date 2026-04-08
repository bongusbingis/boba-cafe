--[[
    Module: OrderController
    Description: Knit controller that listens to OrderService server signals and
                 maintains client-side order state. React components subscribe to
                 the exposed GoodSignals rather than talking to the service directly.
--]]

---> Services

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local SharedStorage = ReplicatedStorage:WaitForChild("SharedStorage")

---> Dependencies

local Knit = require(Packages.Knit)
local GoodSignal = require(Packages.GoodSignal)

---> Controller

local OrderController = Knit.CreateController({
	Name = "OrderController",
})

local LocalPlayer = Players.LocalPlayer
local PickupBeam = SharedStorage.Effects.PickupBeam
local PlayerBeams = {}


OrderController.CurrentOrder = nil :: { any }? 
OrderController.ReadyNode = nil :: Instance?

OrderController.OrderChanged = GoodSignal.new()
OrderController.ReadyNodeChanged = GoodSignal.new()
OrderController.AnnouncementReceived = GoodSignal.new()

---> Lifecycle
function OrderController:KnitStart()
	local OrderService = Knit.GetService("OrderService")

	OrderService.NotepadUpdated:Connect(function(action: string, order: { any }?)
		if action == "SetNewOrder" then
			self.CurrentOrder = order
			self.OrderChanged:Fire(order)
		elseif action == "ResetOrder" then
			self.CurrentOrder = nil
			self.ReadyNode = nil
			self.OrderChanged:Fire(nil)
			self.ReadyNodeChanged:Fire(nil)
		end
	end)

	OrderService.PickUpNodeVisibilityChanged:Connect(function(node, isVisible: boolean, isReady: boolean?)
		node.ProximityPrompt.Enabled = isVisible
		if #PlayerBeams ~= 0 and isVisible == false then
			for num, beam in PlayerBeams do
				if beam.Attachment1.Parent == node then
					table.remove(PlayerBeams, num)
					beam.Attachment0:Destroy()
					beam.Attachment1:Destroy()
					beam:Destroy()
				end
			end
		end
		if isReady then
			local beam = PickupBeam:Clone()
			table.insert(PlayerBeams, beam)
			beam.Parent = LocalPlayer.Character.HumanoidRootPart

			local a0 = Instance.new("Attachment")
			local a1 = Instance.new("Attachment")
			a0.Parent = LocalPlayer.Character.HumanoidRootPart
			a1.Parent = node

			beam.Attachment0 = a0
			beam.Attachment1 = a1
		end
	end)

	OrderService.Announcement:Connect(function(title: string, body: string, color: Color3)
		self.AnnouncementReceived:Fire(title, body, color)
	end)
end

return OrderController

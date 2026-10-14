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

---> Dependencies

local Knit = require(Packages.Knit)
local GoodSignal = require(Packages.GoodSignal)
local WorldPath = require(ReplicatedStorage:WaitForChild("Shared").Utility.WorldPath)

---> Controller

local OrderController = Knit.CreateController({
	Name = "OrderController",
})

local LocalPlayer = Players.LocalPlayer

local PlayerBeams = {}
local Highlights = {}

OrderController.CurrentOrder = nil :: { any }?
OrderController.ReadyNode = nil :: Instance?
OrderController.QueuePosition = nil :: number? -- nil = not queued, 1 = next up

OrderController.OrderChanged = GoodSignal.new()
OrderController.ReadyNodeChanged = GoodSignal.new()
OrderController.AnnouncementReceived = GoodSignal.new()
OrderController.QueueChanged = GoodSignal.new() -- fires(position: number?)

---> Private

-- ReplicatedStorage.SharedStorage.Effects.PickupBeam is authored in the place. It
-- is looked up on use; when missing, the pick-up beam is skipped (warned once).
local warnedMissingBeam = false
local function getPickupBeam(): Beam?
	local beam = WorldPath.find(ReplicatedStorage, { "SharedStorage", "Effects", "PickupBeam" })
	if beam and beam:IsA("Beam") then
		return beam
	end
	if not warnedMissingBeam then
		warnedMissingBeam = true
		warn("[OrderController] SharedStorage.Effects.PickupBeam not found; pick-up beam disabled.")
	end
	return nil
end

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
		local character = LocalPlayer.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local pickupBeam = isReady and rootPart and getPickupBeam()
		if pickupBeam then
			local beam = pickupBeam:Clone()
			table.insert(PlayerBeams, beam)
			beam.Parent = rootPart

			local a0 = Instance.new("Attachment")
			local a1 = Instance.new("Attachment")
			a0.Parent = rootPart
			a1.Parent = node

			beam.Attachment0 = a0
			beam.Attachment1 = a1
		end
	end)

	OrderService.Announcement:Connect(function(title: string, body: string, color: Color3)
		self.AnnouncementReceived:Fire(title, body, color)
	end)

	OrderService.QueueUpdated:Connect(function(position: number?)
		self.QueuePosition = position
		self.QueueChanged:Fire(position)
	end)
end

-- Called by the OrderQueue UI button. Tells the server to remove this player
-- from the barista queue and clears local state immediately for responsiveness.
function OrderController:LeaveQueue()
	self.QueuePosition = nil
	self.QueueChanged:Fire(nil)
	Knit.GetService("OrderService"):LeaveQueue()
end

return OrderController

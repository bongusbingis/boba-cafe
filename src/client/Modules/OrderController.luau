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
local UiSfx = require(ReplicatedStorage:WaitForChild("Shared").UI.Utility.UiSfx)
local WorldPath = require(ReplicatedStorage:WaitForChild("Shared").Utility.WorldPath)

---> Controller

local OrderController = Knit.CreateController({
	Name = "OrderController",
})

local LocalPlayer = Players.LocalPlayer

local PlayerBeams = {}
local Highlights = {}
local DepositWatchers: { [Instance]: RBXScriptConnection } = {} -- node -> owner watcher while its deposit prompt is on

OrderController.CurrentOrder = nil :: { any }?
OrderController.Ticket = nil :: { [string]: any }? -- the NPC ticket from CustomerService
OrderController.Tickets = {} :: { { [string]: any } } -- up to 2 NPC tickets, ordered by Slot
OrderController._ticketsById = {} :: { [string]: { [string]: any } }
OrderController._notepadOrder = nil :: { any }? -- a real-player order wins over the ticket
OrderController.ReadyNode = nil :: Instance?
OrderController.QueuePosition = nil :: number? -- nil = not queued, 1 = next up

OrderController.OrderChanged = GoodSignal.new()
OrderController.TicketsChanged = GoodSignal.new() -- fires(tickets: { ticket })
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
			self._notepadOrder = order
			self.CurrentOrder = order
			self.OrderChanged:Fire(order)
		elseif action == "ResetOrder" then
			self._notepadOrder = nil
			self.CurrentOrder = self.Ticket
			self.ReadyNode = nil
			self.OrderChanged:Fire(self.CurrentOrder)
			self.ReadyNodeChanged:Fire(nil)
		end
	end)

	Knit.GetService("CustomerService").TicketChanged:Connect(function(ticket, slot)
		local byId = self._ticketsById
		if ticket ~= nil then
			-- A new ticket replaces whatever held its slot (or its own Id).
			for id, held in byId do
				if id == ticket.Id or held.Slot == (ticket.Slot or slot) then
					byId[id] = nil
				end
			end
			byId[ticket.Id] = ticket
		else
			for id, held in byId do
				if held.Slot == slot then
					byId[id] = nil
				end
			end
		end
		local list = {}
		for _, held in byId do
			table.insert(list, held)
		end
		table.sort(list, function(a, b)
			return (a.Slot or 1) < (b.Slot or 1)
		end)
		while #list > 2 do
			byId[list[#list].Id] = nil
			table.remove(list)
		end
		self.Tickets = list
		self.TicketsChanged:Fire(list)

		self.Ticket = list[1]
		if self._notepadOrder == nil then
			self.CurrentOrder = self.Ticket
			self.OrderChanged:Fire(self.Ticket)
		end
	end)

	OrderService.PickUpNodeVisibilityChanged:Connect(function(node, isVisible: boolean, isReady: boolean?)
		-- OrderOwner is the node's server-set owner: a node that is already filled never
		-- offers a deposit (the pick-up prompt for its owner is shown with isReady).
		local previousWatcher = DepositWatchers[node]
		if previousWatcher then
			previousWatcher:Disconnect()
			DepositWatchers[node] = nil
		end
		local ownerValue = node:FindFirstChild("OrderOwner")
		if isVisible and not isReady and ownerValue and ownerValue:IsA("IntValue") then
			if ownerValue.Value ~= 0 then
				isVisible = false
			else
				-- Another barista may fill the node while this prompt is showing.
				DepositWatchers[node] = ownerValue:GetPropertyChangedSignal("Value"):Connect(function()
					if ownerValue.Value ~= 0 then
						node.ProximityPrompt.Enabled = false
					end
				end)
			end
		end
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

	-- Serve chime (SOUNDS D5): the serve toast is the client signal; pitch rises with combo.
	Knit.GetService("DialogService").NotificationSignal:Connect(function(n)
		if typeof(n) ~= "table" then
			return
		end
		local text = if typeof(n.Text) == "string" and n.Text ~= ""
			then n.Text
			else (n.Title or "") .. " " .. (n.Description or "")
		if string.sub(text, 1, 13) ~= "Order served!" then
			return
		end
		local comboN = tonumber(string.match(text, "Combo ×(%d+)"))
		UiSfx.Play("Serve", { Speed = UiSfx.ServeSpeed(comboN) })
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

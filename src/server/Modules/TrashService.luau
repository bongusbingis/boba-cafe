---> services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Knit = require(Packages.Knit)
local Styles = require(Shared.UI.Styles)

---> constants
local CAN_TAG = "TrashCan"
local MAX_DISTANCE = 12
local BUILT_BY = "REVIVAL-001-TRASH"

---> module declaration
local TrashService = Knit.CreateService({ Name = "TrashService", Client = {} })
TrashService._busy = {} :: { [Player]: boolean }
TrashService._prompts = {} :: { [Instance]: ProximityPrompt }

local function getDialogService()
	return Knit.GetService("DialogService")
end

local function getCanPart(can: Instance): BasePart?
	if can:IsA("BasePart") then
		return can
	end
	if can:IsA("Model") and can.PrimaryPart then
		return can.PrimaryPart
	end
	return can:FindFirstChildWhichIsA("BasePart", true)
end

local function getTool(player: Player): Tool?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Tool") or nil
end

local function notify(player: Player, description: string)
	getDialogService():Notify(player, {
		Title = "Trash",
		Description = description,
		Image = "",
		SoundEnabled = false,
	})
end

function TrashService:_onTriggered(player: Player, part: BasePart)
	if self._busy[player] then
		return
	end
	local tool = getTool(player)
	if not tool then
		notify(player, "Hold a drink to throw it away.")
		return
	end
	if tool:GetAttribute("NotDisposable") == true then
		notify(player, "You can't throw that away.")
		return
	end

	self._busy[player] = true
	getDialogService()
		:CreateDialog(player, "ButtonPrompt", {
			Title = "Throw Away?",
			Text = "This will discard what you are holding.",
			Buttons = {
				{ Text = "Yes", Color = Styles.GREEN },
				{ Text = "No", Color = Styles.RED },
			},
			OffsetX = 0.1,
		})
		:andThen(function(choice)
			if choice ~= "Yes" then
				return
			end
			local ok, err = pcall(function()
				if getTool(player) ~= tool or tool:GetAttribute("NotDisposable") == true then
					return
				end
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not root or not part.Parent then
					return
				end
				if ((root :: BasePart).Position - part.Position).Magnitude > MAX_DISTANCE then
					return
				end
				tool:Destroy()
			end)
			if not ok then
				warn("[TrashService]: Failed to discard tool for", player.Name, err)
			end
		end)
		:catch(function(err)
			warn("[TrashService]: Dialog failed for", player.Name, err)
		end)
		:finally(function()
			self._busy[player] = nil
		end)
end

function TrashService:_wireCan(can: Instance)
	if self._prompts[can] then
		return
	end
	local ok, err = pcall(function()
		local part = getCanPart(can)
		if not part then
			warn("[TrashService]: Tagged can has no BasePart:", can:GetFullName())
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Use"
		prompt.ObjectText = "Trash"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("BuiltBy", BUILT_BY)
		prompt.Triggered:Connect(function(player)
			self:_onTriggered(player, part)
		end)
		prompt.Parent = part
		self._prompts[can] = prompt
	end)
	if not ok then
		warn("[TrashService]: Failed to wire can", err)
	end
end

function TrashService:KnitStart()
	for _, can in CollectionService:GetTagged(CAN_TAG) do
		self:_wireCan(can)
	end
	CollectionService:GetInstanceAddedSignal(CAN_TAG):Connect(function(can)
		self:_wireCan(can)
	end)
	CollectionService:GetInstanceRemovedSignal(CAN_TAG):Connect(function(can)
		local prompt = self._prompts[can]
		if prompt then
			prompt:Destroy()
			self._prompts[can] = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self._busy[player] = nil
	end)
end

return TrashService

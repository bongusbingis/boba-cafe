--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)
local GoodSignal = require(Packages.GoodSignal)
local PetFollowerRenderer = require(script.Parent.Pets.PetFollowerRenderer)

local LocalPlayer = Players.LocalPlayer

local PetController = Knit.CreateController({
	Name = "PetController",
})

PetController.EquippedPetsByUserId = {} :: { [number]: { any } }
PetController.EquippedPetsChanged = GoodSignal.new()
PetController.LocalEquippedPetsChanged = GoodSignal.new()
PetController._renderer = nil

local function cloneList(list: { any }?): { any }
	if typeof(list) ~= "table" then
		return {}
	end

	local copied = table.clone(list)
	for i, value in copied do
		if typeof(value) == "table" then
			copied[i] = table.clone(value)
		end
	end

	return copied
end

function PetController:GetEquippedPetsForUserId(userId: number): { any }
	return self.EquippedPetsByUserId[userId] or {}
end

function PetController:GetLocalEquippedPets(): { any }
	return self:GetEquippedPetsForUserId(LocalPlayer.UserId)
end

function PetController:PlayerRemoving(player: Player)
	if self.EquippedPetsByUserId[player.UserId] ~= nil then
		self.EquippedPetsByUserId[player.UserId] = nil
		self.EquippedPetsChanged:Fire(player.UserId, {})
	end

	if self._renderer then
		self._renderer:RemoveFollower(player.UserId)
	end
end

function PetController:KnitStart()
	local PetService = Knit.GetService("PetService")
	self._renderer = PetFollowerRenderer.new(LocalPlayer)

	PetService:GetAllEquippedPetsAsync():andThen(function(snapshotByUser)
		self.EquippedPetsByUserId = {}
		for userId, equippedPets in snapshotByUser do
			local copied = cloneList(equippedPets)
			self.EquippedPetsByUserId[userId] = copied
			if self._renderer then
				self._renderer:SyncEquippedPets(userId, copied)
			end
		end

		self.LocalEquippedPetsChanged:Fire(self:GetLocalEquippedPets())
	end):catch(function(err)
		warn("[PetController]: Failed to fetch initial equipped pets snapshot", err)
	end)

	PetService.EquippedPetsChanged:Connect(function(userId: number, equippedPets: { any })
		local copied = cloneList(equippedPets)
		self.EquippedPetsByUserId[userId] = copied
		if self._renderer then
			self._renderer:SyncEquippedPets(userId, copied)
		end
		self.EquippedPetsChanged:Fire(userId, copied)

		if userId == LocalPlayer.UserId then
			self.LocalEquippedPetsChanged:Fire(copied)
		end
	end)
end

function PetController:Destroy()
	if self._renderer then
		self._renderer:Destroy()
		self._renderer = nil
	end

	self.EquippedPetsChanged:DisconnectAll()
	self.LocalEquippedPetsChanged:DisconnectAll()
end

return PetController
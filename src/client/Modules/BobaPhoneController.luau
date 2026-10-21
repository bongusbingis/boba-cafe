--[[
	BobaPhoneController (REVIVAL-001 BOBA-PHONE D11)
	Equip-driven overlay for the Boba Phone Tool. Renders Pages/BobaPhone into
	a separate BobaPhoneReact ScreenGui (NOT through App/SetCurrentPage, so it
	coexists with the HUD and the Ordering tablet). Equipped = open,
	Unequipped or phone removal = close.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)

local BobaPhone = require(Shared.UI.Pages.BobaPhone)

local BobaPhoneController = Knit.CreateController({
	Name = "BobaPhoneController",
})

local TOOL_ATTRIBUTE = "BobaPhone"

local function isPhoneTool(instance: Instance?): boolean
	return instance ~= nil and instance:IsA("Tool") and instance:GetAttribute(TOOL_ATTRIBUTE) == true
end

function BobaPhoneController:KnitStart()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "BobaPhoneReact"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 1
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = ReactRoblox.createRoot(gui)
	local open = false

	local function render()
		root:render(React.createElement(BobaPhone, {
			Open = open,
			OnClose = function()
				open = false
				render()
			end,
		}))
	end

	local function setOpen(value: boolean)
		if open ~= value then
			open = value
			render()
		end
	end

	local _connections: { RBXScriptConnection } = {}
	local watchedTools: { [Tool]: boolean } = {}

	local function watchTool(tool: Tool)
		if watchedTools[tool] then
			return
		end
		watchedTools[tool] = true
		table.insert(
			_connections,
			tool.Equipped:Connect(function()
				setOpen(true)
			end)
		)
		table.insert(
			_connections,
			tool.Unequipped:Connect(function()
				setOpen(false)
			end)
		)
		table.insert(
			_connections,
			tool.Destroying:Connect(function()
				watchedTools[tool] = nil
				setOpen(false)
			end)
		)
	end

	local function watchContainer(container: Instance)
		for _, child in container:GetChildren() do
			if isPhoneTool(child) then
				watchTool(child :: Tool)
			end
		end
		table.insert(
			_connections,
			container.ChildAdded:Connect(function(child)
				if isPhoneTool(child) then
					watchTool(child :: Tool)
				end
			end)
		)
		table.insert(
			_connections,
			container.ChildRemoved:Connect(function(child)
				if isPhoneTool(child) then
					setOpen(false)
				end
			end)
		)
	end

	local function watchCharacter(character: Model?)
		if character then
			-- An already-equipped phone (KnitStart after respawn) opens at once.
			local held = character:FindFirstChildWhichIsA("Tool")
			if isPhoneTool(held) then
				setOpen(true)
			end
			watchContainer(character)
		end
	end

	render()
	watchCharacter(player.Character)
	table.insert(_connections, player.CharacterAdded:Connect(watchCharacter))
	table.insert(
		_connections,
		player.CharacterRemoving:Connect(function()
			setOpen(false)
		end)
	)
end

return BobaPhoneController

---> services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local UI = Shared:WaitForChild("UI")

local Dialogs = UI.Components.Dialogs
local Styles = require(UI.Styles)
local UiSfx = require(UI.Utility.UiSfx)
local SmallNotification = require(UI.Components.Core.Hud.SmallNotification)

---> dependencies
local Knit = require(Packages.Knit)
local React = require(Packages.React)
local ReactRoblox = require(Packages.ReactRoblox)
local Promise = require(Packages.Promise)
local GoodSignal = require(Packages.GoodSignal)

---> module declaration
local DialogController = Knit.CreateController({
	Name = "DialogController",
})
DialogController.Prototype = {}
-- fires(pageKey: string?). App opens Shop on that tab (BobaBucksShortfall "Get Boba Bucks").
DialogController.OpenShopRequested = GoodSignal.new()
DialogController.OpenInventoryRequested = GoodSignal.new()

---> private
local c = React.createElement
local joinDicts = require(UI.Utility.joinDicts)
local dialogEvent = GoodSignal.new()

-- UI sounds are authored in the place (SoundService.SFX.UI, else SoundService.UISounds).
-- They are looked up on use, and a missing sound is skipped.
local function playUiSound(name: string)
	UiSfx.Play(name)
end

---> constants
-- TUNING: the pulse on the dialog button the current recipe step wants (M1.5d).
local PULSE_THICKNESS = 4
local PULSE_TWEEN = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local PULSE_FIND_ATTEMPTS = 10 -- the dialog renders a frame or two after it is queued
local PULSE_FIND_INTERVAL = 0.1
local HINT_INTERVAL = 15
local HINT_NATIVE = {
	Size = UDim2.fromScale(0.65, 0.05),
	Position = UDim2.fromScale(0.5, 0.075),
	AnchorPoint = Vector2.new(0.5, 0),
	ZIndex = 0,
}

---> types
type Dialog = {
	id: string?,
	type: string,
	props: { [string]: any },
	onResolution: (any?) -> ()?, ---> client only
}

type DialogObject = typeof(setmetatable({} :: Dialog, { __index = DialogController.Prototype }))

type QueueItem = {
	Dialog: Dialog,
	Component: any,
}

type Queue = { QueueItem }

local priorityGui: ScreenGui? = nil
local pulseToken = 0
local activePulse: { Tween: Tween, Stroke: UIStroke }? = nil

local function clearPulse()
	pulseToken += 1
	if activePulse then
		activePulse.Tween:Cancel()
		activePulse.Stroke:Destroy()
		activePulse = nil
	end
end

-- The guided choice for the open dialog, or nil. Never errors: guidance is optional.
local function currentChoice(): string?
	local ok, choice = pcall(function()
		return Knit.GetController("KitchenController"):GetCurrentChoice()
	end)
	return if ok and typeof(choice) == "string" then choice else nil
end

-- Finds the button whose label reads `choice` (size, coffee and food pickers all label a
-- button with the choice) and pulses a gold outline on it. If no button matches, nothing happens.
local function pulseChoice(choice: string)
	clearPulse()
	local token = pulseToken
	task.spawn(function()
		for _ = 1, PULSE_FIND_ATTEMPTS do
			if token ~= pulseToken or priorityGui == nil then
				return
			end
			for _, descendant in priorityGui:GetDescendants() do
				if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and descendant.Text == choice then
					local button = descendant:FindFirstAncestorWhichIsA("GuiButton")
						or (if descendant:IsA("TextButton") then descendant else nil)
					if button then
						local stroke = Instance.new("UIStroke")
						stroke.Name = "GuidePulse"
						stroke.Color = Styles.GOLD
						stroke.Thickness = PULSE_THICKNESS
						stroke.Transparency = 0
						stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
						stroke.Parent = button
						local tween = TweenService:Create(stroke, PULSE_TWEEN, { Transparency = 0.8 })
						tween:Play()
						activePulse = { Tween = tween, Stroke = stroke }
						return
					end
				end
			end
			task.wait(PULSE_FIND_INTERVAL)
		end
	end)
end

local function formatBrackets(str: string): string
	return str:gsub("%[(.-)%]", " <font color='#f5c242'>%1</font> ")
		:gsub("%|(.-)%|", " <font color='#fa2545'>%1</font> ")
end

local function dialogHolder()
	local queue: Queue, setQueue = React.useState({})
	local dialogOnScreen, setDialogOnScreen = React.useState(nil)

	React.useEffect(function()
		dialogEvent:Connect(function(dialog: Dialog, isCancel: boolean)
			if isCancel then
				setQueue(function(oldQueue: Queue)
					local newQueue = table.clone(oldQueue)
					for k, item in newQueue do
						if item.Dialog.id == dialog.id then
							table.remove(newQueue, k)
						end
					end
					return newQueue
				end)
				return
			end

			local dialogComponent: ModuleScript = Dialogs:FindFirstChild(dialog.type)
			if not dialogComponent then
				error("[CRITICAL] Unknown dialog type; must exist in Shared -> UI -> Components -> Dialogs")
				return
			end

			setQueue(function(oldQueue: Queue)
				local newQueue = table.clone(oldQueue)
				table.insert(newQueue, {
					Dialog = dialog,
					Component = require(dialogComponent),
				})
				return newQueue
			end)
		end)
	end, {})

	React.useEffect(function()
		clearPulse()
		if queue[1] then
			local current = queue[1]
			local choice = currentChoice()
			if choice then
				pulseChoice(choice)
			end
			setDialogOnScreen(c(
				current.Component,
				joinDicts({
					OnResolution = function(value: any, doNotSendToServer: boolean?)
						if current.Dialog.onResolution then
							current.Dialog.onResolution(value)
						elseif doNotSendToServer == nil then
							local dialogService = Knit.GetService("DialogService")
							dialogService.DialogSignal:Fire("Resolve", { id = current.Dialog.id, value = value })
						end
						setQueue(function(oldQueue: Queue)
							local newQueue = table.clone(oldQueue)
							table.remove(newQueue, 1)
							return newQueue
						end)
					end,
				}, current.Dialog.props)
			))
		else
			setDialogOnScreen(nil)
		end
	end, { queue })

	return c("Frame", {
		ZIndex = math.huge,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, { dialogOnScreen })
end

function DialogController.Prototype.Destroy(self: DialogObject, resolveTo: any)
	dialogEvent:Fire(self, true)
	self.onResolution(resolveTo or nil)
	table.clear(self)
	self = nil
end

function DialogController.Prototype.Fire(self: DialogObject)
	playUiSound("Pop1")
	return Promise.new(function(resolve, _)
		self.onResolution = resolve
		dialogEvent:Fire(self)
	end):finally(function()
		playUiSound("Pop2")
	end)
end

function DialogController.new(type: string, props: {}): DialogObject
	return setmetatable({
		type = type,
		props = props,
	}, { __index = DialogController.Prototype })
end

DialogController.FormatBrackets = formatBrackets

--[=[
	Pushes a toast notification from the client side.
	Mirror of DialogService:Notify on the server.
]=]
function DialogController:Notify(
	notification: { Title: string, Description: string, Image: string, SoundEnabled: boolean? }
)
	SmallNotification.Push(notification)
end

--[[
	Pushes a plain-text toast (SmallNotification takes `Text`; Notify's Title and Description
	are not read by it). Used for "Next: <step>" and the Clock In reminder.
]]
function DialogController:Toast(text: string)
	SmallNotification.Push({ Text = text })
end

function DialogController:KnitInit()
	local handle = Instance.new("ScreenGui")
	handle.Name = "Priority"
	handle.DisplayOrder = 100
	handle.ResetOnSpawn = false
	handle.Parent = Players.LocalPlayer.PlayerGui
	priorityGui = handle

	local root = ReactRoblox.createRoot(handle)
	root:render(c(dialogHolder))

	local DialogService = Knit.GetService("DialogService")
	DialogService.DialogSignal:Connect(function(action, ...)
		if action == "CreateDialog" then
			local dialog: Dialog = ...
			dialogEvent:Fire(dialog)
		elseif action == "OpenShop" then
			DialogController.OpenShopRequested:Fire(...)
		end
	end)
	DialogService.NotificationSignal:Connect(function(notification)
		SmallNotification.Push(notification)
	end)
end

return DialogController

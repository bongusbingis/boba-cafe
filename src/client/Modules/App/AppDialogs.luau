---> services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local UI = Shared:WaitForChild("UI")

local Dialogs = UI.Components.Dialogs
local Styles = require(UI.Styles)
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

---> private
local c = React.createElement
local joinDicts = require(UI.Utility.joinDicts)
local dialogEvent = GoodSignal.new()

---> constants
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
		if queue[1] then
			local current = queue[1]
			setDialogOnScreen(c(
				current.Component,
				joinDicts({
					OnResolution = function(value: any, doNotSendToServer: boolean?)
						if current.Dialog.onResolution then
							current.Dialog.onResolution(value)
						elseif doNotSendToServer == nil then
                            local dialogService = Knit.GetService("DialogService")
                            dialogService.DialogSignal:Fire("Resolve", {id = current.Dialog.id, value = value})
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
	return Promise.new(function(resolve, _)
		self.onResolution = resolve
		dialogEvent:Fire(self)
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
function DialogController:Notify(notification: { Title: string, Description: string, Image: string, SoundEnabled: boolean? })
	SmallNotification.Push(notification)
end

function DialogController:KnitInit()
	local handle = Instance.new("ScreenGui")
	handle.Name = "Priority"
	handle.DisplayOrder = 100
	handle.ResetOnSpawn = false
	handle.Parent = Players.LocalPlayer.PlayerGui

	local root = ReactRoblox.createRoot(handle)
	root:render(c(dialogHolder))

	local DialogService = Knit.GetService("DialogService")
	DialogService.DialogSignal:Connect(function(action, ...)
		if action == "CreateDialog" then
			local dialog: Dialog = ...
			dialogEvent:Fire(dialog)
		end
	end)
	DialogService.NotificationSignal:Connect(function(notification)
		SmallNotification.Push(notification)
	end)
end

return DialogController

---> services
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Dialogs = Shared.UI.Components.Dialogs

---> dependencies
local Knit = require(Packages.Knit)
local Promise = require(Packages.Promise)

---> module declaration
local DialogService = Knit.CreateService({
	Name = "DialogService",
	Client = {
		DialogSignal = Knit.CreateSignal(),
	},
})

---> types
type OnResolution = {
	id: string,
	value: any,
}

type Props = { [string]: any }

type PendingDialog = {
	Player: Player,
	Dialog: {
		id: string,
		type: string,
		props: Props,
	},
	Resolve: (any) -> (),
	CreatedAt: number,
	Timeout: number?,
}

local pendingDialogs: { [string]: PendingDialog } = {}
local function formatBrackets(str: string): string
	return str:gsub("%[(.-)%]", " <font color='#f5c242'>%1</font> ")
end

---> public
DialogService.PropBuilders = {}

function DialogService:CreateDialog(player: Player, type: string, props: Props, timeout: number?)
	return Promise.new(function(resolve, reject)
		local dialogComponent: ModuleScript = Dialogs:FindFirstChild(type)
		if not dialogComponent then
			reject("[CRITICAL] Unknown dialog type; must exist in Shared -> UI -> Components -> Dialogs")
			return
		end

		local uniqueId = HttpService:GenerateGUID(false)
		local dialog = {
			id = uniqueId,
			type = type,
			props = props,
		}

		DialogService.Client.DialogSignal:Fire(player, "CreateDialog", dialog)
		pendingDialogs[uniqueId] = {
			Player = player,
			Dialog = dialog,
			Resolve = resolve,
			CreatedAt = os.time(),
			Timeout = timeout or 120,
		}
	end)
end

function DialogService.PlayerRemoving(player: Player)
	for id, pendingDialog in pendingDialogs do
		if pendingDialog.Player == player then
			pendingDialog.Resolve(nil)
			pendingDialogs[id] = nil
		end
	end
end

function DialogService:KnitStart()
	while task.wait(1) do
		for id, pendingDialog in pendingDialogs do
			if not pendingDialog.Timeout then
				continue
			end
			if os.time() - pendingDialog.CreatedAt > pendingDialog.Timeout then
				pendingDialog.Resolve(nil)
				pendingDialogs[id] = nil
			end
		end
	end
end

function DialogService:KnitInit()
	self.Client.DialogSignal:Connect(function(player: Player, action: string, ...)
		if action == "Resolve" then
			local data: OnResolution = ...
			self:Resolve(player, data)
		end
	end)
end

function DialogService:Resolve(player: Player, data: OnResolution)
	local pending = pendingDialogs[data.id]
	if pending and pending.Player == player then
		pending.Resolve(data.value)
	end
end

DialogService.FormatBrackets = formatBrackets

return DialogService

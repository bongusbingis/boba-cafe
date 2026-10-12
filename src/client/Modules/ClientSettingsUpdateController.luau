---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Knit = require(Packages.Knit)
local SettingsConfig = require(Shared.Configuration.SettingsConfig)

---> module declaration
local ClientSettingsUpdateController = Knit.CreateController({
	Name = "ClientSettingsUpdateController",
	Applied = {},
})

---> private

--- Flat key -> setting definition, so callbacks resolve without rescanning categories.
local settingsByKey = {}
for _, category in SettingsConfig do
	for _, setting in category.Settings do
		settingsByKey[setting.Key] = setting
	end
end

--- Runs a setting's ClientCallback, guarding against one bad callback stopping the rest.
function ClientSettingsUpdateController:_apply(key: string, value: any)
	local definition = settingsByKey[key]
	if not definition or not definition.ClientCallback then
		return
	end

	-- Action settings fire on press, not on value change.
	if definition.Type == "Action" then
		return
	end

	local ok, err = pcall(definition.ClientCallback, value)
	if not ok then
		warn(`[ClientSettingsUpdateController] '{key}' callback failed: {err}`)
	end
end

--- Applies every setting whose stored value differs from what was last applied.
function ClientSettingsUpdateController:_sync(settings: { [string]: any })
	if typeof(settings) ~= "table" then
		return
	end

	for key, value in settings do
		if self.Applied[key] ~= value then
			self.Applied[key] = value
			self:_apply(key, value)
		end
	end
end

---> lifecycle

function ClientSettingsUpdateController:KnitStart()
	task.spawn(function()
		local dataController = Knit.GetController("DataController")
		if not dataController or not dataController.GetDataAsync then
			warn("[ClientSettingsUpdateController] DataController unavailable; settings not applied.")
			return
		end

		-- Takes no argument: it always resolves the local player's replica.
		local ok, replica = dataController:GetDataAsync():await()
		if not ok or not replica then
			return
		end

		self:_sync(replica.Data and replica.Data.Settings)

		-- Re-apply whenever the profile's Settings table changes.
		if replica.ListenToChange then
			replica:ListenToChange({ "Settings" }, function()
				self:_sync(replica.Data and replica.Data.Settings)
			end)
		end
	end)
end

return ClientSettingsUpdateController

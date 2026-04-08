--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(ReplicatedStorage.Packages.React)

local Page = require(UI.Components.Core.Page)
local CoreCapsuleOpening = require(UI.Components.Core.CapsuleOpening)

local c = React.createElement

type CapsuleOpeningData = {
	CapsuleImage: string,
	Reward: any,
	ItemType: string,
	IsInstant: boolean,
}

return function(props: {
	Capsule: CapsuleOpeningData,
	OnResolution: (any?) -> (),
})
	local closeFnRef = React.useRef(nil)

	return c(Page, {
		IsVisible = true,
		OnClosing = function(callback)
			closeFnRef.current = callback
		end,
		PageContent = c(CoreCapsuleOpening, {
			Capsule = props.Capsule,
			OnOpened = function()
				if closeFnRef.current then
					closeFnRef.current()
				end
				props.OnResolution(nil)
			end,
		}),
	})
end

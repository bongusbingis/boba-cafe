--[[
    Dialog: Darken
    Description: A full-screen dim, used to focus attention on something in the world
    (a cutscene, a highlighted station) rather than on other UI.

    Resolves when clicked unless Dismissible is false, in which case the server closes
    it by resolving the dialog itself.

    Props: Transparency?, Dismissible?, Duration?, OnResolution
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

---> dependencies
local React = require(Packages.React)
local ReactSpring = require(Packages.ReactSpring)

---> styles
local Styles = require(UI.Styles)

---> private
local c = React.createElement

---> public
return function(props: {
	Transparency: number?,
	Dismissible: boolean?,
	Duration: number?,
	OnResolution: (string) -> (),
})
	local target = props.Transparency or 0.4
	local dismissible = props.Dismissible ~= false

	-- Table form, matching how the rest of the codebase calls useSpring (see ItemCard).
	-- Starts fully transparent on mount and settles to the target so the dim fades in.
	local mounted, setMounted = React.useState(false)

	React.useEffect(function()
		setMounted(true)
	end, {})

	local styles = ReactSpring.useSpring({
		transparency = if mounted then target else 1,
		config = Styles.SPRING_STANDARD,
	})

	-- Optional auto-close, for uses that are purely a timed effect.
	React.useEffect(function()
		if not props.Duration then
			return
		end

		local cancelled = false
		task.delay(props.Duration, function()
			if not cancelled then
				props.OnResolution("Timeout")
			end
		end)

		return function()
			cancelled = true
		end
	end, { props.Duration })

	return c("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = styles.transparency,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		-- Sits behind other dialogs but above the rest of the UI.
		ZIndex = 0,
		[React.Event.Activated] = dismissible and function()
			props.OnResolution("Close")
		end or nil,
	})
end

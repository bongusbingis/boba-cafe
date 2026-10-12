--[[
    Hook: usePolicy
    Description: Reads the local player's Roblox policy info from the server's
    PolicyService.

    Returns `restricted: boolean` for paid random items (capsules), and `loaded: boolean`
    so callers can tell "not known yet" from "known to be unrestricted".

    `restricted` starts TRUE. Until the real answer arrives the UI must assume the player
    is restricted — offering a gacha shop to a restricted player is a policy violation,
    while briefly showing the direct-purchase shop to everyone else is harmless.

    The lookup is server-side and cached per session, so this is one remote call.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local React = require(Packages.React)
local Knit = require(Packages.Knit)

export type Policy = {
	restricted: boolean,
	loaded: boolean,
}

return function(): Policy
	local restricted, setRestricted = React.useState(true)
	local loaded, setLoaded = React.useState(false)

	React.useEffect(function()
		local cancelled = false

		task.spawn(function()
			local ok, policyService = pcall(Knit.GetService, Knit, "PolicyService")
			if not ok or not policyService then
				-- No service: stay restricted, but stop showing a loading state.
				if not cancelled then
					setLoaded(true)
				end
				return
			end

			local fetched, policy = policyService:GetPolicy():await()

			if cancelled then
				return
			end

			if fetched and typeof(policy) == "table" then
				setRestricted(policy.ArePaidRandomItemsRestricted == true)
			end
			setLoaded(true)
		end)

		return function()
			cancelled = true
		end
	end, {})

	return {
		restricted = restricted,
		loaded = loaded,
	}
end

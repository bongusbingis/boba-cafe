--[[
    Module: AdBoardConfig
    Description: The in-world advertisement boards.

    V3 gave every board its own Script and its own hand-built SurfaceGui, so adding a
    board meant copying a model and editing Instances by hand. Everything is declared
    here instead: one config entry per board, one React component, one controller.

    Boards are matched by Model name inside the ads folder (see FOLDER_PATH). A board
    model is expected to contain:

        Part           header strip  — header SurfaceGui is adorned to this
        Union          body panel    — content SurfaceGui is adorned to this
        ClickDetector  purchase click
        MainColor      Color3Value, optional — overrides Color below

    Any SurfaceGui already sitting in the model is replaced at runtime, so the old
    hand-built ones can be deleted from the place.
--]]

local AdBoardConfig = {}

--- Where the boards live. Checked under workspace.
AdBoardConfig.FOLDER_PATH = { "Assets", "Advertisements" }

--- Fallback if the model has no MainColor value.
AdBoardConfig.DEFAULT_COLOR = Color3.fromRGB(102, 204, 255)

--- Rendering constants lifted from the original boards so the look is unchanged.
AdBoardConfig.HEADER_PIXELS_PER_STUD = 150
AdBoardConfig.BODY_PIXELS_PER_STUD = 100
AdBoardConfig.SURFACE_FACE = Enum.NormalId.Back
AdBoardConfig.BUTTON_IMAGE = "rbxassetid://2018256936"
AdBoardConfig.ROBUX_ICON = "http://www.roblox.com/asset/?id=4478299857"

--- Board definitions, keyed by Model name.
---
--- Kind:
---   "GamePass"   Subtitle defaults to "Game Pass"; price and icon come from Roblox
---   "Product"    developer product
---   "Celebrity"  the bespoke subscription board, see CELEBRITY below
---
--- Title/Description are optional overrides. When omitted the live Roblox name and
--- description are used, which is what V3 did.
AdBoardConfig.Boards = {
	["Barista"] = { Kind = "GamePass", Id = 6202153 },
	["Staff Intern"] = { Kind = "GamePass", Id = 15243046 },
	["Faster Walkspeed"] = { Kind = "GamePass", Id = 12385742 },
	["Instant Brewing"] = { Kind = "GamePass", Id = 12385760, Title = "Instant Brew" },
	["VIP"] = { Kind = "GamePass", Id = 12385781 },
	["Korblox"] = { Kind = "GamePass", Id = 12385818 },
	["Headless Head"] = { Kind = "GamePass", Id = 14067340 },
	["Rainbow Pack"] = { Kind = "GamePass", Id = 12385796 },
	["MopWhack"] = { Kind = "GamePass", Id = 40973940, Title = "Mop Whack" },
	["UnlimitedStock"] = { Kind = "GamePass", Id = 43707849, Title = "Unlimited Stock" },
	["Donate!"] = { Kind = "Product", Id = 0, Title = "Donate!" },
	["Celebrity"] = { Kind = "Celebrity" },

	-- "Fun Pass" (12385799) is deliberately absent — the Fun Pass is retired.
}

--- The Celebrity board sells timed subscriptions rather than a single pass, so it has
--- its own layout: a perks list and a row of duration tiles.
AdBoardConfig.CELEBRITY = {
	Color = Color3.fromRGB(255, 213, 128),
	Heading = "Why become a Celebrity?",
	Blurb = "Celebrities are the most elite type of customer here at Boba. They get unique perks to thank them for their unique support towards the group.",
	PerksHeading = "Perks of being a Celebrity:",
	Footer = "Become a Celebrity today!",

	Perks = {
		{
			Label = "Private Island",
			Description = "Have your own in-game customizable Private Island! Invite your friends and have fun!",
		},
		{
			Label = "Celebrity Tag",
			Description = "In-game Celebrity Overhead Tag and Chat Tag!",
		},
		{
			Label = "x3 Boba Bucks",
			Description = "Get x3 more Boba Bucks! This is stackable with other multiplicators.",
		},
		{
			Label = "Kitchen Access",
			Description = "Access to the Staff Kitchen without having to be a Staff Member.",
		},
		{
			Label = "Celebrity Admin",
			Description = "Gain access to the following commands:\n• :sit\n• :to <Player>\n• :view <Player>\n• :unview <Player>",
		},
		{
			Label = "Join Notification",
			Description = "A notification will pop up on everybody's screen when you join the server!",
		},
	},

	--- Purchase tiles, left to right. Premium has no product id — it is a perk of
	--- Roblox Premium rather than something you buy here.
	Tiers = {
		{ ProductId = 1128806440, Duration = "1 Month", Price = "500 Robux" },
		{ ProductId = 1143304035, Duration = "3 Months", Price = "1250 Robux" },
		{ ProductId = 1143304104, Duration = "6 Months", Price = "2250 Robux" },
		{
			ProductId = nil,
			Duration = "10 Days",
			Price = "Roblox Premium users get 10 days of Celebrity for FREE!",
			IsPremium = true,
		},
	},
}

return AdBoardConfig

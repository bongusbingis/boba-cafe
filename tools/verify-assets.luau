--[[
	verify-assets.luau — checks a place file against every instance path the code in
	src/ expects to exist at runtime.

	Usage:
		lune run tools/verify-assets.luau <place.rbxl>

	Compare two places (e.g. see what the old build has that the new one lacks):
		lune run tools/verify-assets.luau current-baseplate-build.rbxl
		lune run tools/verify-assets.luau old-v3.rbxl

	Every entry below is traceable to a real require/index in src/; the Source column in
	the printed report names the file that depends on it.
]]

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local placePath = process.args[1]
if not placePath then
	print("usage: lune run tools/verify-assets.luau <place.rbxl>")
	process.exit(1)
end

local game = roblox.deserializePlace(fs.readFile(placePath))

-- { path, requiredBy, kind }
-- kind: "hard" = code indexes it directly and will error if absent
--       "soft" = code guards with FindFirstChild / warns and degrades
local REQUIRED = {
	---> Workspace: ordering system
	{ "Workspace/Ordering System", "OrderService", "hard" },
	{ "Workspace/Ordering System/Computers", "OrderService (order terminals), OnboardingConfig (worker onboarding beacon)", "hard" },
	{ "Workspace/Ordering System/Status Screens", "OrderService:_updateStatusScreens", "hard" },
	{ "Workspace/Ordering System/Staff Screens", "OrderService:_updateStaffScreens", "hard" },
	{ "Workspace/Ordering System/Pick Up", "OrderService (pickup nodes)", "hard" },

	---> Workspace: kitchen
	{ "Workspace/Assets", "KitchenService, SpillService", "hard" },
	{ "Workspace/Assets/Kitchen", "KitchenService", "hard" },
	{ "Workspace/Assets/Kitchen/Givers", "KitchenService:_getMatchingModels", "hard" },
	{ "Workspace/Assets/Kitchen/Syrups", "KitchenService:_spawnSyrupDispensers", "hard" },

	---> Workspace: leaderboards
	{ "Workspace/Assets/Leaderboards", "LeaderboardService", "soft" },
	{ "Workspace/Assets/Leaderboards/Global", "LeaderboardService (all-time boards)", "soft" },
	{ "Workspace/Assets/Leaderboards/Monthly", "LeaderboardService (monthly boards)", "soft" },
	{ "Workspace/Assets/Leaderboards/Statues", "LeaderboardService (podium statues)", "soft" },

	---> Workspace: celebrity islands
	{ "Workspace/Assets/Celebrity", "CelebrityService", "soft" },
	{ "Workspace/Assets/Celebrity/IslandTemplate", "CelebrityService:LoadIsland", "soft" },
	{ "Workspace/Assets/Celebrity/Spawns", "CelebrityService (island plots)", "soft" },

	---> Workspace: spills
	{ "Workspace/Assets/Spills", "SpillService, SpillController", "hard" },
	{ "Workspace/ActiveSpills", "SpillService (runtime spill parent)", "soft" },

	---> ReplicatedStorage: networking
	{ "ReplicatedStorage/Networking", "Inventory, PromoCodes, RankClaiming", "hard" },
	{ "ReplicatedStorage/Networking/InventoryEvent", "InventoryClient/InventoryServer", "hard" },
	{ "ReplicatedStorage/Networking/GetPurchases", "ProcessReceipt, Purchases page", "hard" },
	{ "ReplicatedStorage/Networking/RedeemCode", "PromoCodes", "hard" },
	{ "ReplicatedStorage/Networking/ClaimRank", "RankClaiming, SettingsConfig", "hard" },

	---> ReplicatedStorage: shared storage
	{ "ReplicatedStorage/SharedStorage", "many", "hard" },
	{ "ReplicatedStorage/SharedStorage/Tools", "Recipes, RecipeConstructors", "hard" },
	{ "ReplicatedStorage/SharedStorage/Tools/Kitchen", "Recipes (Tools.Kitchen)", "hard" },
	{ "ReplicatedStorage/SharedStorage/Tools/Kitchen/Cups", "makeCupGiver", "hard" },
	{ "ReplicatedStorage/SharedStorage/Tools/Kitchen/Mop Whack", "MopWhackService", "hard" },
	{ "ReplicatedStorage/SharedStorage/Animations", "Recipes (AllAnimations)", "hard" },
	{ "ReplicatedStorage/SharedStorage/Animations/Kitchen", "RecipeConstructors", "hard" },
	{ "ReplicatedStorage/SharedStorage/Animations/TemporaryItems", "Animate action props", "hard" },
	{ "ReplicatedStorage/SharedStorage/Animations/TemporaryItems/Spoon_01", "SCOOP_ANIMATION", "hard" },
	{ "ReplicatedStorage/SharedStorage/Animations/TemporaryItems/BlenderLid_01", "BLENDER_ANIMATION", "hard" },
	{ "ReplicatedStorage/SharedStorage/Animations/TemporaryItems/Milk_01", "MILK_ANIMATION", "hard" },
	{ "ReplicatedStorage/SharedStorage/Animations/ScoopAnimation_01", "SCOOP_ANIMATION", "hard" },
	{ "ReplicatedStorage/SharedStorage/Animations/BlenderAnimation_01", "BLENDER_ANIMATION", "hard" },
	{ "ReplicatedStorage/SharedStorage/Animations/MilkAnimation_01", "MILK_ANIMATION", "hard" },
	{ "ReplicatedStorage/SharedStorage/Animations/Kitchen/GrabAnimation_01", "makeCupGiver, makeGrabSelector", "hard" },
	{ "ReplicatedStorage/SharedStorage/Effects", "OrderController", "hard" },
	{ "ReplicatedStorage/SharedStorage/Effects/PickupBeam", "OrderController", "hard" },
	{ "ReplicatedStorage/SharedStorage/Spills", "SpillService, SpillController", "hard" },
	{ "ReplicatedStorage/SharedStorage/Pets", "InventoryItemDefinitions.Pets", "hard" },
	{ "ReplicatedStorage/SharedStorage/Nametags", "CosmeticsService", "soft" },

	---> NPC customers (ported from V4)
	{ "ReplicatedStorage/SharedStorage/NPC", "CustomerService", "soft" },
	{ "ReplicatedStorage/SharedStorage/NPC/Characters", "customer appearances", "soft" },
	{ "ReplicatedStorage/SharedStorage/NPC/Overhead", "customer name tag", "soft" },
	{ "ReplicatedStorage/SharedStorage/NPC/InUse", "spawned customer parent", "soft" },
	-- Not in the build yet: copy from boba-v4 ReplicatedStorage/SharedStorage/NPCStorage/Rig
	{ "ReplicatedStorage/SharedStorage/NPC/Rig", "customer body (COPY FROM V4)", "soft" },
	{ "ReplicatedStorage/SharedStorage/UIModules", "legacy UI", "soft" },

	---> ReplicatedStorage: selector models
	{ "ReplicatedStorage/SelectorModels", "Menu, PromptSelection, kitchen actions", "hard" },
	{ "ReplicatedStorage/SelectorModels/Kitchen", "KitchenService", "hard" },
	{ "ReplicatedStorage/SelectorModels/Kitchen/SyrupDispenser", "KitchenService:_spawnSyrupDispensers", "hard" },
	{ "ReplicatedStorage/SelectorModels/Fruits Cups", "AddFruit", "hard" },
	{ "ReplicatedStorage/SelectorModels/Fruits Slices", "SmoothieLiquid", "hard" },
	{ "ReplicatedStorage/SelectorModels/Cup", "Menu (CUP_MODELS)", "hard" },
	{ "ReplicatedStorage/SelectorModels/Mochi", "Menu, Recipes", "hard" },
	{ "ReplicatedStorage/SelectorModels/Macaron", "Menu, Recipes", "hard" },
	{ "ReplicatedStorage/SelectorModels/Pastry", "Menu, Recipes", "hard" },
	{ "ReplicatedStorage/SelectorModels/IceCream", "Menu, Recipes", "hard" },
	{ "ReplicatedStorage/SelectorModels/Pool", "Menu", "soft" },

	---> SoundService
	{ "SoundService/SFX", "DataController, AppDialogs, SettingsConfig", "hard" },
	{ "SoundService/SFX/Kitchen", "InteractionRunner", "hard" },
	{ "SoundService/SFX/Kitchen/Pour", "Recipes (Sound = \"Pour\")", "hard" },
	{ "SoundService/SFX/Kitchen/Pop", "Recipes (Sound = \"Pop\")", "hard" },
	{ "SoundService/SFX/Kitchen/Powder", "Recipes (Sound = \"Powder\")", "hard" },
	{ "SoundService/SFX/Kitchen/Blender", "Recipes (Sound = \"Blender\")", "hard" },
	{ "SoundService/SFX/Kitchen/Machine", "Recipes (Sound = \"Machine\")", "hard" },
	{ "SoundService/SFX/Kitchen/IceCubes", "Recipes (Sound = \"IceCubes\")", "hard" },
	{ "SoundService/SFX/UI", "AppDialogs", "hard" },
	{ "SoundService/SFX/UI/Pop1", "ActionPrompt", "hard" },
	{ "SoundService/SFX/UI/Pop2", "ActionPrompt", "hard" },
	{ "SoundService/SFX/Trip_01", "SpillController:_Trip", "hard" },
	{ "SoundService/SFX/Trip_02", "SpillController:_Trip", "hard" },
	{ "SoundService/Music", "DataController, SettingsConfig", "hard" },
	{ "SoundService/Music/Background", "background music", "soft" },
}

local function resolve(path: string): Instance?
	local parts = {}
	for part in string.gmatch(path, "[^/]+") do
		table.insert(parts, part)
	end

	local ok, node = pcall(function()
		return game:GetService(parts[1])
	end)
	if not ok or not node then
		return nil
	end

	for i = 2, #parts do
		node = node:FindFirstChild(parts[i])
		if not node then
			return nil
		end
	end

	return node
end

local missingHard, missingSoft, present = {}, {}, 0

for _, entry in REQUIRED do
	local path, requiredBy, kind = entry[1], entry[2], entry[3]
	if resolve(path) then
		present += 1
	elseif kind == "hard" then
		table.insert(missingHard, { path, requiredBy })
	else
		table.insert(missingSoft, { path, requiredBy })
	end
end

print(string.format("Checked %s\n", placePath))
print(string.format("  present:      %d", present))
print(string.format("  MISSING hard: %d  (code indexes these directly — will error)", #missingHard))
print(string.format("  missing soft: %d  (guarded; degrades gracefully)", #missingSoft))

if #missingHard > 0 then
	print("\n=== MISSING (hard) ===")
	for _, m in missingHard do
		print(string.format("  %-62s  <- %s", m[1], m[2]))
	end
end

if #missingSoft > 0 then
	print("\n=== missing (soft) ===")
	for _, m in missingSoft do
		print(string.format("  %-62s  <- %s", m[1], m[2]))
	end
end

print("")

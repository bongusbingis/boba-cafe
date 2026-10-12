-- Executes the real ToolNameMatcher source against the kitchen naming chain.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local src = fs.readFile("src/shared/Kitchen/ToolNameMatcher.luau")
local chunk = luau.load(src, { environment = { warn = print, string = string, table = table } })
local M = chunk()

local pass, fail = 0, 0
local function check(label, actual, expected)
	if actual == expected then
		pass += 1
	else
		fail += 1
		print(string.format("  FAIL %s (got %s, want %s)", label, tostring(actual), tostring(expected)))
	end
end

local FRUITS_FREEZER = { "#Clear Cup", "!%[Fruit%]" }
local MILK = { "#Clear Cup|=Mug", "!%+ Milk" }
local SYRUP = { "#Cup %+ Milk" }
local BLENDER_SMOOTHIE = "#%[Fruit%] %+ Milk"
local BLENDER_MILK = "#Syrup"

print("smoothie chain: Clear Cup -> Freezer -> Milk -> Blender")
check("fresh cup enters freezer", M.matchesAll("Small Clear Cup", FRUITS_FREEZER), true)
check("fruit cup rejected by freezer", M.matchesAll("Small Clear Cup + [Fruit]", FRUITS_FREEZER), false)
check("fruit cup takes milk", M.matchesAll("Small Clear Cup + [Fruit]", MILK), true)
check("milked fruit cup -> smoothie branch", M.matchesEntry("Small Clear Cup + [Fruit] + Milk", BLENDER_SMOOTHIE), true)
check("milked fruit cup NOT flavored milk", M.matchesEntry("Small Clear Cup + [Fruit] + Milk", BLENDER_MILK), false)
check("no double milk", M.matchesAll("Small Clear Cup + [Fruit] + Milk", MILK), false)

print("flavored milk chain: Clear Cup -> Milk -> Syrup -> Blender")
check("milked cup takes syrup", M.matchesAll("Small Clear Cup + Milk", SYRUP), true)
check("syruped -> flavored milk branch", M.matchesEntry("Milk + Taro Syrup", BLENDER_MILK), true)
check("syruped NOT smoothie branch", M.matchesEntry("Milk + Taro Syrup", BLENDER_SMOOTHIE), false)

print("mug chain")
check("empty mug takes milk", M.matchesAll("Mug", MILK), true)
check("mug with milk refused", M.matchesAll("Mug + Steamed Milk", MILK), false)

print("regressions")
check("plain Cup is not a Clear Cup", M.matchesEntry("Small Cup", "#Clear Cup"), false)
check("no double milk on plain cup", M.matchesAll("Small Clear Cup + Milk", MILK), false)

-- Blender branch order: first match wins, so verify no cross-talk either way.
print("branch exclusivity")
local smoothieTool = "Small Clear Cup + [Fruit] + Milk"
local milkTool = "Milk + Taro Syrup"
check("smoothie tool matches exactly one branch", (M.matchesEntry(smoothieTool, BLENDER_SMOOTHIE) and not M.matchesEntry(smoothieTool, BLENDER_MILK)), true)
check("milk tool matches exactly one branch", (M.matchesEntry(milkTool, BLENDER_MILK) and not M.matchesEntry(milkTool, BLENDER_SMOOTHIE)), true)

print(string.format("\n%d passed, %d failed", pass, fail))
if fail > 0 then
	process.exit(1)
end

-- Cross-checks MigrationConfig alias targets against the real item definitions,
-- and reports which V4 item names survive the mapping.
local fs = require("@lune/fs")

local function namesFrom(path: string): { [string]: boolean }
	local src = fs.readFile(path)
	local names = {}
	-- Top-level `["Name"] = {` entries. Indentation is inconsistent in these files
	-- (mix of tabs and 4 spaces), so accept any leading horizontal whitespace.
	for name in string.gmatch(src, '\n[ \t]+%["([^"]+)"%] = {') do
		names[name] = true
	end
	return names
end

local function aliasesFrom(src: string, tableName: string): { [string]: string }
	local block = string.match(src, tableName .. "%s*=%s*{(.-)\n}")
	local map = {}
	if not block then
		return map
	end
	for from, to in string.gmatch(block, "(%w+)%s*=%s*\"([^\"]+)\"") do
		map[from] = to
	end
	return map
end

local configSrc = fs.readFile("src/shared/Configuration/MigrationConfig.luau")

local nametags = namesFrom("src/shared/Configuration/InventoryItemDefinitions/Nametags.luau")
local particles = namesFrom("src/shared/Configuration/InventoryItemDefinitions/Particles.luau")

local nametagAliases = aliasesFrom(configSrc, "MigrationConfig.NAMETAG_ALIASES")
local particleAliases = aliasesFrom(configSrc, "MigrationConfig.PARTICLE_ALIASES")

local failures = 0

local function checkAliases(label, aliases, definitions)
	print(`\n=== {label} alias targets ===`)
	local count, broken = 0, 0
	for from, to in aliases do
		count += 1
		if not definitions[to] then
			broken += 1
			failures += 1
			print(`  BROKEN  {from} -> {to}  (no such definition)`)
		end
	end
	print(`  {count} aliases, all targets valid: {broken == 0}`)
end

checkAliases("Nametag", nametagAliases, nametags)
checkAliases("Particle", particleAliases, particles)

-- Coverage: which V4 names resolve?
local v4Nametags = {
	"Red", "Blue", "Green", "Purple", "Cyan", "Black", "SunsetOrange", "Bubblegum",
	"BabyBlue", "Watermelon", "USA", "FrostedGlow", "Rainbow", "IcyEssence", "VIP",
	"Platinum", "Golden", "SunnyDay", "HarvestSun",
}

print("\n=== V4 nametag coverage ===")
local resolved, unresolved = 0, {}
for _, name in v4Nametags do
	local target = nametags[name] and name or nametagAliases[name]
	if target and nametags[target] then
		resolved += 1
	else
		table.insert(unresolved, name)
	end
end
print(`  {resolved}/{#v4Nametags} resolve`)
print(`  unresolved (will be skipped + logged): {table.concat(unresolved, ", ")}`)

local v4Particles = {
	"Macaron", "Popsicle", "Strawberry", "Orange", "Grapes", "Cherry", "Coffee",
	"Cookie", "Jelly", "Mochis", "SakuraPetals", "Bubbles", "Stinky", "Coquette",
}
print("\n=== V4 particle coverage (sample) ===")
local pResolved, pUnresolved = 0, {}
for _, name in v4Particles do
	local target = particles[name] and name or particleAliases[name]
	if target and particles[target] then
		pResolved += 1
	else
		table.insert(pUnresolved, name)
	end
end
print(`  {pResolved}/{#v4Particles} resolve`)
print(`  unresolved: {table.concat(pUnresolved, ", ")}`)

print(`\nbroken alias targets: {failures}`)

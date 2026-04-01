---> fonts
local FONT_FREDOKA = Font.new("rbxasset://fonts/families/FredokaOne.json")

---> greens
local GREEN = Color3.fromRGB(143, 169, 127) -- primary: shop title, purchase button bg
local GREEN_MID = Color3.fromRGB(138, 173, 125) -- staff/role card bg + stroke
local GREEN_DEEP = Color3.fromRGB(99, 129, 91) -- shadow, description text
local GREEN_LIGHT = Color3.fromRGB(150, 189, 136) -- icons, tab text, accents
local GREEN_DIM = Color3.fromRGB(136, 170, 122) -- category header tint
local GREEN_TEXT = Color3.fromRGB(159, 189, 140) -- topbar text labels
local GREEN_BADGE = Color3.fromRGB(72, 199, 116) -- trending badge

---> rose
local ROSE = Color3.fromRGB(255, 182, 193)
local ROSE_MID = Color3.fromRGB(230, 145, 165)
local ROSE_DEEP = Color3.fromRGB(180, 80, 100)
local ROSE_TEXT = Color3.fromRGB(110, 50, 65)

---> gold
local GOLD = Color3.fromRGB(255, 215, 37)
local GOLD_MID = Color3.fromRGB(255, 185, 30)
local GOLD_DEEP = Color3.fromRGB(188, 132, 0)
local GOLD_BADGE = Color3.fromRGB(232, 234, 121)

---> misc
local RED = Color3.fromRGB(255, 87, 90)
local CORAL = Color3.fromRGB(255, 107, 107)
local CREAM = Color3.fromRGB(253, 240, 190)
local GRAY = Color3.fromRGB(180, 180, 180)
local OFFWHITE = Color3.fromRGB(250, 250, 250)

---> corner radii
local CORNER_FULL = UDim.new(1, 0)
local CORNER_PILL = UDim.new(0.4, 0)
local CORNER_BUTTON = UDim.new(0.2, 0)
local CORNER_CARD = UDim.new(0.06, 0)

---> spring configs
local SPRING_STANDARD = { mass = 1, tension = 10000, friction = 150 }
local SPRING_CARD = { mass = 1, tension = 10000, friction = 200 }

return {
	FONT_FREDOKA = FONT_FREDOKA,

	GREEN = GREEN,
	GREEN_MID = GREEN_MID,
	GREEN_DEEP = GREEN_DEEP,
	GREEN_LIGHT = GREEN_LIGHT,
	GREEN_DIM = GREEN_DIM,
	GREEN_TEXT = GREEN_TEXT,
	GREEN_BADGE = GREEN_BADGE,

	ROSE = ROSE,
	ROSE_MID = ROSE_MID,
	ROSE_DEEP = ROSE_DEEP,
	ROSE_TEXT = ROSE_TEXT,

	GOLD = GOLD,
	GOLD_MID = GOLD_MID,
	GOLD_DEEP = GOLD_DEEP,
	GOLD_BADGE = GOLD_BADGE,

	RED = RED,
	CORAL = CORAL,
	CREAM = CREAM,
	GRAY = GRAY,
	OFFWHITE = OFFWHITE,

	CORNER_FULL = CORNER_FULL,
	CORNER_PILL = CORNER_PILL,
	CORNER_BUTTON = CORNER_BUTTON,
	CORNER_CARD = CORNER_CARD,

	SPRING_STANDARD = SPRING_STANDARD,
	SPRING_CARD = SPRING_CARD,
}

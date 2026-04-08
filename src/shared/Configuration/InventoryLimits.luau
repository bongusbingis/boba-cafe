local RunService = game:GetService("RunService")
local BASE_STORAGE = RunService:IsStudio() and 200 or 10

return {
	Equipped = {
		Nametags = 1,
		Pets = 1,
		Particles = 5,
	},
	Storage = {
		Nametags = BASE_STORAGE,
		Pets = BASE_STORAGE,
		Particles = BASE_STORAGE,
		Capsules = BASE_STORAGE,
	},
}

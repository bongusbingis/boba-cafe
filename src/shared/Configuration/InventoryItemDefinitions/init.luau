--!strict

return setmetatable({
	Nametags = require(script.Nametags),
	Pets = require(script.Pets),
	Capsules = require(script.Capsules),
}, { __index = {
	Tiers = require(script.Tiers),
} })

export type GamepassDefinition = {
	Name: string,
	Description: string,
	Icon: string,
}

local Gamepasses: { [number]: GamepassDefinition } = {
	[6202153] = {
		Name = "Barista",
		Rank = 8,
		Description = "Become a Barista immediately without having to train for it!",
		Icon = "rbxassetid://16709481934",
	},
	[15243046] = {
		Name = "Kitchen Leader",
		Rank = 10,
		Description = "Become a Kitchen Leader immediately without having to earn it!",
		Icon = "rbxassetid://16728123715",
	},
	[12385742] = {
		Name = "Faster Walk Speed",
		Description = "Increase your walk speed by 90%!",
		Icon = "rbxassetid://16728131311",
	},
	[12385760] = {
		Name = "Instant Brew",
		Description = "Create drinks 2x faster!",
		Icon = "rbxassetid://16728132011",
	},
	[12385781] = {
		Name = "VIP",
		Description = "Unlock exclusive VIP features including special patio access, 2x rewards, and a specialized chat color!",
		Icon = "rbxassetid://16728139086",
	},
	[29083693] = {
		Name = "Nametag Customizer",
		Description = "Customize your nametag with a variety of colors!",
		Icon = "rbxassetid://16728123607",
	},
	[219651061] = {
		Name = "Emote Pack",
		Description = "Enjoy a set of popular dances that make you stand out from the crowd!",
		Icon = "rbxassetid://16728123417",
	},
	[219650999] = {
		Name = "Star Employee",
		Description = "Unlock an exclusive benefits package to make your job easier!",
		Icon = "rbxassetid://16728123956",
	},
	[219651106] = {
		Name = "Flying Mop",
		Description = "Stand out from the crowd with your own flying mop to get around the cafe faster!",
		Icon = "rbxassetid://16728123822",
	},
	[219651224] = {
		Name = "Uniform Remover",
		Description = "Remove your uniform and wear your own style in the cafe!",
		Icon = "rbxassetid://16728123822",
	},
	[219651161] = {
		Name = "Water Pack",
		Description = "Buckle up and unleash the thrill as you conquer the waves!",
		Icon = "rbxassetid://16709440324",
	},
}

return Gamepasses

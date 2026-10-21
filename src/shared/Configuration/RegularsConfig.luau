--!strict
--[[
	RegularsConfig
	BIG-B5 Regulars collection: twelve named customers with a fixed look and a
	favourite drink. They sometimes walk in as normal NPC customers, greet the
	barista by name once they have met, and stamp the Regulars page (Menu) on
	every serve. Stamping all of them pays the completion reward once.

	DEC-058 Opus-set, Jack to tune: every name, look, favourite, line, the
	spawn chance and the reward below.

	Look: a fixed HumanoidDescription, applied server-side in the existing NPC spawn
	path (CustomerService/Npc.luau, Players:CreateHumanoidModelFromDescription; no
	separate models). Base indexes SharedStorage.NPCs.Characters (sorted by Name,
	wrapping) and supplies the clothing until Jack fills the IDs; every Description
	entry is a HumanoidDescription property set on top. 0 / "" are TODO placeholders
	(skipped): no catalog IDs are guessed. A failed build falls back to the normal look.
	Favourite: a CustomerConfig.ORDER_POOL Key (existing drinks only). Size is fixed.
	A barista below the favourite's level gets a normal pool order instead.
--]]

export type Look = {
	Base: number,
	Description: { [string]: any }?,
}

export type Regular = {
	Id: string,
	Name: string,
	Look: Look,
	Favourite: string,
	Size: string?,
}

local RegularsConfig = {
	-- DEC-058 Opus-set, Jack to tune
	SPAWN_CHANCE = 0.12, -- chance that a new (non-VIP, non-Karen) customer is a regular
	MIN_GAP_SECONDS = 60, -- server-wide minimum time between two regular spawns
	UNMET_BIAS = 0.6, -- chance to prefer a regular some clocked-in barista has not met yet
	REWARD_BOBA_BUCKS = 2500, -- completion reward, paid once
	REWARD_TITLE = "CafeFavourite", -- Titles.MANUAL_TITLES id granted on completion

	ROSTER = {
		{
			Id = "Mabel",
			Name = "Mabel",
			Look = {
				Base = 1,
				Description = {
					HeadColor = Color3.fromRGB(255, 224, 189),
					TorsoColor = Color3.fromRGB(255, 224, 189),
					LeftArmColor = Color3.fromRGB(255, 224, 189),
					RightArmColor = Color3.fromRGB(255, 224, 189),
					LeftLegColor = Color3.fromRGB(255, 224, 189),
					RightLegColor = Color3.fromRGB(255, 224, 189),
					HeightScale = 0.95,
					WidthScale = 0.9,
					Shirt = 0, -- TODO Jack: catalog shirt id
					Pants = 0, -- TODO Jack: catalog pants id
					Face = 0, -- TODO Jack: catalog face id
					HairAccessory = "", -- TODO Jack: comma-separated catalog hair ids
					HatAccessory = "", -- TODO Jack: comma-separated catalog hat ids
				},
			},
			Favourite = "Taro Syrup",
			Size = "Medium",
		},
		{
			Id = "Theo",
			Name = "Theo",
			Look = {
				Base = 2,
				Description = {
					HeadColor = Color3.fromRGB(141, 85, 36),
					TorsoColor = Color3.fromRGB(141, 85, 36),
					LeftArmColor = Color3.fromRGB(141, 85, 36),
					RightArmColor = Color3.fromRGB(141, 85, 36),
					LeftLegColor = Color3.fromRGB(141, 85, 36),
					RightLegColor = Color3.fromRGB(141, 85, 36),
					HeightScale = 1.05,
					WidthScale = 0.95,
					Shirt = 0, -- TODO Jack: catalog shirt id
					Pants = 0, -- TODO Jack: catalog pants id
					Face = 0, -- TODO Jack: catalog face id
					HairAccessory = "", -- TODO Jack: comma-separated catalog hair ids
					HatAccessory = "", -- TODO Jack: comma-separated catalog hat ids
				},
			},
			Favourite = "Regular Coffee",
			Size = "Large",
		},
		{
			Id = "Priya",
			Name = "Priya",
			Look = {
				Base = 3,
				Description = {
					HeadColor = Color3.fromRGB(198, 134, 66),
					TorsoColor = Color3.fromRGB(198, 134, 66),
					LeftArmColor = Color3.fromRGB(198, 134, 66),
					RightArmColor = Color3.fromRGB(198, 134, 66),
					LeftLegColor = Color3.fromRGB(198, 134, 66),
					RightLegColor = Color3.fromRGB(198, 134, 66),
					HeightScale = 0.98,
					WidthScale = 0.9,
					Shirt = 0, -- TODO Jack: catalog shirt id
					Pants = 0, -- TODO Jack: catalog pants id
					Face = 0, -- TODO Jack: catalog face id
					HairAccessory = "", -- TODO Jack: comma-separated catalog hair ids
					HatAccessory = "", -- TODO Jack: comma-separated catalog hat ids
				},
			},
			Favourite = "Strawberry Syrup",
			Size = "Small",
		},
		{
			Id = "Gus",
			Name = "Gus",
			Look = {
				Base = 4,
				Description = {
					HeadColor = Color3.fromRGB(234, 192, 134),
					TorsoColor = Color3.fromRGB(234, 192, 134),
					LeftArmColor = Color3.fromRGB(234, 192, 134),
					RightArmColor = Color3.fromRGB(234, 192, 134),
					LeftLegColor = Color3.fromRGB(234, 192, 134),
					RightLegColor = Color3.fromRGB(234, 192, 134),
					HeightScale = 1.0,
					WidthScale = 1.05,
					Shirt = 0, -- TODO Jack: catalog shirt id
					Pants = 0, -- TODO Jack: catalog pants id
					Face = 0, -- TODO Jack: catalog face id
					HairAccessory = "", -- TODO Jack: comma-separated catalog hair ids
					HatAccessory = "", -- TODO Jack: comma-separated catalog hat ids
				},
			},
			Favourite = "Fudge Brownie",
		},
		{
			Id = "Juniper",
			Name = "Juniper",
			Look = {
				Base = 5,
				Description = {
					HeadColor = Color3.fromRGB(255, 219, 172),
					TorsoColor = Color3.fromRGB(255, 219, 172),
					LeftArmColor = Color3.fromRGB(255, 219, 172),
					RightArmColor = Color3.fromRGB(255, 219, 172),
					LeftLegColor = Color3.fromRGB(255, 219, 172),
					RightLegColor = Color3.fromRGB(255, 219, 172),
					HeightScale = 0.97,
					WidthScale = 0.9,
					Shirt = 0, -- TODO Jack: catalog shirt id
					Pants = 0, -- TODO Jack: catalog pants id
					Face = 0, -- TODO Jack: catalog face id
					HairAccessory = "", -- TODO Jack: comma-separated catalog hair ids
					HatAccessory = "", -- TODO Jack: comma-separated catalog hat ids
				},
			},
			Favourite = "Classic Milk Tea Boba",
			Size = "Large",
		},
		{
			Id = "Kenji",
			Name = "Kenji",
			Look = {
				Base = 6,
				Description = {
					HeadColor = Color3.fromRGB(241, 194, 125),
					TorsoColor = Color3.fromRGB(241, 194, 125),
					LeftArmColor = Color3.fromRGB(241, 194, 125),
					RightArmColor = Color3.fromRGB(241, 194, 125),
					LeftLegColor = Color3.fromRGB(241, 194, 125),
					RightLegColor = Color3.fromRGB(241, 194, 125),
					HeightScale = 1.03,
					WidthScale = 0.9,
					Shirt = 0, -- TODO Jack: catalog shirt id
					Pants = 0, -- TODO Jack: catalog pants id
					Face = 0, -- TODO Jack: catalog face id
					HairAccessory = "", -- TODO Jack: comma-separated catalog hair ids
					HatAccessory = "", -- TODO Jack: comma-separated catalog hat ids
				},
			},
			Favourite = "Espresso",
			Size = "Small",
		},
		{
			Id = "Rosa",
			Name = "Rosa",
			Look = {
				Base = 7,
				Description = {
					HeadColor = Color3.fromRGB(224, 172, 105),
					TorsoColor = Color3.fromRGB(224, 172, 105),
					LeftArmColor = Color3.fromRGB(224, 172, 105),
					RightArmColor = Color3.fromRGB(224, 172, 105),
					LeftLegColor = Color3.fromRGB(224, 172, 105),
					RightLegColor = Color3.fromRGB(224, 172, 105),
					HeightScale = 0.96,
					WidthScale = 0.9,
					Shirt = 0, -- TODO Jack: catalog shirt id
					Pants = 0, -- TODO Jack: catalog pants id
					Face = 0, -- TODO Jack: catalog face id
					HairAccessory = "", -- TODO Jack: comma-separated catalog hair ids
					HatAccessory = "", -- TODO Jack: comma-separated catalog hat ids
				},
			},
			Favourite = "Mango Syrup",
			Size = "Medium",
		},
		{
			Id = "Felix",
			Name = "Felix",
			Look = {
				Base = 8,
				Description = {
					HeadColor = Color3.fromRGB(255, 205, 148),
					TorsoColor = Color3.fromRGB(255, 205, 148),
					LeftArmColor = Color3.fromRGB(255, 205, 148),
					RightArmColor = Color3.fromRGB(255, 205, 148),
					LeftLegColor = Color3.fromRGB(255, 205, 148),
					RightLegColor = Color3.fromRGB(255, 205, 148),
					HeightScale = 1.0,
					WidthScale = 0.9,
					Shirt = 0, -- TODO Jack: catalog shirt id
					Pants = 0, -- TODO Jack: catalog pants id
					Face = 0, -- TODO Jack: catalog face id
					HairAccessory = "", -- TODO Jack: comma-separated catalog hair ids
					HatAccessory = "", -- TODO Jack: comma-separated catalog hat ids
				},
			},
			Favourite = "Classic Milk Tea Boba",
			Size = "Small",
		},
		{
			Id = "Noor",
			Name = "Noor",
			Look = {
				Base = 9,
				Description = {
					HeadColor = Color3.fromRGB(161, 102, 94),
					TorsoColor = Color3.fromRGB(161, 102, 94),
					LeftArmColor = Color3.fromRGB(161, 102, 94),
					RightArmColor = Color3.fromRGB(161, 102, 94),
					LeftLegColor = Color3.fromRGB(161, 102, 94),
					RightLegColor = Color3.fromRGB(161, 102, 94),
					HeightScale = 1.02,
					WidthScale = 0.9,
					Shirt = 0, -- TODO Jack: catalog shirt id
					Pants = 0, -- TODO Jack: catalog pants id
					Face = 0, -- TODO Jack: catalog face id
					HairAccessory = "", -- TODO Jack: comma-separated catalog hair ids
					HatAccessory = "", -- TODO Jack: comma-separated catalog hat ids
				},
			},
			Favourite = "Taro Syrup",
			Size = "Large",
		},
		{
			Id = "Ollie",
			Name = "Ollie",
			Look = {
				Base = 10,
				Description = {
					HeadColor = Color3.fromRGB(255, 227, 200),
					TorsoColor = Color3.fromRGB(255, 227, 200),
					LeftArmColor = Color3.fromRGB(255, 227, 200),
					RightArmColor = Color3.fromRGB(255, 227, 200),
					LeftLegColor = Color3.fromRGB(255, 227, 200),
					RightLegColor = Color3.fromRGB(255, 227, 200),
					HeightScale = 0.92,
					WidthScale = 0.9,
					Shirt = 0, -- TODO Jack: catalog shirt id
					Pants = 0, -- TODO Jack: catalog pants id
					Face = 0, -- TODO Jack: catalog face id
					HairAccessory = "", -- TODO Jack: comma-separated catalog hair ids
					HatAccessory = "", -- TODO Jack: comma-separated catalog hat ids
				},
			},
			Favourite = "Regular Coffee",
			Size = "Small",
		},
		{
			Id = "Wren",
			Name = "Wren",
			Look = {
				Base = 11,
				Description = {
					HeadColor = Color3.fromRGB(229, 184, 143),
					TorsoColor = Color3.fromRGB(229, 184, 143),
					LeftArmColor = Color3.fromRGB(229, 184, 143),
					RightArmColor = Color3.fromRGB(229, 184, 143),
					LeftLegColor = Color3.fromRGB(229, 184, 143),
					RightLegColor = Color3.fromRGB(229, 184, 143),
					HeightScale = 0.99,
					WidthScale = 0.9,
					Shirt = 0, -- TODO Jack: catalog shirt id
					Pants = 0, -- TODO Jack: catalog pants id
					Face = 0, -- TODO Jack: catalog face id
					HairAccessory = "", -- TODO Jack: comma-separated catalog hair ids
					HatAccessory = "", -- TODO Jack: comma-separated catalog hat ids
				},
			},
			Favourite = "Strawberry Syrup",
			Size = "Large",
		},
		{
			Id = "Dex",
			Name = "Dex",
			Look = {
				Base = 12,
				Description = {
					HeadColor = Color3.fromRGB(92, 56, 54),
					TorsoColor = Color3.fromRGB(92, 56, 54),
					LeftArmColor = Color3.fromRGB(92, 56, 54),
					RightArmColor = Color3.fromRGB(92, 56, 54),
					LeftLegColor = Color3.fromRGB(92, 56, 54),
					RightLegColor = Color3.fromRGB(92, 56, 54),
					HeightScale = 1.05,
					WidthScale = 1.0,
					Shirt = 0, -- TODO Jack: catalog shirt id
					Pants = 0, -- TODO Jack: catalog pants id
					Face = 0, -- TODO Jack: catalog face id
					HairAccessory = "", -- TODO Jack: comma-separated catalog hair ids
					HatAccessory = "", -- TODO Jack: comma-separated catalog hat ids
				},
			},
			Favourite = "Fudge Brownie",
		},
	} :: { Regular },

	-- {name} = the regular, {player} = the barista's display name, {drink} = the favourite's label.
	FIRST_GREETINGS = {
		"Hi! I'm {name}. Could I get a {drink}?",
		"Hello, I'm {name}! One {drink}, please.",
		"First time here! I'm {name}. A {drink}, please.",
	},
	MET_GREETINGS = {
		"Hey {player}! The usual {drink}, please.",
		"{player}! Good to see you. My usual {drink}?",
		"Hi again, {player}! You know my order: {drink}.",
	},
	-- The favourite is above the barista's level: the regular orders from the normal pool.
	SURPRISE_GREETINGS = {
		"Hey {player}! Surprise me today.",
		"Hi {player}! Something new today, please.",
	},
	SURPRISE_FIRST_GREETINGS = {
		"Hi! I'm {name}. Surprise me!",
	},
}

return RegularsConfig

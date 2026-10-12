--[[
    Module: CustomerConfig
    Description: NPC customers — capacity, order size, appearances and dialogue.

    Ported from V4's customer system (V3's legacy NPCService is not used). Dialogue is
    grouped by personality; every category must define Default, and may define Karen.
    Greeting and Followup lines contain a single %s placeholder for the item name.
--]]

local CustomerConfig = {}

--- Most NPCs alive at once across the whole cafe.
CustomerConfig.MaxCapacity = 25

--- How many times a customer will reject a wrong order before giving up and leaving.
CustomerConfig.MaxAttempts = 3

--- Item count per order, inclusive.
CustomerConfig.MinItems = 1
CustomerConfig.MaxItems = 3

--- Seconds a customer waits at the register before leaving unserved.
CustomerConfig.PatienceSeconds = 180

--- Chance (0-1) that a spawned customer is a Karen.
CustomerConfig.KarenChance = 0.15

--- Seconds between idle "Waiting" remarks.
CustomerConfig.WaitingChatInterval = 25

--- User ids whose avatars are cloned onto NPCs. Purely cosmetic; a failed lookup falls
--- back to the default rig rather than blocking the spawn.
CustomerConfig.Appearances = {
	183587408,
	454881159,
	303108562,
	75045215,
	256448888,
	173362076,
	176353970,
	3249046002,

	---> allied groups
	402700513,
	35238060,
	65917121,
	23212029,
	26249891,
	668328180,
	6220197,
	211336968,
	27842645,
	189866232,
	101395763,
	33965721,
	142333320,
	456304941,
	171687673,
	1343720874,
	386432707,
	125281862,
	54753551,
	21419481,
}

CustomerConfig.Interactions = {
	Greeting = {
		Default = {
			"Hey there, I would like to order a %s.",
			"Greetings! May I please get a %s?",
			"Hey! I'm starving! I'll take a %s.",
			"Hello! Can I have a %s?",
			"Hi there! One %s, please.",
			"Yo! I'm in the mood for a %s.",
			"Can I get a %s? Thanks!",
			"I'd love a %s, please.",
			"Oh, that %s looks good! I'll take one.",
		},
		Karen = {
			"Ugh. I've been having an awful day. Get me a %s NOW!",
			"Don't test my patience. Get me a %s.",
			"Can't you see I'm in a hurry?! Get me a %s right this second!",
			"Are you going to take my order or not? I want a %s.",
			"Finally! I want a %s and make it quick.",
		},
	},

	Followup = {
		Default = {
			"Oh, and a %s too please!",
			"I'd also like a %s.",
			"Could I add a %s as well?",
			"And a %s, thanks!",
			"One more thing — a %s please.",
		},
		Karen = {
			"And a %s. Obviously.",
			"I also want a %s. Keep up.",
			"Add a %s to that. Now.",
		},
	},

	Leaving = {
		Default = {
			"Wow... Ok...",
			"Cya later!",
			"Goodbye!",
			"Bye!",
			"Thanks, see ya!",
			"Later!",
			"I'm out, have a good one!",
		},
		Karen = {
			"I'm calling your corporate office.",
			"Terrible service! I'm getting you FIRED!",
			"Awful service experience.",
			"I'm leaving a bad review.",
			"Fine.. I'll just go to the cafe across the street!",
			"I can't believe this place!",
			"You're going to regret this.",
		},
	},

	Waiting = {
		Default = {
			"I'm so hungry...",
			"I can't wait to taste my drink!",
			"I'm so excited!",
			"I'm really hungry...",
			"Hope my order's ready soon...",
			"I wonder how it'll taste!",
			"Can't wait much longer, I'm starving!",
		},
		Karen = {
			"Is my order ready yet???!!",
			"Hurry up!",
			"Ugh. I hate waiting.",
			"WHAT IS TAKING SO LONG??!!",
			"I could've made it faster myself!",
			"This is ridiculous.",
		},
	},

	WrongOrder = {
		Default = {
			"Hey! This isn't what I ordered! Try again.",
			"Excuse me, but this isn't what I ordered... Try again.",
			"That's not what I wanted! Try again.",
			"Uh, this isn't mine. Could you fix it?",
			"Sorry, but that's not right. Can you double check?",
			"I'm pretty sure I ordered something else.",
		},
		Karen = {
			"Are you serious? That is NOT what I ordered!",
			"Unbelievable! This is NOT what I ordered!",
			"Are you trying to make me mad? This is NOT what I ordered!",
			"This is ridiculous. Get it right!",
			"Do you even know what you're doing?",
		},
	},

	WorkerAction = {
		Default = {
			"Thanks a bunch!",
			"Thanks!",
			"You're the best, thanks!",
			"Great service!",
			"Awesome, appreciate it!",
			"Thanks so much!",
			"Thank you! This looks amazing.",
		},
		Karen = {
			"Took you long enough!",
			"You started this!",
			"I am NEVER coming here ever again!",
			"I demand a full refund.",
			"I will get you fired.",
			"Finally. About time.",
			"This is unacceptable.",
		},
	},
}

--- Random line from a category, falling back to Default when a personality has no
--- variant of its own.
function CustomerConfig.getLine(category: string, personality: string?): string?
	local group = CustomerConfig.Interactions[category]
	if not group then
		return nil
	end

	local lines = (personality and group[personality]) or group.Default
	if not lines or #lines == 0 then
		return nil
	end

	return lines[math.random(1, #lines)]
end

return CustomerConfig

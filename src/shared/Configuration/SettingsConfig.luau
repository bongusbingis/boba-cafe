export type Setting = {
	Key: string,
	Label: string,
	--- Discriminates between a boolean toggle and a one-shot action button.
	--- Defaults to "Toggle" when omitted for backwards compatibility.
	Type: ("Toggle" | "Action")?,
	--- Toggle settings: the default on/off value.
	Default: boolean?,
	--- Action settings: called on the client when the button is pressed.
	--- Networking is the caller's responsibility.
	ClientCallback: (() -> ())?,
	--- Text shown inside the action button pill (e.g. "OPEN", "CLAIM").
	ButtonLabel: string?,
	MinRank: number?,
	--- When set, this setting is only shown to players who own the specified game pass.
	--- The "Game Passes" category is hidden entirely if the player owns none of its passes.
	GamepassId: number?,
}

export type Category = {
	Category: string,
	Settings: { Setting },
}

local MIN_STAFF_RANK = 7

local rankNamesById = {
    [8] = "Barista",
    [10] = "Kitchen Leader",
}

local function makeClaimClientCallback(passId: number): () -> ()
    return function()
        task.spawn(function()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local ClaimRank = ReplicatedStorage:WaitForChild("Networking"):WaitForChild("ClaimRank")
            local ok, result = pcall(function()
                return ClaimRank:InvokeServer(passId)
            end)
            if not ok or not result then
                warn("[RankClaiming] Remote invocation failed for passId", passId)
            end
        end)
    end
end

local function makeClaimRankSetting(rankId: number, passId: number): Setting
    local rankName: string = rankNamesById[rankId] or ("Rank " .. rankId)
    return {
        Key = "ClaimRank_" .. rankId,
        Label = "Claim " .. rankName,
        ButtonLabel = "CLAIM",
        Type = "Action",
        GamepassId = passId,
        ClientCallback = makeClaimClientCallback(passId),
    }
end

local config: { Category } = {
	{
		Category = "Game Passes",
		Settings = {
			--{ Key = "HeadlessHead",    Label = "Headless Head",      Default = false, GamepassId = 6202153 },
			--{ Key = "FasterWalkSpeed", Label = "Faster Walk Speed",  Default = false, GamepassId = 12385742 },
            makeClaimRankSetting(8, 6202153), ---> Barista
            makeClaimRankSetting(10, 15243046), ---> Kitchen Leader
        },
	},
	{
		Category = "Game Audio",
		Settings = {
			{ Key = "MusicEnabled", Label = "Music", Default = true },
            { Key = "SFXEnabled", Label = "SFX", Default = true },
		},
	},
	{
		Category = "Staff",
		Settings = {
            { Key = "SyrupHighlighting", Label = "Syrup Highlighting", Default = true, MinRank = MIN_STAFF_RANK },
            { Key = "ShiftTimerEnabled", Label = "Shift Timer", Default = true, MinRank = 11 },
        },
	},
}

return config

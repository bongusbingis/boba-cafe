--[[
    Module: NicknamePrompt
    Description: The roleplay nickname prompt, as a one-shot the caller decides when to run.

    This used to fire three seconds after a player's first join and could not be dismissed:
    closing it resolved nil, which was treated as an invalid nickname and re-opened the
    same prompt forever. It was the first thing a new player met and it blocked play.

    It is now deferred (OnboardingService runs it once onboarding is done), skippable, and
    falls back to the player's DisplayName. Retries only happen for input the player can
    actually fix, and only up to MAX_ATTEMPTS.
--]]

---> services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

---> dependencies
local Packages = ReplicatedStorage:WaitForChild("Packages")

local Knit = require(Packages.Knit)

---> constants

local MAX_NICKNAME_LENGTH = 15

--- After this many corrections the DisplayName fallback is applied. A prompt that can
--- reopen without limit is the bug this module exists to fix.
local MAX_ATTEMPTS = 3

---> private

local function formatBrackets(str: string): string
	return str:gsub("%[(.-)%]", " <font color='#f5c242'>%1</font> "):gsub("|(.-)|", " <font color='#fa2545'>%1</font> ")
end

local function getFilterResult(text: string, fromUserId: number)
	local filterResult
	local success, errorMessage = pcall(function()
		filterResult = TextService:FilterStringAsync(text, fromUserId)
	end)

	if success then
		return filterResult
	end

	warn("Error generating TextFilterResult:", errorMessage)
	return nil
end

--- Applies a nickname to the profile and tells the cosmetics layer to redraw the overhead.
local function commit(player: Player, proxy, nickname: string)
	proxy:SetValue({ "Nickname" }, nickname)
	Knit.GetService("CosmeticsService"):NotifyNicknameChanged(player, nickname)
end

---> public

--- Prompts once, retrying only on fixable input. Dismissal — or exhausting the attempts —
--- settles on DisplayName so the player is never asked again and never stuck.
--- Safe to call more than once; it no-ops if a nickname is already set.
return function(player: Player, proxy)
	if typeof(proxy.Data.Nickname) == "string" and proxy.Data.Nickname ~= "" then
		return
	end

	local attempts = 0

	local function ask(errorText: string?)
		attempts += 1

		Knit.GetService("DialogService")
			:CreateDialog(player, "TextInputPrompt", {
				Title = "Roleplay Name",
				Text = formatBrackets(
					`Choose a roleplay nickname. {errorText or "Skip to use your display name — you can change it from the Menu."}`
				),
				PlaceholderText = player.DisplayName,
				CloseText = "Skip",
			})
			:andThen(function(nickname)
				if not player.Parent then
					return
				end

				-- Dismissed. Not an error — the player chose to keep their display name.
				if typeof(nickname) ~= "string" or nickname:gsub(" ", "") == "" then
					commit(player, proxy, player.DisplayName)
					return
				end

				if attempts >= MAX_ATTEMPTS then
					commit(player, proxy, player.DisplayName)
					return
				end

				if #nickname > MAX_NICKNAME_LENGTH then
					ask(`|Nickname must be {MAX_NICKNAME_LENGTH} characters or less.|`)
					return
				end

				local filterResult = getFilterResult(nickname, player.UserId)
				if not filterResult then
					-- The failure is ours, not the player's; don't make them retype.
					commit(player, proxy, player.DisplayName)
					return
				end

				if filterResult:GetNonChatStringForBroadcastAsync() ~= nickname then
					ask("|That name contains filtered content. Please try another.|")
					return
				end

				commit(player, proxy, nickname)
			end)
			:catch(function(err)
				warn(`[NicknamePrompt] Prompt failed for {player.Name}: {err}`)
			end)
	end

	ask()
end

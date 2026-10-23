--!strict
--[[
	NicknamePrompt
	Client-side helper for prompting the player to enter a new roleplay nickname.
	Verifies the nickname on the server and prompts developer product (1152995517)
	only after verification passes.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

local NicknamePrompt = {}

function NicknamePrompt.Submit(newName: string)
	local trimmed = string.match(newName, "^%s*(.-)%s*$") or ""
	if #trimmed == 0 then
		NicknamePrompt.Open("Nickname cannot be empty.")
		return
	end

	if #trimmed > 15 then
		NicknamePrompt.Open("Nickname must be 15 characters or less.")
		return
	end

	Knit.GetService("CosmeticsService")
		:RequestNicknameChange(trimmed)
		:andThen(function(result)
			if typeof(result) == "table" and result.Success == false then
				NicknamePrompt.Open(result.Error or "Invalid nickname. Please try again.")
			elseif typeof(result) == "table" and result.Success == true and result.Free == true then
				local dialogController = Knit.GetController("DialogController")
				if dialogController then
					dialogController:Notify({
						Title = "Nickname Set",
						Description = `Your roleplay nickname is now {trimmed}.`,
					})
				end
			end
		end)
		:catch(function(err)
			warn("[NicknamePrompt] Nickname change request failed:", err)
		end)
end

function NicknamePrompt.Open(errorText: string?)
	local appDialogs = Knit.GetController("DialogController")
	if not appDialogs then
		return
	end

	local text = errorText or "Enter a new roleplay nickname (1-15 characters). Changing your nickname costs Robux."

	local prompt = appDialogs.new("TextInputPrompt", {
		Title = "Change Nickname",
		Text = text,
		PlaceholderText = "New Nickname",
		CloseText = "Cancel",
	})

	prompt:Fire():andThen(function(newName: any)
		if typeof(newName) ~= "string" or newName == "" then
			return
		end
		NicknamePrompt.Submit(newName)
	end)
end

return NicknamePrompt

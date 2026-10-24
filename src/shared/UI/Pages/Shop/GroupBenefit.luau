--!strict

local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local UI = Shared:WaitForChild("UI")

local React = require(Packages.React)
local Knit = require(Packages.Knit)
local NormalButton = require(UI.Components.Buttons.NormalButton)
local Styles = require(UI.Styles)

local c = React.createElement
local GROUP_ID = 3174578

return function(props: { OnClaimed: (() -> ())? }?)
	local isClaimed, setIsClaimed = React.useState(false)
	local isBusy, setIsBusy = React.useState(false)
	local status, setStatus = React.useState("Join the group to claim your Ant Pet.")

	React.useEffect(function()
		Knit.GetService("GroupBenefitService")
			:GetClaimStatusAsync()
			:andThen(function(claimStatus)
				if claimStatus == "Claimed" then
					setIsClaimed(true)
					setStatus("You already claimed your Ant Pet!")
					if props and props.OnClaimed then
						props.OnClaimed()
					end
				elseif claimStatus == "Retry" then
					setStatus("Claim status is unavailable. Please try again.")
				end
			end)
			:catch(function()
				setStatus("Claim status is unavailable. Please try again.")
			end)
	end, {})

	local function joinAndClaim()
		if isBusy or isClaimed then
			return
		end

		setIsBusy(true)
		setStatus("Checking group membership...")

		local promptOk, membershipStatus = pcall(function()
			return GroupService:PromptJoinAsync(GROUP_ID)
		end)
		if not promptOk then
			setStatus("The join prompt could not open. Please try again.")
			setIsBusy(false)
			return
		end

		if
			membershipStatus ~= Enum.GroupMembershipStatus.Joined
			and membershipStatus ~= Enum.GroupMembershipStatus.AlreadyMember
		then
			if membershipStatus == Enum.GroupMembershipStatus.JoinRequestPending then
				setStatus("Your group join request is pending. You can claim after it is approved.")
			else
				setStatus("Join the group to claim your Ant Pet.")
			end
			setIsBusy(false)
			return
		end

		setStatus("Verifying membership and claiming your Ant Pet...")
		Knit.GetService("GroupBenefitService")
			:ClaimAntPetAsync()
			:andThen(function(claimStatus)
				if claimStatus == "Claimed" then
					setIsClaimed(true)
					setStatus("Ant Pet claimed!")
					if props and props.OnClaimed then
						props.OnClaimed()
					end
				elseif claimStatus == "NotMember" then
					setStatus("Group membership could not be confirmed. Please try again.")
				else
					setStatus("Your Ant Pet is not claimed yet. Free a pet slot or try again.")
				end
			end)
			:catch(function()
				setStatus("Your Ant Pet is not claimed yet. Please try again.")
			end)
			:finally(function()
				setIsBusy(false)
			end)
	end

	return c("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Title = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.470149, 0),
			Size = UDim2.fromScale(0.94, 0.09),
			Text = "Group Benefit",
			TextColor3 = Styles.GREEN,
			TextScaled = true,
		}),

		Reward = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.5, 0.24),
			Size = UDim2.fromScale(0.84, 0.14),
			Text = "Join our group and claim a free Ant Pet!",
			TextColor3 = Styles.GREEN_DEEP,
			TextScaled = true,
		}),

		ClaimButton = c(NormalButton, {
			Text = if isClaimed then "Claimed" else if isBusy then "Please Wait" else "Join Group",
			Color = if isClaimed then Styles.GRAY else Styles.GREEN,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.52, 0.12),
			OnClick = if isClaimed or isBusy then nil else joinAndClaim,
		}),

		Status = c("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Styles.FONT_FREDOKA,
			Position = UDim2.fromScale(0.5, 0.64),
			Size = UDim2.fromScale(0.84, 0.12),
			Text = status,
			TextColor3 = Styles.GRAY,
			TextScaled = true,
		}),
	})
end

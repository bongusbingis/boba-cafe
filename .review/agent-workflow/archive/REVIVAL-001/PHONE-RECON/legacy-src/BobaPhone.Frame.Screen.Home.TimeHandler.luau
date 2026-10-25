local Months = {
	[1] = "January",
	[2] = "Febuary",
	[3] = "March",
	[4] = "April",
	[5] = "May",
	[6] = "June",
	[7] = "July",
	[8] = "August",
	[9] = "September",
	[10] = "October",
	[11] = "November",
	[12] = "December",
}

local function toDisplayDate(timeTable)
	return Months[timeTable.month].." "..timeTable.day..", "..timeTable.year
end

while wait(3600) do
	script.Parent.Date.Text = toDisplayDate(os.date("*t", os.time()))
end

local ClientTimeDisplay = game:GetService("ReplicatedStorage"):WaitForChild("ReplicatedValues").ClientTimeDisplay
script.Parent.Time.Text = ClientTimeDisplay.Value
ClientTimeDisplay:GetPropertyChangedSignal("Value", function()
	script.Parent.Time.Text = ClientTimeDisplay.Value
end)

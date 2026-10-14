local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local TestEZ = require(Packages.TestEZ)
local TextReporter = TestEZ.Reporters.TextReporter

-- Code default stays false. In Studio only, setting workspace attribute
-- "RunTests" = true enables the suite without editing this file (the Studio
-- guard means a saved stray attribute can never run tests in a live server).
local TESTS_ENABLED = false

if RunService:IsStudio() and workspace:GetAttribute("RunTests") == true then
	TESTS_ENABLED = true
end

if not TESTS_ENABLED then
	return
end

task.wait(3)

print("[Tests] Running test suite...")
print(string.rep("-", 60))

TestEZ.run(script.Parent, function(results)
	TextReporter.report(results)

	if results.failureCount > 0 then
		warn(string.format("[Tests] %d test(s) FAILED.", results.failureCount))
	else
		print(string.format("[Tests] All %d test(s) passed.", results.successCount))
	end
end)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage:WaitForChild("Packages")

local TestEZ = require(Packages.TestEZ)
local TextReporter = TestEZ.Reporters.TextReporter

local TESTS_ENABLED = false

if not TESTS_ENABLED then
	return
end

task.wait(3)

print("[Tests] Running OrderService tests...")
print(string.rep("-", 60))

TestEZ.run(script.Parent, function(results)
	TextReporter.report(results)

	if results.failureCount > 0 then
		warn(string.format("[Tests] %d test(s) FAILED.", results.failureCount))
	else
		print(string.format("[Tests] All %d test(s) passed.", results.successCount))
	end
end)

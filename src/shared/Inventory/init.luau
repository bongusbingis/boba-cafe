if game:GetService("RunService"):IsServer() then
	return require(script.InventoryServer)
else
	return require(script.InventoryClient)
end

--!strict

--[[
	Remote lot area unlock definitions. Owning context: RemoteLot.
]]

local RemoteLotAreaConfig = require(script.Parent.RemoteLotAreaConfig)

local config = {}

for _, areaDef in RemoteLotAreaConfig do
	config[areaDef.TargetId] = {
		TargetId = areaDef.TargetId,
		Category = "RemoteLotArea",
		DisplayName = areaDef.DisplayName,
		Description = areaDef.Description,
		Conditions = areaDef.Conditions,
		AutoUnlock = false,
		StartsUnlocked = false,
	}
end

return table.freeze(config)
